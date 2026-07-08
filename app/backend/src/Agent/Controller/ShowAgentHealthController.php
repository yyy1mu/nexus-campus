<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Http\UrlGenerator;
use Laminas\Diactoros\Response\JsonResponse;
use Nexus\Forum\Agent\Service\AgentPreflightCatalog;
use Nexus\Forum\Shared\Tooling\OpenApiTooling;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;

class ShowAgentHealthController implements RequestHandlerInterface
{
    private const AGENT_TOKEN_TITLE_PREFIX = 'Nexus local agent';

    private UrlGenerator $url;

    public function __construct(UrlGenerator $url)
    {
        $this->url = $url;
    }

    public function handle(ServerRequestInterface $request): ResponseInterface
    {
        return new JsonResponse([
            'data' => [
                'type' => 'nexus-agent-health',
                'id' => 'public',
                'attributes' => [
                    'schemaVersion' => '0.1',
                    'status' => 'ok',
                    'generatedAt' => gmdate('c'),
                    'nexus' => [
                        'role' => 'agent_skill_api',
                        'forumShell' => 'flarum_native',
                        'apiStyle' => 'jsonapi',
                        'openApiVersion' => OpenApiTooling::OPENAPI_VERSION,
                        'localAgentTokenTitlePrefix' => self::AGENT_TOKEN_TITLE_PREFIX,
                    ],
                    'openApiTooling' => OpenApiTooling::summary(),
                    'docs' => [
                        'publicGuide' => $this->requestPath($request, 'docs/'),
                        'rootAgentEntry' => $this->requestPath($request, 'llms.txt'),
                        'agentTools' => $this->requestPath($request, 'docs/agent-tools.json'),
                        'agentQuickstart' => $this->requestPath($request, 'docs/agent-quickstart.md'),
                        'agentRecipes' => $this->requestPath($request, 'docs/agent-recipes.md'),
                        'agentEntry' => $this->requestPath($request, 'docs/llms.txt'),
                        'nexusSkill' => $this->requestPath($request, 'docs/nexus-skill.md'),
                        'openapi' => $this->requestPath($request, 'docs/openapi.json'),
                        'manifest' => $this->requestPath($request, '.well-known/nexus-agent.json'),
                        'manifestSchema' => $this->requestPath($request, 'schemas/nexus-agent-manifest.v1.json'),
                    ],
                    'endpoints' => [
                        'agentHealth' => '/api/nexus/agent-health',
                        'agentContext' => '/api/nexus/me/agent-context',
                        'agentPreflight' => '/api/nexus/agent-preflight',
                        'needDrafts' => '/api/nexus/need-drafts',
                        'workItems' => '/api/nexus/me/work-items',
                        'capabilityLabels' => '/api/nexus/capability-labels',
                        'capabilities' => '/api/nexus/capabilities',
                        'forumGateway' => '/api/nexus/forum/discussions',
                        'forumDiscussion' => '/api/nexus/forum/discussions/{id}',
                        'helpRequests' => '/api/nexus/help-requests',
                    ],
                    'capabilities' => [
                        'publicReadReady' => true,
                        'docsReady' => true,
                        'manifestReady' => true,
                        'openApiReady' => true,
                        'authenticatedBootstrapReady' => true,
                        'agentPreflightReady' => true,
                        'workQueueReady' => true,
                        'controlledForumGatewayReady' => true,
                        'physicalHelpFlowReady' => true,
                        'writesRequireAuthentication' => true,
                        'writesRequireUserConfirmed' => true,
                        'physicalWritesRequireAllowAgentMatching' => true,
                        'llmProviderOptionalForLocalAgents' => true,
                        'agentPreflightActionCount' => count(AgentPreflightCatalog::actionNames()),
                    ],
                    'checks' => [
                        'publicDiscovery' => $this->check(true, 'Manifest, docs, OpenAPI, public labels, public help requests, and forum search are expected to be reachable without authentication.'),
                        'authenticatedBootstrap' => $this->check(true, 'Use GET /api/nexus/me/agent-context after authentication for private current-user readiness, work queue, and action catalog state.'),
                        'preflightDryRun' => $this->check(true, 'Use POST /api/nexus/agent-preflight before uncertain writes; it is advisory and does not mutate state.'),
                        'writeBoundary' => $this->check(true, 'Local-agent writes should stay under /api/nexus/* and include userConfirmed=true when changing state.'),
                    ],
                    'nextActions' => [
                        $this->action('read_root_agent_entry', 'GET', '/llms.txt', false, 'Read the root agent entry when starting from only the site origin.'),
                        $this->action('read_agent_tools', 'GET', '/docs/agent-tools.json', false, 'Read the compact machine-readable tool contract for goal-to-tool planning.'),
                        $this->action('read_manifest', 'GET', '/.well-known/nexus-agent.json', false, 'Resolve same-origin docs and endpoint links.'),
                        $this->action('read_quickstart', 'GET', '/docs/agent-quickstart.md', false, 'Read the shortest local-agent onboarding path.'),
                        $this->action('read_agent_recipes', 'GET', '/docs/agent-recipes.md', false, 'Read the core task matrix for create help request, candidates, dispatch, dispatch response, match response, match messaging, and work queue polling.'),
                        $this->action('read_openapi', 'GET', '/docs/openapi.json', false, 'Load concrete JSON:API schemas and stable operationId tool names before generating requests.'),
                        $this->action('search_public_context', 'GET', '/api/nexus/capability-labels', false, 'Verify public read access and reuse existing capability labels.'),
                        $this->action('authenticate_then_bootstrap', 'GET', '/api/nexus/me/agent-context', true, 'After the user supplies a token, fetch live private skill state.'),
                    ],
                    'notes' => [
                        'publicEndpoint' => true,
                        'doesNotAuthenticateUser' => true,
                        'doesNotReturnPrivateState' => true,
                        'doesNotWriteDatabase' => true,
                        'doesNotReplaceAgentContext' => true,
                    ],
                ],
            ],
        ], 200, [
            'content-type' => 'application/vnd.api+json',
        ]);
    }

