<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Http\RequestUtil;
use Flarum\Foundation\ValidationException;
use Flarum\Settings\SettingsRepositoryInterface;
use Flarum\User\Exception\NotAuthenticatedException;
use Illuminate\Support\Arr;
use Laminas\Diactoros\Response\JsonResponse;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\LlmSettings;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;

class UpdateLlmSettingsController implements RequestHandlerInterface
{
    private SettingsRepositoryInterface $settings;

    private AgentActionLogger $actionLogger;

    public function __construct(SettingsRepositoryInterface $settings, AgentActionLogger $actionLogger)
    {
        $this->settings = $settings;
        $this->actionLogger = $actionLogger;
    }

    public function handle(ServerRequestInterface $request): ResponseInterface
    {
        $actor = RequestUtil::getActor($request);

        if ($actor->isGuest()) {
            throw new NotAuthenticatedException;
        }

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating LLM settings requires explicit user confirmation.',
            ]);
        }

        $validated = LlmSettings::validate($attributes);

        LlmSettings::saveForUserId($actor->id, $validated, $this->settings);
        $current = LlmSettings::forUserId($actor->id, $this->settings);

        $this->actionLogger->succeeded(
            $actor,
            'llm_settings.update',
            'llm_settings',
            (int) $actor->id,
            [
                'provider' => $validated['provider'] ?? null,
                'baseUrlSet' => ($validated['baseUrl'] ?? '') !== '',
                'chatModel' => $validated['chatModel'] ?? null,
                'responsesModel' => $validated['responsesModel'] ?? null,
                'apiKeyChanged' => array_key_exists('apiKey', $validated),
                'supportsChatCompletions' => $validated['supportsChatCompletions'] ?? null,
                'supportsResponses' => $validated['supportsResponses'] ?? null,
            ],
            [
                'provider' => $current['provider'] ?? null,
                'apiKeySet' => $current['apiKeySet'] ?? false,
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return new JsonResponse([
            'data' => [
                'type' => 'nexus-llm-settings',
                'id' => (string) $actor->id,
                'attributes' => $current,
            ],
        ], 200, [
            'content-type' => 'application/vnd.api+json',
        ]);
    }
}
