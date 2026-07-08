<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Nexus\Forum\Agent\Service\AgentNextActionEnricher;

class CapabilityLabelSerializer extends AbstractSerializer
{
    protected $type = 'nexus-capability-labels';

    private AgentNextActionEnricher $nextActionEnricher;

    public function __construct(AgentNextActionEnricher $nextActionEnricher)
    {
        $this->nextActionEnricher = $nextActionEnricher;
    }

    public function getId($label)
    {
        return (string) $label['label'];
    }

    protected function getDefaultAttributes($label): array
    {
        return [
            'label' => $label['label'],
            'name' => $label['name'],
            'helperCount' => (int) $label['helperCount'],
            'capabilityCount' => (int) $label['capabilityCount'],
            'sampleCapabilities' => array_values($label['sampleCapabilities']),
            'reuseGuidance' => $this->reuseGuidance($label),
            'nextActions' => $this->nextActions($label),
            'createdAt' => $this->formatDate($label['createdAt']),
            'updatedAt' => $this->formatDate($label['updatedAt']),
        ];
    }

    private function reuseGuidance(array $label): array
    {
        $labelName = (string) $label['label'];
        $helperCount = (int) $label['helperCount'];

        return [
            'recommendedForReuse' => $helperCount > 0,
            'why' => $helperCount > 0
                ? 'This public label already has active helper profiles; prefer it over creating a near-duplicate label.'
                : 'No active helpers are currently visible for this label; keep searching before relying on it.',
            'useInFields' => [
                'helpRequestNeededLabels' => 'data.attributes.neededLabels[]',
                'capabilityProfileLabel' => 'data.attributes.capabilities[].label',
                'capabilitySearchFilter' => 'filter[label]',
            ],
            'matchingRule' => 'Prefer exact label reuse first, then close human-meaning matches with helperCount > 0, then a new concise label only after read-before-write discovery.',
            'normalizedLabel' => $labelName,
        ];
    }

    private function nextActions(array $label): array
    {
        $labelName = (string) $label['label'];

        return [
            $this->nextActionEnricher->enrich([
                'name' => 'use_label_for_help_request',
                'method' => 'POST',
                'endpoint' => '/api/nexus/help-requests',
                'requiresUserConfirmation' => true,
                'catalogAction' => 'help_request.create',
                'writeBodySchemaRef' => '#/components/schemas/HelpRequestInput',
                'proposedFields' => ['neededLabels', 'title', 'summary', 'content', 'urgency', 'locationHint', 'meetingSafetyState', 'userConfirmed'],
                'bodyTemplate' => [
                    'data' => [
                        'type' => 'nexus-help-requests',
                        'attributes' => [
                            'userConfirmed' => true,
                            'neededLabels' => [$labelName],
                            'meetingSafetyState' => 'public_place_suggested',
                        ],
                    ],
                ],
                'why' => 'Use this existing label in a confirmed help request instead of creating a near-duplicate label.',
            ], 'help_request.create'),
            [
                'name' => 'find_helpers_with_label',
                'method' => 'GET',
                'endpoint' => '/api/nexus/capabilities',
                'requiresUserConfirmation' => false,
                'query' => [
                    'filter[label]' => $labelName,
                    'page[limit]' => 10,
                ],
                'writesState' => false,
                'why' => 'Find public helper profiles that have opted into this capability label.',
            ],
            [
                'name' => 'search_open_help_requests_with_label',
                'method' => 'GET',
                'endpoint' => '/api/nexus/help-requests',
                'requiresUserConfirmation' => false,
                'query' => [
                    'filter[status]' => 'open',
                    'filter[label]' => $labelName,
                    'page[limit]' => 10,
                ],
                'writesState' => false,
                'why' => 'Check whether a related open help request already exists before posting a duplicate.',
            ],
        ];
    }
}
