<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractShowController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\User\Exception\PermissionDeniedException;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpMatchSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Shared\Authorization\AgentAuthorization;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateHelpMatchController extends AbstractShowController
{
    public $serializer = HelpMatchSerializer::class;

    public $include = ['helper', 'helpRequest', 'helpRequest.discussion'];

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    private ConnectionInterface $database;

    public function __construct(
        AgentActionLogger $actionLogger,
        AgentAuthorization $authorization,
        ConnectionInterface $database
    )
    {
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
        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating a match requires explicit user confirmation.',
            ]);
        }

        return $this->database->transaction(function () use ($id, $actor, $attributes, $request): HelpMatch {
            $match = HelpMatch::query()
                ->with(['helper', 'helpRequest', 'helpRequest.discussion'])
                ->whereKey($id)
                ->lockForUpdate()
                ->firstOrFail();
            $helpRequest = $match->helpRequest;
            $isRequester = (int) $helpRequest->requester_user_id === (int) $actor->id;
            $isHelper = (int) $match->helper_user_id === (int) $actor->id;

            if (! $isRequester && ! $isHelper && ! $actor->isAdmin()) {
                throw new PermissionDeniedException;
            }

            $this->authorization->assertMatchingAllowed((int) $actor->id, 'update Nexus match state');

            $previousStatus = $match->status;
            $nextStatus = NexusPayload::oneOf(
                $attributes,
                'status',
                ['offered', 'accepted', 'declined', 'cancelled', 'completed'],
                $match->status
            );

            $this->assertValidTransition($previousStatus, $nextStatus, array_key_exists('meetingHint', $attributes) || array_key_exists('meetingSafetyState', $attributes));

            if (in_array($nextStatus, ['accepted', 'declined'], true) && ! $isRequester && ! $actor->isAdmin()) {
                throw new PermissionDeniedException;
            }

            if ($nextStatus === 'cancelled' && ! $isHelper && ! $isRequester && ! $actor->isAdmin()) {
                throw new PermissionDeniedException;
            }

            if (array_key_exists('meetingHint', $attributes)) {
                $match->meeting_hint = NexusPayload::string($attributes, 'meetingHint', 255, false);
            }

            if (array_key_exists('meetingSafetyState', $attributes)) {
                $match->meeting_safety_state = NexusPayload::oneOf(
                    $attributes,
                    'meetingSafetyState',
                    ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
                    $match->meeting_safety_state
                );
            }

            $match->status = $nextStatus;

            if ($nextStatus === 'accepted' && ! $match->accepted_at) {
                $match->accepted_at = Carbon::now();
                $helpRequest->status = 'matched';
                $helpRequest->meeting_safety_state = $match->meeting_safety_state;
                $helpRequest->save();
            }

            if ($nextStatus === 'completed' && ! $match->completed_at) {
                $match->completed_at = Carbon::now();
                $helpRequest->status = 'closed';
                $helpRequest->closed_at = Carbon::now();
                $helpRequest->save();
            }

            $match->save();

            $this->actionLogger->succeeded(
                $actor,
                'match.update',
                'help_match',
                (int) $match->id,
                [
                    'previousStatus' => $previousStatus,
                    'nextStatus' => $nextStatus,
                    'meetingHintChanged' => array_key_exists('meetingHint', $attributes),
                    'meetingSafetyState' => $match->meeting_safety_state,
                ],
                [
                    'status' => $match->status,
                    'helpRequestId' => (int) $match->help_request_id,
                    'helpRequestStatus' => $helpRequest->status,
                    'acceptedAtSet' => $match->accepted_at !== null,
                    'completedAtSet' => $match->completed_at !== null,
                ],
                (string) $request->getAttribute('ipAddress'),
                true
            );

            return $match;
        });
    }

    private function assertValidTransition(string $previousStatus, string $nextStatus, bool $changesMeeting): void
    {
        if (in_array($previousStatus, ['declined', 'cancelled', 'completed'], true)) {
            if ($nextStatus !== $previousStatus || $changesMeeting) {
                throw new ValidationException(['status' => 'This match has already been resolved.']);
            }

            return;
        }

        if ($nextStatus === 'offered' && $previousStatus !== 'offered') {
            throw new ValidationException(['status' => 'A match cannot move back to offered.']);
        }

        $allowed = [
            'offered' => ['offered', 'accepted', 'declined', 'cancelled'],
            'accepted' => ['accepted', 'completed', 'cancelled'],
        ];

        if (! in_array($nextStatus, $allowed[$previousStatus] ?? [$previousStatus], true)) {
            throw new ValidationException(['status' => "Cannot move match from $previousStatus to $nextStatus."]);
        }
    }
}
