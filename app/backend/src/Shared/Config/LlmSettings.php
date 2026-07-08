<?php

namespace Nexus\Forum\Service;

use Flarum\Settings\SettingsRepositoryInterface;
use Flarum\Foundation\ValidationException;
use Nexus\Forum\Model\UserLlmSettings;

class LlmSettings
{
    public static function forUserId(int $userId, SettingsRepositoryInterface $settings): array
    {
        $row = UserLlmSettings::query()->find($userId);
        $provider = $row->provider ?? $settings->get('nexus-forum.default_llm_provider', 'builtin');
        $apiKey = (string) ($row->api_key ?? '');
        $defaultChatModel = $settings->get('nexus-forum.default_llm_chat_model', 'gpt-4o-mini');
        $defaultResponsesModel = $settings->get('nexus-forum.default_llm_responses_model', 'gpt-4.1-mini');

        if ($provider === 'builtin') {
            $apiKey = '';
        }

        return [
            'provider' => $provider,
            'baseUrl' => $provider === 'builtin' ? '' : ($row->base_url ?? $settings->get('nexus-forum.default_llm_base_url', '')),
            'chatModel' => $provider === 'builtin' ? $defaultChatModel : ($row->chat_model ?? $defaultChatModel),
            'responsesModel' => $provider === 'builtin' ? $defaultResponsesModel : ($row->responses_model ?? $defaultResponsesModel),
            'apiKeySet' => $apiKey !== '',
            'apiKeyPreview' => self::previewKey($apiKey),
            'supportsChatCompletions' => $row ? (bool) $row->supports_chat_completions : true,
            'supportsResponses' => $row ? (bool) $row->supports_responses : true,
        ];
    }

    public static function saveForUserId(int $userId, array $values, SettingsRepositoryInterface $settings): void
    {
        $row = UserLlmSettings::query()->find($userId);

        if (! $row) {
            $row = new UserLlmSettings;
            $row->user_id = $userId;
        }

        $row->provider = $values['provider'] ?? $row->provider ?? $settings->get('nexus-forum.default_llm_provider', 'builtin');
        $row->base_url = $values['baseUrl'] ?? $row->base_url ?? $settings->get('nexus-forum.default_llm_base_url', '');
        $row->chat_model = $values['chatModel'] ?? $row->chat_model ?? $settings->get('nexus-forum.default_llm_chat_model', 'gpt-4o-mini');
        $row->responses_model = $values['responsesModel'] ?? $row->responses_model ?? $settings->get('nexus-forum.default_llm_responses_model', 'gpt-4.1-mini');

        if (array_key_exists('apiKey', $values)) {
            $row->api_key = $values['apiKey'];
        }

        if (array_key_exists('supportsChatCompletions', $values)) {
            $row->supports_chat_completions = $values['supportsChatCompletions'];
        }

        if (array_key_exists('supportsResponses', $values)) {
            $row->supports_responses = $values['supportsResponses'];
        }

        if ($row->provider === 'builtin') {
            $row->base_url = '';
            $row->chat_model = $settings->get('nexus-forum.default_llm_chat_model', 'gpt-4o-mini');
            $row->responses_model = $settings->get('nexus-forum.default_llm_responses_model', 'gpt-4.1-mini');
            $row->api_key = '';
        }

        $row->save();
    }

    public static function validate(array $attributes): array
    {
        $allowed = [
            'provider',
            'baseUrl',
            'chatModel',
            'responsesModel',
            'apiKey',
            'supportsChatCompletions',
            'supportsResponses',
        ];

        $values = [];

        foreach ($allowed as $key) {
            if (array_key_exists($key, $attributes)) {
                $values[$key] = $attributes[$key];
            }
        }

        $provider = (string) ($values['provider'] ?? 'builtin');
        if (! in_array($provider, ['builtin', 'openai-compatible', 'openai-responses-compatible'], true)) {
            throw new ValidationException([
                'provider' => 'Provider must be builtin, openai-compatible, or openai-responses-compatible.',
            ]);
        }

        $values['provider'] = $provider;

        foreach (['baseUrl', 'chatModel', 'responsesModel', 'apiKey'] as $key) {
            if (isset($values[$key])) {
                $values[$key] = trim((string) $values[$key]);
            }
        }

        if (($values['baseUrl'] ?? '') !== '' && ! preg_match('~^https?://~i', $values['baseUrl'])) {
            throw new ValidationException([
                'baseUrl' => 'Base URL must start with http:// or https://.',
            ]);
        }

        foreach (['chatModel', 'responsesModel'] as $key) {
            if (($values[$key] ?? '') !== '' && mb_strlen($values[$key]) > 120) {
                throw new ValidationException([
                    $key => 'Model name is too long.',
                ]);
            }
        }

        if (isset($values['apiKey']) && mb_strlen($values['apiKey']) > 300) {
            throw new ValidationException([
                'apiKey' => 'API key is too long.',
            ]);
        }

        foreach (['supportsChatCompletions', 'supportsResponses'] as $key) {
            if (isset($values[$key])) {
                $values[$key] = (bool) $values[$key];
            }
        }

        if ($provider === 'builtin') {
            $values['baseUrl'] = '';
            $values['apiKey'] = '';
        }

        return $values;
    }

    private static function previewKey(string $key): string
    {
        if ($key === '') {
            return '';
        }

        if (strlen($key) <= 8) {
            return str_repeat('*', strlen($key));
        }

        return substr($key, 0, 4).str_repeat('*', max(strlen($key) - 8, 4)).substr($key, -4);
    }
}
