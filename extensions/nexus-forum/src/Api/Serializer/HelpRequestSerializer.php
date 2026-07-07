<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicDiscussionSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Flarum\Http\UrlGenerator;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Service\AgentNextActionEnricher;

class HelpRequestSerializer extends AbstractSerializer
{
    protected $type = 'nexus-help-requests';

    private UrlGenerator $url;
    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(UrlGenerator $url, AgentNextActionEnricher $nextActionEnricher)
    {
        $this->url = $url;
        $this->nextActionEnricher = $nextActionEnricher;
    }

    protected function getDefaultAttributes($helpRequest): array
    {
        /** @var HelpRequest $helpRequest */
        $discussion = $helpRequest->discussion;
        $discussionUrl = $discussion
            ? $this->url->to('forum')->route('discussion', ['id' => (string) $discussion->id])
            : null;

        return [
            'discussionId' => (int) $helpRequest->discussion_id,
            'discussionUrl' => $discussionUrl,
            'requesterUserId' => (int) $helpRequest->requester_user_id,
            'status' => $helpRequest->status,
            'categoryLabel' => $helpRequest->category_label,
            'neededLabels' => $this->decodeList($helpRequest->needed_labels),
            'summary' => $helpRequest->summary,
            'urgency' => $helpRequest->urgency,
            'locationHint' => $helpRequest->location_hint,
            'meetingSafetyState' => $helpRequest->meeting_safety_state,
            'agentContext' => $this->decodeObject($helpRequest->agent_context),
            'nextActions' => $this->nextActions($helpRequest),
            'createdAt' => $this->formatDate($helpRequest->created_at),
            'updatedAt' => $this->formatDate($helpRequest->updated_at),
            'closedAt' => $this->formatDate($helpRequest->closed_at),
        ];
    }

    private function nextActions(HelpRequest $helpRequest): array
    {
        $actions = [
            [
                'name' => 'find_candidates',
                'method' => 'GET',
                'endpoint' => '/api/nexus/help-requests/'.$helpRequest->id.'/candidates',
                'requiresUserConfirmation' => false,
                'purpose' => 'Find existing capable helpers before dispatching or creating a direct match offer.',
            ],
        ];

        if (in_array($helpRequest->status, ['open', 'matching'], true)) {
            $actions[] = $this->nextActionEnricher->enrich([
                'name' => 'preflight_match_offer',
                'method' => 'POST',
                'endpoint' => '/api/nexus/agent-preflight',
                'requiresUserConfirmation' => false,
                'purpose' => 'Dry-run match.offer before asking the helper to make a public offer.',
                'body' => [
                    'data' => [
                        'type' => 'nexus-agent-preflights',
                        'attributes' => [
                            'action' => 'match.offer',
                            'userConfirmed' => false,
                            'target' => [
                                'type' => 'help_request',
                                'id' => (int) $helpRequest->id,
                            ],
                        ],
                    ],
                ],
            ]);
            $actions[] = $this->nextActionEnricher->enrich([
                'name' => 'offer_match',
                'method' => 'POST',
                'endpoint' => '/api/nexus/help-requests/'.$helpRequest->id.'/matches',
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
                'purpose' => 'Offer help after the helper confirms the exact public reply, meeting hint, and safety state.',
                'preflight' => [
                    'method' => 'POST',
                    'endpoint' => '/api/nexus/agent-preflight',
                    'body' => [
                        'data' => [
                            'type' => 'nexus-agent-preflights',
                            'attributes' => [
                                'action' => 'match.offer',
                                'userConfirmed' => false,
                                'target' => [
                                    'type' => 'help_request',
                                    'id' => (int) $helpRequest->id,
                                ],
                            ],
                        ],
                    ],
                ],
                'bodyTemplate' => [
                    'data' => [
                        'type' => 'nexus-help-matches',
                        'attributes' => [
                            'userConfirmed' => true,
                            'message' => '<helper-approved public offer message>',
                            'meetingHint' => '<public safe meeting hint if needed>',
                            'meetingSafetyState' => 'public_place_suggested',
                        ],
                    ],
                ],
            ], 'match.offer');
        }

        return $actions;
    }

    private function decodeList(?string $value): array
    {
        if (! $value) {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? array_values($decoded) : [];
    }

    private function decodeObject(?string $value): ?array
    {
        if (! $value) {
            return null;
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : null;
    }

    protected function discussion($helpRequest)
    {
        return $this->hasOne($helpRequest, BasicDiscussionSerializer::class);
    }

    protected function requester($helpRequest)
    {
        return $this->hasOne($helpRequest, BasicUserSerializer::class);
    }

    protected function matches($helpRequest)
    {
        return $this->hasMany($helpRequest, HelpMatchSerializer::class);
    }

    protected function dispatches($helpRequest)
    {
        return $this->hasMany($helpRequest, HelpDispatchSerializer::class);
    }
}
