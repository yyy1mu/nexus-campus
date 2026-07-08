<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Agent\Service\AgentNextActionEnricher;

class HelpMatchSerializer extends AbstractSerializer
{
    protected $type = 'nexus-help-matches';

    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(AgentNextActionEnricher $nextActionEnricher)
    {
        $this->nextActionEnricher = $nextActionEnricher;
    }

    protected function getDefaultAttributes($match): array
    {
        /** @var HelpMatch $match */
        return [
            'helpRequestId' => (int) $match->help_request_id,
            'helperUserId' => (int) $match->helper_user_id,
            'status' => $match->status,
            'message' => $match->message,
            'meetingHint' => $match->meeting_hint,
            'meetingSafetyState' => $match->meeting_safety_state,
            'viewerRole' => $this->viewerRole($match),
            'nextActions' => $this->nextActions($match),
            'createdAt' => $this->formatDate($match->created_at),
            'updatedAt' => $this->formatDate($match->updated_at),
            'acceptedAt' => $this->formatDate($match->accepted_at),
            'completedAt' => $this->formatDate($match->completed_at),
        ];
    }

    private function viewerRole(HelpMatch $match): ?string
    {
        if (! $this->actor || $this->actor->isGuest()) {
            return null;
        }

        if ((int) $match->helper_user_id === (int) $this->actor->id) {
            return 'helper';
        }

        $helpRequest = $match->helpRequest;
        if ($helpRequest && (int) $helpRequest->requester_user_id === (int) $this->actor->id) {
            return 'requester';
        }

        return $this->actor->isAdmin() ? 'admin' : null;
    }

    private function nextActions(HelpMatch $match): array
    {
        $role = $this->viewerRole($match);
        $actions = [];

        if ($match->status === 'offered' && ($role === 'requester' || $role === 'admin')) {
            $actions[] = $this->preflightAction(
                'preflight_match_accept',
                'match.update',
                'Dry-run match.update before asking the requester to accept this helper offer.',
                $match,
                'accepted'
            );
            $actions[] = $this->matchUpdateAction(
                'accept_match',
                $match,
                'accepted',
                'Accept this offer after the requester confirms the helper, public meeting hint, and safety state.',
                [
                    'meetingHint' => '<requester-approved public safe meeting hint>',
                    'meetingSafetyState' => 'public_place_confirmed',
                ]
            );
            $actions[] = $this->matchUpdateAction(
                'decline_match',
                $match,
                'declined',
                'Decline this offer after requester confirmation.'
            );
        }

        if ($match->status === 'offered' && ($role === 'helper' || $role === 'admin')) {
            $actions[] = $this->preflightAction(
                'preflight_offer_cancel',
                'match.update',
                'Dry-run match.update before asking the helper to cancel this offer.',
                $match,
                'cancelled'
            );
            $actions[] = $this->matchUpdateAction(
                'cancel_offer',
                $match,
                'cancelled',
                'Cancel this pending offer after helper confirmation.'
            );
        }

        if ($match->status === 'accepted' && in_array($role, ['requester', 'helper', 'admin'], true)) {
            $actions[] = [
                'name' => 'list_messages',
                'method' => 'GET',
                'endpoint' => '/api/nexus/matches/'.$match->id.'/messages',
                'requiresUserConfirmation' => false,
                'purpose' => 'Read private coordination messages for this accepted match.',
            ];
            $actions[] = $this->preflightAction(
                'preflight_match_message',
                'match_message.create',
                'Dry-run match_message.create before asking the user to send private coordination text.',
                $match
            );
            $actions[] = $this->nextActionEnricher->enrich([
                'name' => 'send_match_message',
                'method' => 'POST',
                'endpoint' => '/api/nexus/matches/'.$match->id.'/messages',
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
                'purpose' => 'Send a private coordination message only after the user approves the exact text.',
                'preflight' => [
                    'method' => 'POST',
                    'endpoint' => '/api/nexus/agent-preflight',
                    'body' => [
                        'data' => [
                            'type' => 'nexus-agent-preflights',
                            'attributes' => [
                                'action' => 'match_message.create',
                                'userConfirmed' => false,
                                'target' => [
                                    'type' => 'help_match',
                                    'id' => (int) $match->id,
                                ],
                            ],
                        ],
                    ],
                ],
                'bodyTemplate' => [
                    'data' => [
                        'type' => 'nexus-help-match-messages',
                        'attributes' => [
                            'userConfirmed' => true,
                            'content' => '<user-approved private coordination message>',
                            'agentContext' => [
                                'source' => 'nexus-help-matches.nextActions',
                            ],
                        ],
                    ],
                ],
            ], 'match_message.create');
            $actions[] = $this->preflightAction(
                'preflight_match_complete',
                'match.update',
                'Dry-run match.update before asking a participant to mark the help as completed.',
                $match,
                'completed'
            );
            $actions[] = $this->matchUpdateAction(
                'complete_match',
                $match,
                'completed',
                'Mark the match completed after a participant confirms the work is finished.'
            );
            $actions[] = $this->matchUpdateAction(
                'cancel_match',
                $match,
                'cancelled',
                'Cancel this accepted match after a participant confirms coordination should stop.'
            );
        }

        return $actions;
    }

    private function preflightAction(string $name, string $action, string $purpose, HelpMatch $match, ?string $status = null): array
    {
        $attributes = [
            'action' => $action,
            'userConfirmed' => false,
            'target' => [
                'type' => 'help_match',
                'id' => (int) $match->id,
            ],
        ];

        if ($status !== null) {
            $attributes['proposed'] = [
                'status' => $status,
            ];
        }

        return $this->nextActionEnricher->enrich([
            'name' => $name,
            'method' => 'POST',
            'endpoint' => '/api/nexus/agent-preflight',
            'requiresUserConfirmation' => false,
            'purpose' => $purpose,
            'body' => [
                'data' => [
                    'type' => 'nexus-agent-preflights',
                    'attributes' => $attributes,
                ],
            ],
        ]);
    }

    private function matchUpdateAction(string $name, HelpMatch $match, string $status, string $purpose, array $attributes = []): array
    {
        return $this->nextActionEnricher->enrich([
            'name' => $name,
            'method' => 'PATCH',
            'endpoint' => '/api/nexus/matches/'.$match->id,
            'requiresUserConfirmation' => true,
            'requiredPermission' => 'allowAgentMatching',
            'purpose' => $purpose,
            'preflight' => [
                'method' => 'POST',
                'endpoint' => '/api/nexus/agent-preflight',
                'body' => [
                    'data' => [
                        'type' => 'nexus-agent-preflights',
                        'attributes' => [
                            'action' => 'match.update',
                            'userConfirmed' => false,
                            'target' => [
                                'type' => 'help_match',
                                'id' => (int) $match->id,
                            ],
                            'proposed' => [
                                'status' => $status,
                            ],
                        ],
                    ],
                ],
            ],
            'bodyTemplate' => [
                'data' => [
                    'type' => 'nexus-help-matches',
                    'attributes' => array_merge([
                        'userConfirmed' => true,
                        'status' => $status,
                    ], $attributes),
                ],
            ],
        ], 'match.update');
    }

    protected function helpRequest($match)
    {
        return $this->hasOne($match, HelpRequestSerializer::class);
    }

    protected function helper($match)
    {
        return $this->hasOne($match, BasicUserSerializer::class);
    }

    protected function messages($match)
    {
        return $this->hasMany($match, HelpMatchMessageSerializer::class);
    }
}
