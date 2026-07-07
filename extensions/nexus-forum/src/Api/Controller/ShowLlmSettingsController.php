<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Http\RequestUtil;
use Flarum\Settings\SettingsRepositoryInterface;
use Flarum\User\Exception\NotAuthenticatedException;
use Laminas\Diactoros\Response\JsonResponse;
use Nexus\Forum\Service\LlmSettings;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;

class ShowLlmSettingsController implements RequestHandlerInterface
{
    private SettingsRepositoryInterface $settings;

    public function __construct(SettingsRepositoryInterface $settings)
    {
        $this->settings = $settings;
    }

    public function handle(ServerRequestInterface $request): ResponseInterface
    {
        $actor = RequestUtil::getActor($request);

        if ($actor->isGuest()) {
            throw new NotAuthenticatedException;
        }

        return new JsonResponse([
            'data' => [
                'type' => 'nexus-llm-settings',
                'id' => (string) $actor->id,
                'attributes' => LlmSettings::forUserId($actor->id, $this->settings),
            ],
        ], 200, [
            'content-type' => 'application/vnd.api+json',
        ]);
    }
}
