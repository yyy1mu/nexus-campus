<?php

namespace Nexus\Forum\Http\Middleware;

use Flarum\Http\AccessToken;
use Flarum\Http\DeveloperAccessToken;
use Flarum\User\Exception\PermissionDeniedException;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;

class RestrictNexusAgentTokenWrites implements MiddlewareInterface
{
    private const TOKEN_PREFIX = 'Token ';
    private const AGENT_TOKEN_TITLE_PREFIX = 'Nexus local agent';

    public function process(Request $request, Handler $handler): Response
    {
        if ($this->isNexusAgentToken($request) && ! $this->isAllowedForNexusAgentToken($request)) {
            throw new PermissionDeniedException('Nexus local agent tokens must use /api/nexus/* for writes.');
        }

        return $handler->handle($request);
    }

    private function isNexusAgentToken(Request $request): bool
    {
        $token = $this->accessTokenFromHeader($request);

        if (! $token || $token->type !== DeveloperAccessToken::$type) {
            return false;
        }

        $title = trim((string) $token->title);

        return $title !== '' && stripos($title, self::AGENT_TOKEN_TITLE_PREFIX) === 0;
    }

    private function accessTokenFromHeader(Request $request): ?AccessToken
    {
        $parts = explode(';', $request->getHeaderLine('authorization'));
        $credential = trim($parts[0] ?? '');

        if (substr($credential, 0, strlen(self::TOKEN_PREFIX)) !== self::TOKEN_PREFIX) {
            return null;
        }

        $token = trim(substr($credential, strlen(self::TOKEN_PREFIX)));

        if ($token === '') {
            return null;
        }

        return AccessToken::findValid($token);
    }

    private function isAllowedForNexusAgentToken(Request $request): bool
    {
        $method = strtoupper($request->getMethod());

        if (in_array($method, ['GET', 'HEAD', 'OPTIONS'], true)) {
            return true;
        }

        $path = $this->normalizedPath($request);

        if ($path === '/nexus' || strpos($path, '/nexus/') === 0) {
            return true;
        }

        // Keep self-service revocation possible for a local-agent token.
        if ($method === 'DELETE' && preg_match('#^/access-tokens/[^/]+/?$#', $path)) {
            return true;
        }

        return false;
    }

    private function normalizedPath(Request $request): string
    {
        $path = '/'.trim($request->getUri()->getPath(), '/');

        return $path === '/' ? '/' : rtrim($path, '/');
    }
}
