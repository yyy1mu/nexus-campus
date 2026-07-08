<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractShowController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\Post\Command\PostReply;
use Flarum\User\Exception\PermissionDeniedException;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpDispatchSerializer;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Shared\Authorization\AgentAuthorization;
use Nexus\Forum\Agent\Service\AgentPreflightCatalog;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateHelpDispatchController extends AbstractShowController
{
    public $serializer = HelpDispatchSerializer::class;

    public $include = ['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match'];

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

        $id = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $dispatch = HelpDispatch::query()
            ->with(['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match'])
            ->findOrFail($id);
        $helpRequest = $dispatch->helpRequest;
        $isHelper = (int) $dispatch->helper_user_id === (int) $actor->id;
        $isRequester = $helpRequest && (int) $helpRequest->requester_user_id === (int) $actor->id;

        if (! $isHelper && ! $isRequester && ! $actor->isAdmin()) {
            throw new PermissionDeniedException;
        }

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating a dispatch requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'respond to Nexus dispatches');

        $previousStatus = $dispatch->status;
        $nextStatus = NexusPayload::oneOf(
            $attributes,
            'status',
            ['accepted', 'declined', 'cancelled'],
            $dispatch->status
        );

        if (in_array($nextStatus, ['accepted', 'declined'], true) && ! $isHelper) {
            throw new PermissionDeniedException;
        }

        if ($nextStatus === 'cancelled' && ! $isRequester && ! $actor->isAdmin()) {
            throw new PermissionDeniedException;
        }

        if (in_array($dispatch->status, ['accepted', 'declined', 'cancelled', 'expired'], true)) {
            throw new ValidationException(['status' => 'This dispatch has already been resolved.']);
        }

        if ($dispatch->expires_at && $dispatch->expires_at->isPast() && $nextStatus === 'accepted') {
            $dispatch->status = 'expired';
            $dispatch->responded_at = Carbon::now();
            $dispatch->save();

            throw new ValidationException(['status' => 'This dispatch has expired.']);
        }

        $responseMessage = NexusPayload::string($attributes, 'responseMessage', 2000, false)
            ?: NexusPayload::string($attributes, 'message', 2000, false);

        return $this->database->transaction(function () use ($dispatch, $attributes, $nextStatus, $responseMessage, $request, $actor, $previousStatus): HelpDispatch {
            if (array_key_exists('meetingHint', $attributes)) {
                $dispatch->meeting_hint = NexusPayload::string($attributes, 'meetingHint', 255, false);
            }

            if (array_key_exists('meetingSafetyState', $attributes)) {
                $dispatch->meeting_safety_state = NexusPayload::oneOf(
                    $attributes,
                    'meetingSafetyState',
                    ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
                    $dispatch->meeting_safety_state
                );
            }

            $dispatch->status = $nextStatus;
            $dispatch->response_message = $responseMessage;
            $dispatch->responded_at = Carbon::now();

            if ($nextStatus === 'accepted') {
                $match = $this->acceptDispatch($dispatch, $responseMessage, (string) $request->getAttribute('ipAddress'));
                $dispatch->match_id = $match->id;
                $dispatch->setRelation('match', $match);
            }

            $dispatch->save();

            $this->actionLogger->succeeded(
                $actor,
                'dispatch.update',
                'help_dispatch',
                (int) $dispatch->id,
                [
                    'previousStatus' => $previousStatus,
                    'nextStatus' => $nextStatus,
                    'responseMessageLength' => $this->actionLogger->length($responseMessage),
                    'meetingHintChanged' => array_key_exists('meetingHint', $attributes),
                    'meetingSafetyState' => $dispatch->meeting_safety_state,
                ],
                [
                    'status' => $dispatch->status,
                    'matchId' => $dispatch->match_id === null ? null : (int) $dispatch->match_id,
                    'helpRequestId' => (int) $dispatch->help_request_id,
                ],
                (string) $request->getAttribute('ipAddress'),
                true
            );

            return $dispatch;
        });
    }

    private function acceptDispatch(HelpDispatch $dispatch, ?string $responseMessage, string $ipAddress): HelpMatch
    {
        $helpRequest = $dispatch->helpRequest;
        $match = HelpMatch::query()
            ->where('help_request_id', $dispatch->help_request_id)
            ->where('helper_user_id', $dispatch->helper_user_id)
            ->first();

        if (! $match) {
            $match = new HelpMatch;
            $match->help_request_id = $dispatch->help_request_id;
            $match->helper_user_id = $dispatch->helper_user_id;
        }

        $match->status = 'accepted';
        $match->message = $responseMessage ?: $dispatch->message ?: 'Accepted Nexus dispatch.';
        $match->meeting_hint = $dispatch->meeting_hint;
        $match->meeting_safety_state = $dispatch->meeting_safety_state;

        if (! $match->accepted_at) {
            $match->accepted_at = Carbon::now();
        }

        $match->save();

        $helpRequest->status = 'matched';
        $helpRequest->meeting_safety_state = $dispatch->meeting_safety_state;
        $helpRequest->save();

        $this->bus->dispatch(new PostReply($helpRequest->discussion_id, $dispatch->helper, [
            'type' => 'posts',
            'attributes' => [
                'content' => $this->composeAcceptancePost($match->message, $match->meeting_hint),
            ],
        ], $ipAddress));

        $match->setRelation('helper', $dispatch->helper);
        $match->setRelation('helpRequest', $helpRequest);

        return $match;
    }

    private function composeAcceptancePost(string $message, ?string $meetingHint): string
    {
        $lines = [$message];

        if ($meetingHint) {
            $lines[] = '';
            $lines[] = 'Suggested meeting point: '.$meetingHint;
        }

        $lines[] = '';
        $lines[] = AgentPreflightCatalog::dispatchAcceptFooter();

        return implode("\n", $lines);
    }
}
