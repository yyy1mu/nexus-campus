<?php

namespace Nexus\Forum\Service;

use Flarum\Foundation\ValidationException;
use Flarum\Http\UrlGenerator;
use Illuminate\Support\Arr;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpRequest;
use Psr\Http\Message\ServerRequestInterface;

class WorkItemFeed
{
    private UrlGenerator $url;
    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(UrlGenerator $url, AgentNextActionEnricher $nextActionEnricher)
    {
        $this->url = $url;
        $this->nextActionEnricher = $nextActionEnricher;
    }

    public function forUser(int $userId, array $filters = [], int $limit = 20, int $offset = 0): array
    {
        $role = $filters['role'] ?? null;
        $kind = $filters['kind'] ?? null;
        $status = $filters['status'] ?? null;

        $this->validate($role, $kind);

        $items = [];

        if ((! $role || $role === 'helper') && (! $kind || $kind === 'dispatch')) {
            $items = array_merge($items, $this->helperDispatchItems($userId));
        }

        if (! $kind || $kind === 'match') {
            $items = array_merge($items, $this->matchItems($userId, $role));
        }

        if ((! $role || $role === 'requester') && (! $kind || $kind === 'help_request')) {
            $items = array_merge($items, $this->requesterHelpRequestItems($userId));
        }

        if ($status) {
            $items = array_values(array_filter($items, function (array $item) use ($status) {
                return $item['status'] === (string) $status;
            }));
        }

        usort($items, function (array $a, array $b) {
            $priority = $b['priority'] <=> $a['priority'];

            if ($priority !== 0) {
                return $priority;
            }

            $aTime = $a['updatedAt'] ? $a['updatedAt']->getTimestamp() : 0;
            $bTime = $b['updatedAt'] ? $b['updatedAt']->getTimestamp() : 0;

            return $bTime <=> $aTime;
        });

        return array_slice($items, $offset, $limit);
    }

    public function forRequest(ServerRequestInterface $request, int $userId): array
    {
        $params = $request->getQueryParams();

        return $this->forUser(
            $userId,
            [
                'role' => Arr::get($params, 'filter.role') ?: Arr::get($params, 'role'),
                'kind' => Arr::get($params, 'filter.kind') ?: Arr::get($params, 'kind'),
                'status' => Arr::get($params, 'filter.status') ?: Arr::get($params, 'status'),
            ],
            $this->limitFromRequest($request),
            $this->offsetFromRequest($request)
        );
    }

    public function summarize(array $items): array
    {
        $byKind = [];
        $byRole = [];
        $byAction = [];

        foreach ($items as $item) {
            $byKind[$item['kind']] = ($byKind[$item['kind']] ?? 0) + 1;
            $byRole[$item['role']] = ($byRole[$item['role']] ?? 0) + 1;
            $byAction[$item['action']] = ($byAction[$item['action']] ?? 0) + 1;
        }

        ksort($byKind);
        ksort($byRole);
        ksort($byAction);

        return [
            'total' => count($items),
            'byKind' => $byKind,
            'byRole' => $byRole,
            'byAction' => $byAction,
            'topActions' => array_values(array_slice(array_map(function (array $item) {
                return [
                    'kind' => $item['kind'],
                    'role' => $item['role'],
                    'action' => $item['action'],
                    'status' => $item['status'],
                    'priority' => (int) $item['priority'],
                    'helpRequestId' => $item['helpRequestId'],
                    'dispatchId' => $item['dispatchId'],
                    'matchId' => $item['matchId'],
                    'title' => $item['title'],
                    'nextActions' => $item['nextActions'],
                ];
            }, $items), 0, 5)),
        ];
    }

    public function limitFromRequest(ServerRequestInterface $request): int
    {
        return min(max((int) Arr::get($request->getQueryParams(), 'page.limit', 20), 1), 50);
    }

    public function offsetFromRequest(ServerRequestInterface $request): int
    {
        return max((int) Arr::get($request->getQueryParams(), 'page.offset', 0), 0);
    }

    private function validate(?string $role, ?string $kind): void
    {
        if ($role && ! in_array($role, ['requester', 'helper'], true)) {
            throw new ValidationException([
                'role' => 'role must be requester or helper.',
            ]);
        }

        if ($kind && ! in_array($kind, ['help_request', 'dispatch', 'match'], true)) {
            throw new ValidationException([
                'kind' => 'kind must be help_request, dispatch, or match.',
            ]);
        }
    }

