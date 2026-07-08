<?php

namespace Nexus\Forum\Service;

use Carbon\Carbon;
use Flarum\User\User;
use Nexus\Forum\Model\AgentActionLog;

class AgentActionLogger
{
    public function succeeded(
        User $actor,
        string $actionType,
        string $targetType,
        ?int $targetId,
        array $inputSummary = [],
        array $outputSummary = [],
        ?string $ipAddress = null,
        bool $userConfirmed = false
    ): AgentActionLog {
        $log = new AgentActionLog;
        $log->user_id = $actor->id;
        $log->action_type = $actionType;
        $log->target_type = $targetType;
        $log->target_id = $targetId;
        $log->status = 'succeeded';
        $log->user_confirmed = $userConfirmed;
        $log->input_summary = $this->encodeSummary($inputSummary);
        $log->output_summary = $this->encodeSummary($outputSummary);
        $log->ip_address = $this->stringOrNull($ipAddress, 45);
        $log->created_at = Carbon::now();
        $log->save();

        return $log;
    }

    public function length(?string $value): int
    {
        return $value === null ? 0 : mb_strlen($value);
    }

    public function keys($value): array
    {
        if (! is_array($value)) {
            return [];
        }

        return array_values(array_map('strval', array_keys($value)));
    }

    private function encodeSummary(array $summary): ?string
    {
        $summary = $this->sanitize($summary);

        if ($summary === []) {
            return null;
        }

        $encoded = json_encode($summary, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        if ($encoded === false) {
            return null;
        }

        if (strlen($encoded) <= 4000) {
            return $encoded;
        }

        $fallback = json_encode([
            'truncated' => true,
            'summaryKeys' => array_values(array_map('strval', array_keys($summary))),
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        return $fallback === false ? null : $fallback;
    }

    private function sanitize($value)
    {
        if (is_array($value)) {
            $clean = [];

            foreach ($value as $key => $item) {
                $keyString = (string) $key;
                if ($this->isSecretKey($keyString)) {
                    $clean[$keyString] = '[redacted]';
                } else {
                    $clean[$keyString] = $this->sanitize($item);
                }
            }

            return $clean;
        }

        if (is_string($value)) {
            return $this->stringOrNull($value, 300);
        }

        if (is_bool($value) || is_int($value) || is_float($value) || $value === null) {
            return $value;
        }

        return (string) $value;
    }

    private function isSecretKey(string $key): bool
    {
        return (bool) preg_match('/api.?key|token|secret|password|authorization|cookie|csrf/i', $key);
    }

    private function stringOrNull(?string $value, int $max): ?string
    {
        if ($value === null || trim($value) === '') {
            return null;
        }

        $value = trim($value);

        if (mb_strlen($value) <= $max) {
            return $value;
        }

        return mb_substr($value, 0, $max - 12).'...[truncated]';
    }
}
