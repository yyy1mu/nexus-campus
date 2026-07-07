<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractShowController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\User\Exception\PermissionDeniedException;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpRequestSerializer;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\AgentAuthorization;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateHelpRequestController extends AbstractShowController
{
    public $serializer = HelpRequestSerializer::class;

    public $include = ['discussion', 'requester', 'matches', 'matches.helper'];

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    public function __construct(AgentActionLogger $actionLogger, AgentAuthorization $authorization)
    {
        $this->actionLogger = $actionLogger;
        $this->authorization = $authorization;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $id = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $helpRequest = HelpRequest::query()->with(['discussion', 'requester', 'matches', 'matches.helper'])->findOrFail($id);

        if ((int) $helpRequest->requester_user_id !== (int) $actor->id && ! $actor->isAdmin()) {
            throw new PermissionDeniedException;
        }

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating a help request requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'update Nexus help request state');

        $previous = [
            'status' => $helpRequest->status,
            'meetingSafetyState' => $helpRequest->meeting_safety_state,
            'locationHintSet' => $helpRequest->location_hint !== null,
            'summaryLength' => $this->actionLogger->length($helpRequest->summary),
        ];

        if (array_key_exists('status', $attributes)) {
            $helpRequest->status = NexusPayload::oneOf($attributes, 'status', ['open', 'matching', 'matched', 'closed', 'cancelled'], $helpRequest->status);
        }

        if (array_key_exists('meetingSafetyState', $attributes)) {
            $helpRequest->meeting_safety_state = NexusPayload::oneOf(
                $attributes,
                'meetingSafetyState',
                ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
                $helpRequest->meeting_safety_state
            );
        }

        if (array_key_exists('locationHint', $attributes)) {
            $helpRequest->location_hint = NexusPayload::string($attributes, 'locationHint', 255, false);
        }

        if (array_key_exists('summary', $attributes)) {
            $helpRequest->summary = NexusPayload::string($attributes, 'summary', 2000, true);
        }

        if (array_key_exists('neededLabels', $attributes)) {
            $helpRequest->needed_labels = json_encode(NexusPayload::stringList($attributes, 'neededLabels', 12), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        if (in_array($helpRequest->status, ['closed', 'cancelled'], true) && ! $helpRequest->closed_at) {
            $helpRequest->closed_at = Carbon::now();
        } elseif (! in_array($helpRequest->status, ['closed', 'cancelled'], true)) {
            $helpRequest->closed_at = null;
        }

        if (! $helpRequest->summary) {
            throw new ValidationException(['summary' => 'summary is required.']);
        }

        $helpRequest->save();

        $this->actionLogger->succeeded(
            $actor,
            'help_request.update',
            'help_request',
            (int) $helpRequest->id,
            [
                'previous' => $previous,
                'changedKeys' => array_values(array_intersect(array_keys($attributes), [
                    'status',
                    'meetingSafetyState',
                    'locationHint',
                    'summary',
                    'neededLabels',
                ])),
                'summaryLength' => $this->actionLogger->length($helpRequest->summary),
                'neededLabels' => array_key_exists('neededLabels', $attributes)
                    ? NexusPayload::stringList($attributes, 'neededLabels', 12)
                    : null,
            ],
            [
                'status' => $helpRequest->status,
                'closedAtSet' => $helpRequest->closed_at !== null,
                'meetingSafetyState' => $helpRequest->meeting_safety_state,
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $helpRequest;
    }
}