    private function check(bool $ready, string $reason): array
    {
        return [
            'ready' => $ready,
            'reason' => $reason,
        ];
    }

    private function action(string $name, string $method, string $endpoint, bool $requiresAuthentication, string $purpose): array
    {
        return [
            'name' => $name,
            'method' => $method,
            'endpoint' => $endpoint,
            'requiresAuthentication' => $requiresAuthentication,
            'requiresUserConfirmation' => false,
            'purpose' => $purpose,
        ];
    }

    private function forumPath(string $path): string
    {
        return $this->url->to('forum')->path($path);
    }

    private function requestPath(ServerRequestInterface $request, string $path): string
    {
        $origin = $this->requestOrigin($request);

        if ($origin === null) {
            return $this->forumPath($path);
        }

        return $origin.'/'.ltrim($path, '/');
    }

    private function requestOrigin(ServerRequestInterface $request): ?string
    {
        $uri = $request->getUri();
        $scheme = $this->firstForwardedHeader($request, 'X-Forwarded-Proto') ?: $uri->getScheme() ?: 'http';
        $host = $this->firstForwardedHeader($request, 'X-Forwarded-Host') ?: $request->getHeaderLine('Host');

        if ($host === '') {
            $host = $uri->getHost();
            $port = $uri->getPort();

            if ($host !== '' && $port !== null && ! in_array($port, [80, 443], true)) {
                $host .= ':'.$port;
            }
        }

        $host = trim($host);

        if ($host === '') {
            return null;
        }

        return $scheme.'://'.$host;
    }

    private function firstForwardedHeader(ServerRequestInterface $request, string $name): ?string
    {
        $value = trim($request->getHeaderLine($name));

        if ($value === '') {
            return null;
        }

        $parts = explode(',', $value);

        return trim($parts[0]) ?: null;
    }
}