    private function helperDispatchItems(int $actorId): array
    {
        $dispatches = HelpDispatch::query()
            ->where('helper_user_id', $actorId)
            ->where('status', 'pending')
            ->with(['helpRequest', 'helpRequest.discussion'])
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        $items = [];

        foreach ($dispatches as $dispatch) {
            $helpRequest = $dispatch->helpRequest;

            if (! $helpRequest) {
                continue;
            }

            $items[] = $this->baseItem(
                'dispatch:'.$dispatch->id,
                'dispatch',
                'helper',
                'respond_to_dispatch',
                $dispatch->status,
                100,
                $helpRequest,
                (int) $dispatch->id,
                $dispatch->match_id === null ? null : (int) $dispatch->match_id,
                (int) $dispatch->requester_user_id,
                (int) $dispatch->helper_user_id,
                $dispatch->meeting_safety_state,
                $dispatch->created_at,
                $dispatch->updated_at,
                [
                    $this->dispatchPreflightAction(
                        'preflight_dispatch_response',
                        $dispatch,
                        'Dry-run dispatch.update before asking the helper to accept or decline this invitation.'
                    ),
                    $this->dispatchUpdateAction(
                        'accept_dispatch',
                        $dispatch,
                        'accepted',
                        'Accept this dispatch after the helper confirms the exact public response, meeting hint, and safety state.',
                        [
                            'responseMessage' => '<helper-approved public acceptance message>',
                            'meetingHint' => '<public safe meeting hint>',
                            'meetingSafetyState' => 'public_place_suggested',
                        ]
                    ),
                    $this->dispatchUpdateAction(
                        'decline_dispatch',
                        $dispatch,
                        'declined',
                        'Decline this dispatch after the helper confirms the response.',
                        [
                            'responseMessage' => '<helper-approved decline message>',
                        ]
                    ),
                ]
            );
        }

        return $items;
    }

    private function matchItems(int $actorId, ?string $role): array
    {
        $query = HelpMatch::query()
            ->with(['helpRequest', 'helpRequest.discussion'])
            ->whereIn('status', ['offered', 'accepted']);

        if ($role === 'helper') {
            $query->where('helper_user_id', $actorId);
        } elseif ($role === 'requester') {
            $query->whereHas('helpRequest', function ($query) use ($actorId) {
                $query->where('requester_user_id', $actorId);
            });
        } else {
            $query->where(function ($query) use ($actorId) {
                $query
                    ->where('helper_user_id', $actorId)
                    ->orWhereHas('helpRequest', function ($query) use ($actorId) {
                        $query->where('requester_user_id', $actorId);
                    });
            });
        }

        $matches = $query
            ->orderBy('updated_at', 'desc')
            ->limit(50)
            ->get();

        $items = [];

        foreach ($matches as $match) {
            $helpRequest = $match->helpRequest;

            if (! $helpRequest) {
                continue;
            }

            $isRequester = (int) $helpRequest->requester_user_id === $actorId;
            $itemRole = $isRequester ? 'requester' : 'helper';

            if ($match->status === 'offered' && $isRequester) {
                $action = 'review_match_offer';
                $priority = 95;
                $nextActions = [
                    $this->matchPreflightAction(
                        'preflight_match_accept',
                        $match,
                        'match.update',
                        'Dry-run match.update before asking the requester to accept this helper offer.',
                        'accepted'
                    ),
                    $this->matchUpdateAction(
                        'accept_match',
                        $match,
                        'accepted',
                        'Accept this offer after the requester confirms the helper, public meeting hint, and safety state.',
                        [
                            'meetingHint' => '<requester-approved public safe meeting hint>',
                            'meetingSafetyState' => 'public_place_confirmed',
                        ]
                    ),
                    $this->matchUpdateAction(
                        'decline_match',
                        $match,
                        'declined',
                        'Decline this offer after requester confirmation.'
                    ),
                ];
            } elseif ($match->status === 'offered') {
                $action = 'await_requester_response';
                $priority = 45;
                $nextActions = [
                    $this->matchPreflightAction(
                        'preflight_offer_cancel',
                        $match,
                        'match.update',
                        'Dry-run match.update before asking the helper to cancel this offer.',
                        'cancelled'
                    ),
                    $this->matchUpdateAction(
                        'cancel_offer',
                        $match,
                        'cancelled',
                        'Cancel this pending offer after helper confirmation.'
                    ),
                ];
            } else {
                $action = 'coordinate_match';
                $priority = 80;
                $nextActions = [
                    $this->readAction(
                        'list_messages',
                        '/api/nexus/matches/'.$match->id.'/messages',
                        'Read private coordination messages for this accepted match.'
                    ),
                    $this->matchPreflightAction(
                        'preflight_match_message',
                        $match,
                        'match_message.create',
                        'Dry-run match_message.create before asking the user to send private coordination text.'
                    ),
                    $this->matchMessageAction($match),
                    $this->matchPreflightAction(
                        'preflight_match_complete',
                        $match,
                        'match.update',
                        'Dry-run match.update before asking a participant to mark the help as completed.',
                        'completed'
                    ),
                    $this->matchUpdateAction(
                        'complete_match',
                        $match,
                        'completed',
                        'Mark the match completed after a participant confirms the work is finished.'
                    ),
                    $this->matchUpdateAction(
                        'cancel_match',
                        $match,
                        'cancelled',
                        'Cancel this accepted match after a participant confirms coordination should stop.'
                    ),
                ];
            }

            $items[] = $this->baseItem(
                'match:'.$match->id,
                'match',
                $itemRole,
                $action,
                $match->status,
                $priority,
                $helpRequest,
                null,
                (int) $match->id,
                (int) $helpRequest->requester_user_id,
                (int) $match->helper_user_id,
                $match->meeting_safety_state,
                $match->created_at,
                $match->updated_at,
                $nextActions
            );
        }

        return $items;
    }

