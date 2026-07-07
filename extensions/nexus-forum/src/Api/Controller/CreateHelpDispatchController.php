<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\Notification\NotificationSyncer;
use Flarum\User\Exception\PermissionDeniedException;
use Flarum\User\User;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpDispatchSerializer;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Notification\HelpDispatchBlueprint;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\AgentAuthorization;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateHelpDispatchController extends AbstractCreateController
{
    public $serializer = HelpDispatchSerializer::class;

    public $include = ['helper', 'requester', 'helpRequest', 'helpRequest.discussion'];

    private NotificationSyncer $notifications;

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    public function __construct(
        NotificationSyncer $notifications,
        AgentActionLogger $actionLogger,
        AgentAuthorization $authorization
    )
    {
        $this->notifications = $notifications;
        $this->actionLogger = $actionLogger;
        $this->authorization = $authorization;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $helpRequestId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $helpRequest = HelpRequest::query()->with(['discussion', 'requester'])->findOrFail($helpRequestId);

        if ((int) $helpRequest->requester_user_id !== (int) $actor->id && ! $actor->isAdmin()) {
            throw new PermissionDeniedException;
        }

        if (! in_array($helpRequest->status, ['open', 'matching'], true)) {
            throw new ValidationException(['status' => 'Only open or matching help requests can be dispatched.']);
        }

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Dispatching a help request requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'dispatch Nexus help requests');

        $helperUserId = (int) ($attributes['helperUserId'] ?? 0);
        if ($helperUserId <= 0) {
            throw new ValidationException(['helperUserId' => 'helperUserId is required.']);
        }

        if ($helperUserId === (int) $helpRequest->requester_user_id) {
            throw new ValidationException(['helperUserId' => 'A requester cannot dispatch their own request to themselves.']);
        }

        $helper = User::query()->findOrFail($helperUserId);
        $message = NexusPayload::string($attributes, 'message', 2000, false);
        $rationale = NexusPayload::string($attributes, 'rationale', 2000, false);
        $meetingHint = NexusPayload::string($attributes, 'meetingHint', 255, false);
        $meetingSafetyState = NexusPayload::oneOf(
            $attributes,
            'meetingSafetyState',
            ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
            'not_arranged'
        );

        $dispatch = HelpDispatch::query()
            ->where('help_request_id', $helpRequest->id)
            ->where('helper_user_id', $helper->id)
            ->first();

        if ($dispatch && $dispatch->status === 'accepted') {
            throw new ValidationException(['helperUserId' => 'This helper has already accepted the dispatch.']);
        }

        if (! $dispatch) {
            $dispatch = new HelpDispatch;
            $dispatch->help_request_id = $helpRequest->id;
            $dispatch->requester_user_id = $helpRequest->requester_user_id;
            $dispatch->helper_user_id = $helper->id;
        }

        $dispatch->status = 'pending';
        $dispatch->message = $message;
        $dispatch->rationale = $rationale;
        $dispatch->response_message = null;
        $dispatch->meeting_hint = $meetingHint;
        $dispatch->meeting_safety_state = $meetingSafetyState;
        $dispatch->expires_at = $this->expiresAt($attributes);
        $dispatch->responded_at = null;
        $dispatch->save();

        $dispatch->setRelation('helper', $helper);
        $dispatch->setRelation('requester', $helpRequest->requester);
        $dispatch->setRelation('helpRequest', $helpRequest);

        if ($helpRequest->status === 'open') {
            $helpRequest->status = 'matching';
            $helpRequest->save();
        }

        $this->notifications->sync(new HelpDispatchBlueprint($dispatch), [$helper]);

        $this->actionLogger->succeeded(
            $actor,
            'dispatch.create',
            'help_dispatch',
            (int) $dispatch->id,
            [
                'helpRequestId' => (int) $helpRequest->id,
                'helperUserId' => (int) $helper->id,
                'messageLength' => $this->actionLogger->length($message),
                'rationaleLength' => $this->actionLogger->length($rationale),
                'meetingHintSet' => $meetingHint !== null,
                'meetingSafetyState' => $meetingSafetyState,
                'expiresAtSet' => $dispatch->expires_at !== null,
            ],
            [
                'status' => $dispatch->status,
                'helpRequestStatus' => $helpRequest->status,
                'notificationType' => 'nexusHelpDispatch',
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $dispatch;
    }

    private function expiresAt(array $attributes): ?Carbon
    {
        $expiresAt = trim((string) ($attributes['expiresAt'] ?? ''));

        if ($expiresAt === '') {
            return null;
        }

        try {
            return Carbon::parse($expiresAt);
        } catch (\Throwable $e) {
            throw new ValidationException(['expiresAt' => 'expiresAt must be a valid datetime.']);
        }
    }
}
