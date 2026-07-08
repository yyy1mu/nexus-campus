<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpCandidateSerializer;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Model\UserCapability;
use Nexus\Forum\Agent\Service\AgentNextActionEnricher;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListHelpCandidatesController extends AbstractListController
{
    public $serializer = HelpCandidateSerializer::class;

    public $include = ['user'];

    public $optionalInclude = ['user'];

    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(AgentNextActionEnricher $nextActionEnricher)
    {
        $this->nextActionEnricher = $nextActionEnricher;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $helpRequestId = (int) Arr::get($request->getQueryParams(), 'id');
        $limit = min(max((int) Arr::get($request->getQueryParams(), 'page.limit', 20), 1), 50);
        $helpRequest = HelpRequest::query()->with('discussion')->findOrFail($helpRequestId);

        if (! $helpRequest->discussion || ! $helpRequest->discussion->newQuery()->where('id', $helpRequest->discussion_id)->whereVisibleTo($actor)->exists()) {
            throw new ModelNotFoundException;
        }

        $neededLabels = $this->decodeList($helpRequest->needed_labels);

        if (! $neededLabels && $helpRequest->category_label) {
            $neededLabels = [$helpRequest->category_label];
        }

        $query = UserCapability::query()
            ->where('is_active', true)
            ->where('user_id', '!=', $helpRequest->requester_user_id)
            ->with('user');

        if ($neededLabels) {
            $candidateUserIds = (clone $query)
                ->whereIn('label', $neededLabels)
                ->pluck('user_id')
                ->unique()
                ->values()
                ->all();

            $query->whereIn('user_id', $candidateUserIds);
        }

        $capabilities = $query->orderBy('updated_at', 'desc')->get();
        $byUser = [];

        foreach ($capabilities as $capability) {
            $userId = (int) $capability->user_id;

            if (! isset($byUser[$userId])) {
                $byUser[$userId] = [
                    'id' => (string) $userId,
                    'helpRequestId' => $helpRequest->id,
                    'userId' => $userId,
                    'matchedLabels' => [],
                    'score' => 0,
                    'capabilities' => [],
                    'user' => $capability->user,
                    'nextActions' => $this->candidateNextActions($helpRequest, $userId),
                ];
            }

            $isMatch = in_array($capability->label, $neededLabels, true);

            if ($isMatch) {
                $byUser[$userId]['matchedLabels'][$capability->label] = $capability->label;
                $byUser[$userId]['score'] += 10;
            }

            $byUser[$userId]['capabilities'][] = [
                'label' => $capability->label,
                'name' => $capability->name,
                'summary' => $capability->summary,
                'availability' => $capability->availability,
                'serviceRadiusM' => $capability->service_radius_m,
                'isMatched' => $isMatch,
            ];
        }

        $candidates = array_map(function (array $candidate) use ($neededLabels) {
            return $this->finalizeCandidate($candidate, $neededLabels);
        }, array_values($byUser));

        usort($candidates, function ($a, $b) {
            return $b['score'] <=> $a['score'];
        });

        return array_slice($candidates, 0, $limit);
    }

    private function finalizeCandidate(array $candidate, array $neededLabels): array
    {
        $matchedLabels = array_values($candidate['matchedLabels']);
        sort($matchedLabels);

        $neededLabels = array_values($neededLabels);
        $missingLabels = array_values(array_diff($neededLabels, $matchedLabels));
        sort($missingLabels);

        $matchedLabelCount = count($matchedLabels);
        $neededLabelCount = count($neededLabels);
        $missingLabelCount = count($missingLabels);
        $activeCapabilityCount = count($candidate['capabilities']);
        $matchedLabelScore = $matchedLabelCount * 10;
        $matchRatio = $neededLabelCount > 0 ? round($matchedLabelCount / $neededLabelCount, 2) : 0.0;

        $candidate['matchedLabels'] = $matchedLabels;
        $candidate['neededLabels'] = $neededLabels;
        $candidate['missingLabels'] = $missingLabels;
        $candidate['scoreBreakdown'] = [
            'matchedLabelCount' => $matchedLabelCount,
            'neededLabelCount' => $neededLabelCount,
            'matchedLabelScore' => $matchedLabelScore,
            'activeCapabilityCount' => $activeCapabilityCount,
            'missingLabelCount' => $missingLabelCount,
            'matchRatio' => $matchRatio,
            'rankReason' => $this->rankReason($matchedLabels, $neededLabels, $missingLabels),
        ];
        $candidate['recommendation'] = $this->recommendation($matchedLabels, $neededLabels, $missingLabels, $matchRatio);
        $candidate['dispatchRationaleTemplate'] = $this->dispatchRationaleTemplate($matchedLabels, $missingLabels);
        $candidate['confirmationPromptHints'] = [
            'requiresUserConfirmation' => true,
            'suggestedQuestion' => 'Do you want me to invite this helper with the shown message, rationale, meeting hint, and safety state?',
            'mustShowFields' => [
                'helperUserId',
                'matchedLabels',
                'missingLabels',
                'message',
                'rationale',
                'meetingHint',
                'meetingSafetyState',
                'sideEffects',
            ],
        ];

        return $candidate;
    }

    private function rankReason(array $matchedLabels, array $neededLabels, array $missingLabels): string
    {
        if (! $neededLabels) {
            return 'No requested labels were attached; ranked by active public capabilities only.';
        }

        if ($matchedLabels) {
            $reason = 'Matched '.count($matchedLabels).' of '.count($neededLabels).' requested labels: '.$this->formatLabels($matchedLabels).'.';

            if ($missingLabels) {
                $reason .= ' Missing labels to verify: '.$this->formatLabels($missingLabels).'.';
            }

            return $reason;
        }

        return 'No requested labels matched; inspect capabilities before dispatching.';
    }

    private function recommendation(array $matchedLabels, array $neededLabels, array $missingLabels, float $matchRatio): array
    {
        $recommended = count($matchedLabels) > 0;

        if (! $neededLabels) {
            $confidence = 'low';
            $reason = 'The help request has no needed labels, so this is not a label-backed recommendation.';
        } elseif (! $recommended) {
            $confidence = 'low';
            $reason = 'No requested labels matched.';
        } elseif (! $missingLabels) {
            $confidence = 'high';
            $reason = 'The helper matches all requested labels: '.$this->formatLabels($matchedLabels).'.';
        } elseif ($matchRatio >= 0.5) {
            $confidence = 'medium';
            $reason = 'The helper matches requested labels: '.$this->formatLabels($matchedLabels).'.';
        } else {
            $confidence = 'low';
            $reason = 'The helper has a partial label match: '.$this->formatLabels($matchedLabels).'.';
        }

        $caveats = [];

        if ($missingLabels) {
            $caveats[] = 'Verify missing requested labels before dispatch: '.$this->formatLabels($missingLabels).'.';
        }

        if (! $neededLabels) {
            $caveats[] = 'Ask the requester to clarify the needed capability labels before dispatching.';
        }

        return [
            'recommended' => $recommended,
            'confidence' => $confidence,
            'reason' => $reason,
            'caveats' => $caveats,
            'nextBestAction' => $recommended ? 'preflight_dispatch' : 'inspect_capabilities',
        ];
    }

    private function dispatchRationaleTemplate(array $matchedLabels, array $missingLabels): string
    {
        if ($matchedLabels) {
            $template = 'Matched labels: '.$this->formatLabels($matchedLabels).'.';
        } else {
            $template = 'No requested labels matched.';
        }

        if ($missingLabels) {
            $template .= ' Missing labels to verify: '.$this->formatLabels($missingLabels).'.';
        } else {
            $template .= ' All requested labels matched.';
        }

        return $template.' Ask the requester before dispatching.';
    }

    private function formatLabels(array $labels): string
    {
        if (! $labels) {
            return 'none';
        }

        return implode(', ', array_map(function (string $label) {
            return '#'.$label;
        }, $labels));
    }

    private function candidateNextActions(HelpRequest $helpRequest, int $helperUserId): array
    {
        return [
            $this->nextActionEnricher->enrich([
                'name' => 'preflight_dispatch',
                'method' => 'POST',
                'endpoint' => '/api/nexus/agent-preflight',
                'requiresUserConfirmation' => false,
                'purpose' => 'Dry-run dispatch.create before asking the requester to invite this helper.',
                'body' => [
                    'data' => [
                        'type' => 'nexus-agent-preflights',
                        'attributes' => [
                            'action' => 'dispatch.create',
                            'userConfirmed' => false,
                            'target' => [
                                'type' => 'help_request',
                                'id' => (int) $helpRequest->id,
                                'helperUserId' => $helperUserId,
                            ],
                        ],
                    ],
                ],
            ]),
            $this->nextActionEnricher->enrich([
                'name' => 'create_dispatch',
                'method' => 'POST',
                'endpoint' => '/api/nexus/help-requests/'.$helpRequest->id.'/dispatches',
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
                'purpose' => 'Invite this candidate helper after the requester confirms the exact message, rationale, meeting hint, and safety state.',
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
                                    'helperUserId' => $helperUserId,
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
                            'helperUserId' => $helperUserId,
                            'message' => '<requester-approved invitation message>',
                            'rationale' => '<why this helper matches the labels or context>',
                            'meetingHint' => '<public safe meeting hint if needed>',
                            'meetingSafetyState' => 'public_place_suggested',
                        ],
                    ],
                ],
            ], 'dispatch.create'),
        ];
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