    private function requesterHelpRequestItems(int $actorId): array
    {
        $helpRequests = HelpRequest::query()
            ->where('requester_user_id', $actorId)
            ->whereIn('status', ['open', 'matching'])
            ->with('discussion')
            ->orderBy('updated_at', 'desc')
            ->limit(50)
            ->get();

        $items = [];

        foreach ($helpRequests as $helpRequest) {
            $items[] = $this->baseItem(
                'help_request:'.$helpRequest->id,
                'help_request',
                'requester',
                'route_help_request',
                $helpRequest->status,
                $helpRequest->status === 'matching' ? 70 : 60,
                $helpRequest,
                null,
                null,
                (int) $helpRequest->requester_user_id,
                null,
                $helpRequest->meeting_safety_state,
                $helpRequest->created_at,
                $helpRequest->updated_at,
                [
                    $this->readAction(
                        'find_candidates',
                        '/api/nexus/help-requests/'.$helpRequest->id.'/candidates',
                        'Find existing capable helpers before dispatching. Candidate results include helper-specific preflight and create_dispatch templates.'
                    ),
                    $this->helpRequestDispatchPreflightAction($helpRequest),
                    $this->helpRequestDispatchTemplateAction($helpRequest),
                    $this->readAction(
                        'list_matches',
                        '/api/nexus/help-requests/'.$helpRequest->id.'/matches',
                        'Review direct match offers on this help request.'
                    ),
                ]
            );
        }

        return $items;
    }

    private function baseItem(
        string $id,
        string $kind,
        string $role,
        string $action,
        string $status,
        int $priority,
        HelpRequest $helpRequest,
        ?int $dispatchId,
        ?int $matchId,
        ?int $requesterUserId,
        ?int $helperUserId,
        ?string $meetingSafetyState,
        $createdAt,
        $updatedAt,
        array $nextActions
    ): array {
        $discussion = $helpRequest->discussion;

        return [
            'id' => $id,
            'kind' => $kind,
            'role' => $role,
            'action' => $action,
            'status' => $status,
            'priority' => $priority,
            'title' => $discussion ? $discussion->title : 'Nexus help request #'.$helpRequest->id,
            'summary' => $helpRequest->summary,
            'helpRequestId' => (int) $helpRequest->id,
            'dispatchId' => $dispatchId,
            'matchId' => $matchId,
            'discussionId' => $helpRequest->discussion_id === null ? null : (int) $helpRequest->discussion_id,
            'discussionUrl' => $discussion ? $this->url->to('forum')->route('discussion', ['id' => (string) $discussion->id]) : null,
            'requesterUserId' => $requesterUserId,
            'helperUserId' => $helperUserId,
            'neededLabels' => $this->decodeList($helpRequest->needed_labels),
            'meetingSafetyState' => $meetingSafetyState,
            'nextActions' => $nextActions,
            'createdAt' => $createdAt,
            'updatedAt' => $updatedAt,
        ];
    }

