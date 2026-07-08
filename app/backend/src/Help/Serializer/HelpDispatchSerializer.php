<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Agent\Service\AgentNextActionEnricher;

class HelpDispatchSerializer extends AbstractSerializer
{
    protected $type = 'nexus-help-dispatches';

    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(AgentNextActionEnricher $nextActionEnricher)
    {
        $this->nextActionEnricher = $nextActionEnricher;
    }

    protected function getDefaultAttributes($dispatch): array
    {
        /** @var HelpDispatch $dispatch */
        return [
            'helpRequestId' => (int) $dispatch->help_request_id,
            'requesterUserId' => (int) $dispatch->requester_user_id,
            'helperUserId' => (int) $dispatch->helper_user_id,
            'matchId' => $dispatch->match_id === null ? null : (int) $dispatch->match_id,
            'status' => $dispatch->status,
            'message' => $dispatch->message,
            'rationale' => $dispatch->rationale,
            'responseMessage' => $dispatch->response_message,
            'meetingHint' => $dispatch->meeting_hint,
            'meetingSafetyState' => $dispatch->meeting_safety_state,
            'expiresAt' => $this->formatDate($dispatch->expires_at),
            'respondedAt' => $this->formatDate($dispatch->responded_at),
            'viewerRole' => $this->viewerRole($dispatch),
            'nextActions' => $this->nextActions($dispatch),
            'createdAt' => $this->formatDate($dispatch->created_at),
            'updatedAt' => $this->formatDate($dispatch->updated_at),
        ];
    }

    private function viewerRole(HelpDispatch $dispatch): ?string
    {
        if (! $this->actor || $this->actor->isGuest()) {
            return null;
        }

        if ((int) $dispatch->helper_user_id === (int) $this->actor->id) {
            return 'helper';
        }

        if ((int) $dispatch->requester_user_id === (int) $this->actor->id) {
            return 'requester';
        }

        return $this->actor->isAdmin() ? 'admin' : null;
    }

    private function nextActions(HelpDispatch $dispatch): array
    {
        $role = $this->viewerRole($dispatch);
        $actions = [];

        if ($dispatch->status === 'pending' && $role === 'helper') {
            $actions[] = $this->preflightAction(
                'preflight_dispatch_response',
                'dispatch.update',
                'Dry-run dispatch.update before asking the helper to accept or decline this invitation.',
                $dispatch
            );
            $actions[] = $this->dispatchUpdateAction(
                'accept_dispatch',
                $dispatch,
                'accepted',
                'Accept this dispatch after the helper confirms the exact public response, meeting hint, and safety state.',
                [
                    'responseMessage' => '<helper-approved public acceptance message>',
                    'meetingHint' => '<public safe meeting hint>',
                    'meetingSafetyState' => 'public_place_suggested',
                ]
            );
            $actions[] = $this->dispatchUpdateAction(
                'decline_dispatch',
                $dispatch,
                'declined',
                'Decline this dispatch after the helper confirms the response.',
                [
                    'responseMessage' => '<helper-approved decline message>',
                ]
            );
        }

        if ($dispatch->status === 'pending' && ($role === 'requester' || $role === 'admin')) {
            $actions[] = $this->preflightAction(
                'preflight_dispatch_cancel',
                'dispatch.update',
                'Dry-run dispatch.update before asking the requester to cancel this invitation.',
                $dispatch,
                'cancelled'
            );
            $actions[] = $this->dispatchUpdateAction(
                'cancel_dispatch',
                $dispatch,
                'cancelled',
                'Cancel this pending dispatch after requester confirmation.',
                [
                    'responseMessage' => '<requester-approved cancellation note>',
                ]
            );
        }

        if ($dispatch->status === 'accepted' && $dispatch->match_id !== null && in_array($role, ['requester', 'helper', 'admin'], true)) {
            $actions[] = [
                'name' => 'list_match_messages',
                'method' => 'GET',
                'endpoint' => '/api/nexus/matches/'.$dispatch->match_id.'/messages',
                'requiresUserConfirmation' => false,
                'purpose' => 'Read accepted-match private coordination messages for the requester/helper pair.',
            ];
            $actions[] = $this->preflightAction(
                'preflight_match_message',
                'match_message.create',
                'Dry-run match_message.create before asking the user to send private coordination text.',
                $dispatch
            );
            $actions[] = $this->nextActionEnricher->enrich([
                'name' => 'send_match_message',
                'method' => 'POST',
                'endpoint' => '/api/nexus/matches/'.$dispatch->match_id.'/messages',
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
                                    'id' => (int) $dispatch->match_id,
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
                                'source' => 'nexus-help-dispatches.nextActions',
                            ],
                        ],
                    ],
                ],
            ], 'match_message.create');
        }

        return $actions;
    }

    private function preflightAction(string $name, string $action, string $purpose, HelpDispatch $dispatch, ?string $status = null): array
    {
        $attributes = [
            'action' => $action,
            'userConfirmed' => false,
        ];

        if ($action === 'match_message.create' && $dispatch->match_id !== null) {
            $attributes['target'] = [
                'type' => 'help_match',
                'id' => (int) $dispatch->match_id,
            ];
        } else {
            $attributes['target'] = [
                'type' => 'help_dispatch',
                'id' => (int) $dispatch->id,
            ];
        }

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

    private function dispatchUpdateAction(string $name, HelpDispatch $dispatch, string $status, string $purpose, array $attributes): array
    {
        return $this->nextActionEnricher->enrich([
            'name' => $name,
            'method' => 'PATCH',
            'endpoint' => '/api/nexus/dispatches/'.$dispatch->id,
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
                            'action' => 'dispatch.update',
                            'userConfirmed' => false,
                            'target' => [
                                'type' => 'help_dispatch',
                                'id' => (int) $dispatch->id,
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
                    'type' => 'nexus-help-dispatches',
                    'attributes' => array_merge([
                        'userConfirmed' => true,
                        'status' => $status,
                    ], $attributes),
                ],
            ],
        ], 'dispatch.update');
    }

    protected function helpRequest($dispatch)
    {
        return $this->hasOne($dispatch, HelpRequestSerializer::class);
    }

    protected function requester($dispatch)
    {
        return $this->hasOne($dispatch, BasicUserSerializer::class);
    }

    protected function helper($dispatch)
    {
        return $this->hasOne($dispatch, BasicUserSerializer::class);
    }

    protected function match($dispatch)
    {
        return $this->hasOne($dispatch, HelpMatchSerializer::class);
    }
}
