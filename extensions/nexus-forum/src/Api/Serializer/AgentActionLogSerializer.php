<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\AgentActionLog;

class AgentActionLogSerializer extends AbstractSerializer
{
    protected $type = 'nexus-agent-action-logs';

    protected function getDefaultAttributes($log): array
    {
        /** @var AgentActionLog $log */
        return [
            'userId' => (int) $log->user_id,
            'actionType' => $log->action_type,
            'targetType' => $log->target_type,
            'targetId' => $log->target_id === null ? null : (int) $log->target_id,
            'status' => $log->status,
            'userConfirmed' => (bool) $log->user_confirmed,
            'inputSummary' => $this->decodeObject($log->input_summary),
            'outputSummary' => $this->decodeObject($log->output_summary),
            'ipAddress' => $log->ip_address,
            'createdAt' => $this->formatDate($log->created_at),
        ];
    }

    private function decodeObject(?string $value): ?array
    {
        if (! $value) {
            return null;
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : null;
    }

    protected function user($log)
    {
        return $this->hasOne($log, BasicUserSerializer::class);
    }
}