    private function readAction(string $name, string $endpoint, string $purpose): array
    {
        return [
            'name' => $name,
            'method' => 'GET',
            'endpoint' => $endpoint,
            'requiresUserConfirmation' => false,
            'purpose' => $purpose,
        ];
    }

    private function helpRequestDispatchPreflightAction(HelpRequest $helpRequest): array
    {
        return $this->nextActionEnricher->enrich([
            'name' => 'preflight_dispatch',
            'method' => 'POST',
            'endpoint' => '/api/nexus/agent-preflight',
            'requiresUserConfirmation' => false,
            'purpose' => 'Dry-run dispatch.create for this help request before selecting a helper. Prefer the helper-specific candidate preflight after find_candidates returns.',
            'body' => [
                'data' => [
                    'type' => 'nexus-agent-preflights',
                    'attributes' => [
                        'action' => 'dispatch.create',
                        'userConfirmed' => false,
                        'target' => [
                            'type' => 'help_request',
                            'id' => (int) $helpRequest->id,
                        ],
                    ],
                ],
            ],
        ]);
    }

    private function helpRequestDispatchTemplateAction(HelpRequest $helpRequest): array
    {
        return $this->nextActionEnricher->enrich([
            'name' => 'create_dispatch',
            'method' => 'POST',
            'endpoint' => '/api/nexus/help-requests/'.$helpRequest->id.'/dispatches',
            'requiresUserConfirmation' => true,
            'requiredPermission' => 'allowAgentMatching',
            'purpose' => 'Invite a selected candidate helper after requester confirmation. Use find_candidates first so helperUserId is known.',
            'preflight' => [
                'method' => 'POST',
                'endpoint' => '/api/nexus/agent-preflight',
                'body' => [
                    'data' => [
                        'type' => 'nexus-agent-preflights',
                        'attributes' => [
                            'action' => 'dispatch.create',
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
                    'type' => 'nexus-help-dispatches',
                    'attributes' => [
                        'userConfirmed' => true,
                        'helperUserId' => '<candidate helper user id from find_candidates>',
                        'message' => '<requester-approved invitation message>',
                        'rationale' => '<why this helper matches the labels or context>',
                        'meetingHint' => '<public safe meeting hint if needed>',
                        'meetingSafetyState' => 'public_place_suggested',
                    ],
                ],
            ],
        ], 'dispatch.create');
    }

    private function dispatchPreflightAction(string $name, HelpDispatch $dispatch, string $purpose, ?string $status = null): array
    {
        $attributes = [
            'action' => 'dispatch.update',
            'userConfirmed' => false,
            'target' => [
                'type' => 'help_dispatch',
                'id' => (int) $dispatch->id,
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
                'body' => $this->dispatchPreflightAction('preflight_'.$name, $dispatch, $purpose, $status)['body'],
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

    private function matchPreflightAction(string $name, HelpMatch $match, string $action, string $purpose, ?string $status = null): array
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
                'body' => $this->matchPreflightAction('preflight_'.$name, $match, 'match.update', $purpose, $status)['body'],
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

    private function matchMessageAction(HelpMatch $match): array
    {
        return $this->nextActionEnricher->enrich([
            'name' => 'send_match_message',
            'method' => 'POST',
            'endpoint' => '/api/nexus/matches/'.$match->id.'/messages',
            'requiresUserConfirmation' => true,
            'requiredPermission' => 'allowAgentMatching',
            'purpose' => 'Send a private coordination message only after the user approves the exact text.',
            'preflight' => [
                'method' => 'POST',
                'endpoint' => '/api/nexus/agent-preflight',
                'body' => $this->matchPreflightAction(
                    'preflight_match_message',
                    $match,
                    'match_message.create',
                    'Dry-run match_message.create before asking the user to send private coordination text.'
                )['body'],
            ],
            'bodyTemplate' => [
                'data' => [
                    'type' => 'nexus-help-match-messages',
                    'attributes' => [
                        'userConfirmed' => true,
                        'content' => '<user-approved private coordination message>',
                        'agentContext' => [
                            'source' => 'nexus-work-items.nextActions',
                        ],
                    ],
                ],
            ],
        ], 'match_message.create');
    }

    private function decodeList(?string $value): array
    {
        if (! $value) {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? array_values($decoded) : [];
    }
}
