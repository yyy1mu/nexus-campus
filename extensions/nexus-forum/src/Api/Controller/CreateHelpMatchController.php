<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\Post\Command\PostReply;
use Flarum\User\Exception\PermissionDeniedException;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpMatchSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\AgentAuthorization;
use Nexus\Forum\Service\AgentPreflightCatalog;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateHelpMatchController extends AbstractCreateController
{
    public $serializer = HelpMatchSerializer::class;

    public $include = ['helper', 'helpRequest'];

    private Dispatcher $bus;

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    private ConnectionInterface $database;

    public function __construct(
        Dispatcher $bus,
        AgentActionLogger $actionLogger,
        AgentAuthorization $authorization,
        ConnectionInterface $database
    )
    {
        $this->bus = $bus;
        $this->actionLogger = $actionLogger;
        $this->authorization = $authorization;
        $this->database = $database;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $helpRequestId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Offering help requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'offer Nexus match help');

        $message = NexusPayload::string($attributes, 'message', 2000, true);
        $meetingHint = NexusPayload::string($attributes, 'meetingHint', 255, false);
        $meetingSafetyState = NexusPayload::oneOf(
            $attributes,
            'meetingSafetyState',
            ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
            'not_arranged'
        );

        return $this->database->transaction(function () use ($helpRequestId, $actor, $message, $meetingHint, $meetingSafetyState, $request): HelpMatch {
            $helpRequest = HelpRequest::query()
                ->with('discussion')
                ->whereKey($helpRequestId)
                ->lockForUpdate()
                ->firstOrFail();

            if ((int) $helpRequest->requester_user_id === (int) $actor->id) {
                throw new PermissionDeniedException;
            }

            if (! in_array($helpRequest->status, ['open', 'matching'], true)) {
                throw new ValidationException(['status' => 'This help request is not open for new matches.']);
            }

            $match = HelpMatch::query()
                ->where('help_request_id', $helpRequest->id)
                ->where('helper_user_id', $actor->id)
                ->lockForUpdate()
                ->first();

            if ($match && $match->status !== 'offered') {
                throw new ValidationException(['status' => 'This existing match is no longer open for a new offer.']);
            }

            if (! $match) {
                $match = new HelpMatch;
                $match->help_request_id = $helpRequest->id;
                $match->helper_user_id = $actor->id;
            }

            $match->status = 'offered';
            $match->message = $message;
            $match->meeting_hint = $meetingHint;
            $match->meeting_safety_state = $meetingSafetyState;
            $match->save();

            $helpRequest->status = $helpRequest->status === 'open' ? 'matching' : $helpRequest->status;
            $helpRequest->save();

            $this->bus->dispatch(new PostReply($helpRequest->discussion_id, $actor, [
                'type' => 'posts',
                'attributes' => [
                    'content' => $this->composeOfferPost($message, $meetingHint),
                ],
            ], $request->getAttribute('ipAddress')));

            $match->setRelation('helper', $actor);
            $match->setRelation('helpRequest', $helpRequest);

            $this->actionLogger->succeeded(
                $actor,
                'match.offer',
                'help_match',
                (int) $match->id,
                [
                    'helpRequestId' => (int) $helpRequest->id,
                    'messageLength' => $this->actionLogger->length($message),
                    'meetingHintSet' => $meetingHint !== null,
                    'meetingSafetyState' => $meetingSafetyState,
                ],
                [
                    'status' => $match->status,
                    'helpRequestStatus' => $helpRequest->status,
                ],
                (string) $request->getAttribute('ipAddress'),
                true
            );

            return $match;
        });
    }

    private function composeOfferPost(string $message, ?string $meetingHint): string
    {
        $lines = [$message];

        if ($meetingHint) {
            $lines[] = '';
            $lines[] = 'Suggested meeting point: '.$meetingHint;
        }

        $lines[] = '';
        $lines[] = AgentPreflightCatalog::matchOfferFooter();

        return implode("\n", $lines);
    }
}
