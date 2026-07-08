<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;

class HelpCandidateSerializer extends AbstractSerializer
{
    protected $type = 'nexus-help-candidates';

    public function getId($candidate)
    {
        return (string) $candidate['userId'];
    }

    protected function getDefaultAttributes($candidate): array
    {
        return [
            'helpRequestId' => (int) $candidate['helpRequestId'],
            'userId' => (int) $candidate['userId'],
            'matchedLabels' => array_values($candidate['matchedLabels']),
            'neededLabels' => array_values($candidate['neededLabels'] ?? []),
            'missingLabels' => array_values($candidate['missingLabels'] ?? []),
            'score' => (int) $candidate['score'],
            'scoreBreakdown' => $candidate['scoreBreakdown'] ?? null,
            'recommendation' => $candidate['recommendation'] ?? null,
            'dispatchRationaleTemplate' => $candidate['dispatchRationaleTemplate'] ?? null,
            'confirmationPromptHints' => $candidate['confirmationPromptHints'] ?? null,
            'capabilities' => array_values($candidate['capabilities']),
            'nextActions' => array_values($candidate['nextActions'] ?? []),
        ];
    }

    protected function user($candidate)
    {
        return $this->hasOne($candidate, BasicUserSerializer::class);
    }
}
