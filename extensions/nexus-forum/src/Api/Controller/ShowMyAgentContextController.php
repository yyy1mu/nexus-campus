<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Http\RequestUtil;
use Flarum\Http\UrlGenerator;
use Flarum\Settings\SettingsRepositoryInterface;
use Flarum\User\Exception\NotAuthenticatedException;
use Laminas\Diactoros\Response\JsonResponse;
use Nexus\Forum\Model\AgentActionLog;
use Nexus\Forum\Model\AgentProfile;
use Nexus\Forum\Model\UserCapability;
use Nexus\Forum\Service\AgentPreflightCatalog;
use Nexus\Forum\Service\LlmSettings;
use Nexus\Forum\Service\OpenApiTooling;
use Nexus\Forum\Service\WorkItemFeed;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;

class ShowMyAgentContextController implements RequestHandlerInterface
{
    private const AGENT_TOKEN_TITLE_PREFIX = 'Nexus local agent';

    private SettingsRepositoryInterface $settings;
    private UrlGenerator $url;
    private WorkItemFeed $workItemFeed;

    public function __construct(SettingsRepositoryInterface $settings, UrlGenerator $url, WorkItemFeed $workItemFeed)
    {
        $this->settings = $settings;
        $this->url = $url;
        $this->workItemFeed = $workItemFeed;
    }

    public function handle(ServerRequestInterface $request): ResponseInterface
    {
        $actor = RequestUtil::getActor($request);

        if ($actor->isGuest()) {
            throw new NotAuthenticatedException;
        }

        $profile = $this->profileForUser((int) $actor->id);
        $capabilities = $this->capabilitiesForUser((int) $actor->id);
        $workItems = $this->workItemFeed->forUser((int) $actor->id, [], 20, 0);
        $workQueue = $this->workItemFeed->summarize($workItems);
        $llmSettings = LlmSettings::forUserId((int) $actor->id, $this->settings);

        return new JsonResponse([
            'data' => [
                'type' => 'nexus-agent-contexts',
                'id' => (string) $actor->id,
                'attributes' => [
                    'schemaVersion' => '0.7',
                    'generatedAt' => gmdate('c'),
                    'user' => [
                        'id' => (int) $actor->id,
                        'username' => $actor->username,
                        'displayName' => $actor->display_name,
                        'avatarUrl' => $actor->avatar_url,
                    ],
                    'agentToken' => [
                        'recommendedTitlePrefix' => self::AGENT_TOKEN_TITLE_PREFIX,
                        'writeBoundary' => 'Tokens titled with this prefix may read normal APIs, write through /api/nexus/*, and revoke tokens; raw Flarum writes are rejected.',
                    ],
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
                    ],
                    'openApiTooling' => OpenApiTooling::summary(),
                    'endpoints' => [
                        'agentHealth' => '/api/nexus/agent-health',
                        'agentContext' => '/api/nexus/me/agent-context',
                        'agentPreflight' => '/api/nexus/agent-preflight',
                        'needDrafts' => '/api/nexus/need-drafts',
                        'capabilityLabels' => '/api/nexus/capability-labels',
                        'capabilities' => '/api/nexus/capabilities',
                        'forumGateway' => '/api/nexus/forum/discussions',
                        'forumDiscussion' => '/api/nexus/forum/discussions/{id}',
                        'forumDiscussionPosts' => '/api/nexus/forum/discussions/{id}/posts',
                        'forumPost' => '/api/nexus/forum/posts/{id}',
                        'helpRequests' => '/api/nexus/help-requests',
                        'helpRequest' => '/api/nexus/help-requests/{id}',
                        'helpCandidates' => '/api/nexus/help-requests/{id}/candidates',
                        'helpDispatches' => '/api/nexus/help-requests/{id}/dispatches',
                        'helpMatches' => '/api/nexus/help-requests/{id}/matches',
                        'dispatch' => '/api/nexus/dispatches/{id}',
                        'match' => '/api/nexus/matches/{id}',
                        'matchMessages' => '/api/nexus/matches/{id}/messages',
                        'workItems' => '/api/nexus/me/work-items',
                        'agentProfile' => '/api/nexus/me/agent-profile',
                        'myCapabilities' => '/api/nexus/me/capabilities',
                        'myHelpRequests' => '/api/nexus/me/help-requests',
                        'myDispatches' => '/api/nexus/me/dispatches',
                        'myMatches' => '/api/nexus/me/matches',
                        'myForumDiscussions' => '/api/nexus/me/discussions',
                        'myForumPosts' => '/api/nexus/me/posts',
                        'myDeviceSignals' => '/api/nexus/me/device-signals',
                        'actionLogs' => '/api/nexus/me/action-logs',
                        'deviceSignals' => '/api/nexus/device-signals',
                        'llmSettings' => '/api/nexus/llm-settings',
                    ],
                    'agentProfile' => $this->profileSummary($profile),
                    'agentPreflight' => [
                        'endpoint' => '/api/nexus/agent-preflight',
                        'catalogSchemaVersion' => '0.3',
                        'actions' => AgentPreflightCatalog::actions(),
                        'actionDefinitionFields' => [
                            'endpoint',
                            'purpose',
                            'requiresConfirmation',
                            'permissions',
                            'targetType',
                            'targetRequiredForPreflight',
                            'targetIdAliases',
                            'proposedFields',
                            'allowedProposedStatus',
                            'writeBodySchemaRef',
                            'sideEffects',
                            'examplePreflightBody',
                        ],
                        'notes' => [
                            'preflightOnly' => true,
                            'noDatabaseWrite' => true,
                            'stillUseTargetEndpoint' => true,
                        ],
                    ],
                    'capabilities' => $capabilities,
                    'llm' => $this->llmSummary($llmSettings),
                    'workQueue' => $workQueue,
                    'recentActionLog' => $this->recentActionLogSummary((int) $actor->id),
                    'agentReadiness' => $this->agentReadiness($profile, $capabilities, $llmSettings, $workQueue),
                    'operatingRules' => [
                        'readDocsFirst' => '/docs/nexus-skill.md',
                        'draftBeforeWrite' => true,
                        'explicitConfirmationRequiredForWrites' => true,
                        'physicalCoordinationRequiresAllowAgentMatching' => true,
                        'useNexusForumGatewayForAgentAuthoredForumWrites' => true,
                        'preferPublicMeetingPlaces' => true,
                    ],
                    'skillInstructions' => $this->skillInstructions($profile, $capabilities, $workQueue),
                ],
            ],
        ], 200, [
            'content-type' => 'application/vnd.api+json',
        ]);
    }

    private function profileForUser(int $userId): AgentProfile
    {
        $profile = AgentProfile::query()->where('user_id', $userId)->first();

        if ($profile) {
            return $profile;
        }

        $profile = new AgentProfile;
        $profile->user_id = $userId;
        $profile->allow_agent_posting = false;
        $profile->allow_agent_replying = false;
        $profile->allow_agent_matching = false;
        $profile->allow_location_matching = false;
        $profile->location_visibility = 'off';

        return $profile;
    }

    private function profileSummary(AgentProfile $profile): array
    {
        return [
            'userId' => (int) $profile->user_id,
            'agentName' => $profile->agent_name,
            'agentAvatarUrl' => $profile->agent_avatar_url,
            'soulMdSet' => trim((string) $profile->soul_md) !== '',
            'soulMdLength' => mb_strlen((string) $profile->soul_md),
            'interestTags' => $this->decodeList($profile->interest_tags),
            'skillTags' => $this->decodeList($profile->skill_tags),
            'helpTags' => $this->decodeList($profile->help_tags),
            'matchPreferences' => $this->decodeObject($profile->match_preferences) ?: [],
            'permissions' => [
                'allowAgentPosting' => (bool) $profile->allow_agent_posting,
                'allowAgentReplying' => (bool) $profile->allow_agent_replying,
                'allowAgentMatching' => (bool) $profile->allow_agent_matching,
                'allowLocationMatching' => (bool) $profile->allow_location_matching,
                'locationVisibility' => $profile->location_visibility ?: 'off',
            ],
            'missingSetup' => $this->missingSetup($profile),
            'updatedAt' => $profile->updated_at ? $profile->updated_at->toJSON() : null,
        ];
    }

    private function capabilitiesForUser(int $userId): array
    {
        return UserCapability::query()
            ->where('user_id', $userId)
            ->orderBy('label')
            ->get()
            ->map(function (UserCapability $capability) {
                return [
                    'label' => $capability->label,
                    'name' => $capability->name,
                    'summary' => $capability->summary,
                    'availability' => $capability->availability,
                    'serviceRadiusM' => $capability->service_radius_m === null ? null : (int) $capability->service_radius_m,
                    'isActive' => (bool) $capability->is_active,
                    'updatedAt' => $capability->updated_at ? $capability->updated_at->toJSON() : null,
                ];
            })
            ->values()
            ->all();
    }

    private function llmSummary(array $llmSettings): array
    {
        return [
            'provider' => $llmSettings['provider'],
            'baseUrl' => $llmSettings['baseUrl'],
            'chatModel' => $llmSettings['chatModel'],
            'responsesModel' => $llmSettings['responsesModel'],
            'apiKeySet' => (bool) $llmSettings['apiKeySet'],
            'apiKeyPreview' => $llmSettings['apiKeyPreview'],
            'supportsChatCompletions' => (bool) $llmSettings['supportsChatCompletions'],
            'supportsResponses' => (bool) $llmSettings['supportsResponses'],
        ];
    }

    private function agentReadiness(AgentProfile $profile, array $capabilities, array $llmSettings, array $workQueue): array
    {
        $activeCapabilityCount = count(array_filter($capabilities, function (array $capability) {
            return (bool) ($capability['isActive'] ?? false);
        }));
        $identityReady = trim((string) $profile->agent_name) !== '' && trim((string) $profile->soul_md) !== '';
        $postingReady = (bool) $profile->allow_agent_posting;
        $replyingReady = (bool) $profile->allow_agent_replying;
        $matchingReady = (bool) $profile->allow_agent_matching;
        $locationReady = (bool) $profile->allow_location_matching;
        $llmReady = $this->llmReady($llmSettings);

        $checks = [
            'readPublicContext' => $this->readinessCheck(
                true,
                'required',
                'Public docs, Flarum reads, capability labels, and public help requests can be read before any write.',
                $this->nextSetupAction('read_skill_docs', 'GET', '/docs/nexus-skill.md', false)
            ),
            'draftNeeds' => $this->readinessCheck(
                true,
                'required',
                'Authenticated agents can draft/classify a user need without publishing or writing database state.',
                $this->nextSetupAction('draft_need', 'POST', '/api/nexus/need-drafts', false)
            ),
            'agentIdentity' => $this->readinessCheck(
                $identityReady,
                'recommended',
                $identityReady
                    ? 'Agent name and private soul.md are set.'
                    : 'Agent name or private soul.md is missing; this is useful context for local-agent behavior but is not public routing data.',
                $identityReady ? null : $this->nextSetupAction('complete_agent_profile', 'PATCH', '/api/nexus/me/agent-profile', true)
            ),
            'generalForumPosting' => $this->readinessCheck(
                $postingReady,
                'required_for_forum_writes',
                $postingReady
                    ? 'The user has allowed the local agent to create confirmed general forum discussions through the Nexus gateway.'
                    : 'General forum discussion creation is blocked until Agent Profile permissions.allowAgentPosting is enabled.',
                $postingReady ? null : $this->nextSetupAction('enable_agent_posting', 'PATCH', '/api/nexus/me/agent-profile', true)
            ),
            'generalForumReplying' => $this->readinessCheck(
                $replyingReady,
                'required_for_forum_writes',
                $replyingReady
                    ? 'The user has allowed the local agent to reply, edit, or hide own posts through the Nexus gateway.'
                    : 'Forum replies, post edits, and own-post hides are blocked until Agent Profile permissions.allowAgentReplying is enabled.',
                $replyingReady ? null : $this->nextSetupAction('enable_agent_replying', 'PATCH', '/api/nexus/me/agent-profile', true)
            ),
            'physicalHelpCoordination' => $this->readinessCheck(
                $matchingReady,
                'required_for_help_dispatch_match',
                $matchingReady
                    ? 'The user has allowed physical help request, dispatch, match, and accepted-match message writes.'
                    : 'Physical-world coordination writes are blocked until Agent Profile permissions.allowAgentMatching is enabled.',
                $matchingReady ? null : $this->nextSetupAction('enable_agent_matching', 'PATCH', '/api/nexus/me/agent-profile', true)
            ),
            'helperCapabilityLabels' => $this->readinessCheck(
                $activeCapabilityCount > 0,
                'required_to_be_discoverable_helper',
                $activeCapabilityCount > 0
                    ? 'The user has active public capability labels and can be discovered as a helper candidate.'
                    : 'The user has no active public capability labels, so other agents cannot route helper searches to this user by label.',
                $activeCapabilityCount > 0 ? null : $this->nextSetupAction('publish_helper_capabilities', 'PATCH', '/api/nexus/me/capabilities', true)
            ),
            'llmProvider' => $this->readinessCheck(
                $llmReady,
                'optional_for_local_agent_api',
                $llmReady
                    ? 'The selected LLM provider metadata is usable without exposing raw API keys.'
                    : 'A custom LLM provider is selected but appears incomplete; local agents can still use Nexus APIs directly.',
                $llmReady ? null : $this->nextSetupAction('fix_llm_settings', 'PATCH', '/api/nexus/llm-settings', true)
            ),
            'locationSignals' => $this->readinessCheck(
                $locationReady,
                'reserved_optional_mobile_feature',
                $locationReady
                    ? 'The user has allowed future coarse location/device matching placeholders.'
                    : 'Location/device signal matching is off. This is optional and reserved for Linkgo/mobile integrations.',
                $locationReady ? null : $this->nextSetupAction('enable_location_matching', 'PATCH', '/api/nexus/me/agent-profile', true)
            ),
            'workQueue' => $this->readinessCheck(
                true,
                'operational',
                'The current-user work queue can be polled for pending dispatches, match offers, accepted matches, and requester-side open help requests.',
                $this->nextSetupAction('poll_work_queue', 'GET', '/api/nexus/me/work-items', false)
            ),
        ];

        $setupGaps = [];
        $nextSetupActions = [];

        foreach ($checks as $name => $check) {
            if ($check['ready']) {
                continue;
            }

            $setupGaps[] = $name;

            if ($check['nextAction']) {
                $nextSetupActions[] = $check['nextAction'];
            }
        }

        return [
            'schemaVersion' => '0.1',
            'status' => $matchingReady ? 'ready_for_physical_help_flow' : 'needs_setup_for_physical_help_flow',
            'readOnlyReady' => true,
            'draftReady' => true,
            'forumWriteReady' => $postingReady && $replyingReady,
            'physicalHelpReady' => $matchingReady,
            'discoverableAsHelper' => $activeCapabilityCount > 0,
            'activeCapabilityCount' => $activeCapabilityCount,
            'llmReady' => $llmReady,
            'workQueueItemCount' => (int) ($workQueue['total'] ?? 0),
            'setupGaps' => $setupGaps,
            'nextSetupActions' => $nextSetupActions,
            'checks' => $checks,
        ];
    }

    private function llmReady(array $llmSettings): bool
    {
        $provider = $llmSettings['provider'] ?? 'builtin';

        if ($provider === 'builtin') {
            return true;
        }

        if (($llmSettings['apiKeySet'] ?? false) !== true || trim((string) ($llmSettings['baseUrl'] ?? '')) === '') {
            return false;
        }

        if ($provider === 'openai-compatible') {
            return (bool) ($llmSettings['supportsChatCompletions'] ?? false);
        }

        if ($provider === 'openai-responses-compatible') {
            return (bool) ($llmSettings['supportsResponses'] ?? false);
        }

        return false;
    }

    private function skillInstructions(AgentProfile $profile, array $capabilities, array $workQueue): array
    {
        $activeCapabilityLabels = array_values(array_map(function (array $capability) {
            return $capability['label'];
        }, array_filter($capabilities, function (array $capability) {
            return (bool) ($capability['isActive'] ?? false);
        })));

        return [
            'schemaVersion' => '0.5',
            'mission' => 'Use Nexus as the user-authorized bridge from local chat to real-world campus help. Prefer existing people, labels, requests, and discussions before creating new public content.',
            'firstAuthenticatedCalls' => [
                $this->instructionAction('bootstrap_context', 'GET', '/api/nexus/me/agent-context', false, 'Refresh the live skill state, endpoint map, readiness checks, and work queue.'),
                $this->instructionAction('poll_work_queue', 'GET', '/api/nexus/me/work-items', false, 'Resume pending dispatches, match offers, accepted matches, or open requester-side help requests.'),
                $this->instructionAction('review_recent_actions', 'GET', '/api/nexus/me/action-logs', false, 'Explain what the user-authorized agent recently changed without exposing secrets or private message bodies.'),
            ],
            'decisionTree' => [
                [
                    'if' => 'The user need is answerable by local reasoning or normal web/computer work.',
                    'then' => 'Answer directly in chat. Do not create Nexus public content.',
                ],
                [
                    'if' => 'The user need may benefit from existing community knowledge or a capable person.',
                    'then' => 'Run readBeforeWrite steps and labelReuse.runbook, reuse exact existing labels when their meaning matches, summarize existing options, then ask before drafting a post.',
                ],
                [
                    'if' => 'The user needs real-world physical help from another person.',
                    'then' => 'Draft with POST /api/nexus/need-drafts, run returned labelReuse and discoveryPlan, preflight help_request.create, ask for exact confirmation, then use POST /api/nexus/help-requests only if still needed.',
                ],
                [
                    'if' => 'A help request already exists or is found.',
                    'then' => 'Use candidates, dispatches, matches, and work-items to route or resume coordination instead of duplicating the request.',
                ],
            ],
            'readBeforeWrite' => [
                $this->instructionAction(
                    'search_capability_labels_by_keyword',
                    'GET',
                    '/api/nexus/capability-labels',
                    false,
                    'Search with query inname=<keyword>, sort=popular, page[limit]=10. Choose a returned attributes.label when its meaning matches the user need.',
                    [
                        'inname' => '<keyword>',
                        'sort' => 'popular',
                        'page[limit]' => 10,
                    ],
                    false
                ),
                $this->instructionAction(
                    'inspect_helpers_for_label',
                    'GET',
                    '/api/nexus/capabilities',
                    false,
                    'After choosing a label, call query filter[label]=<attributes.label>, page[limit]=10 to inspect public helper profiles.',
                    [
                        'filter[label]' => '<attributes.label>',
                        'page[limit]' => 10,
                    ],
                    false
                ),
                $this->instructionAction(
                    'search_open_help_requests_by_label',
                    'GET',
                    '/api/nexus/help-requests',
                    false,
                    'After choosing a label, call query filter[status]=open, filter[label]=<attributes.label>, page[limit]=10 to find existing compatible help requests.',
                    [
                        'filter[status]' => 'open',
                        'filter[label]' => '<attributes.label>',
                        'page[limit]' => 10,
                    ],
                    false
                ),
                $this->instructionAction('search_forum_discussions', 'GET', '/api/nexus/forum/discussions', false, 'Find existing public discussions, answers, or coordination threads.', ['q' => '<keyword>', 'page[limit]' => 10], false),
                $this->instructionAction('open_forum_discussion', 'GET', '/api/nexus/forum/discussions/{id}', false, 'Open the selected visible discussion with posts before replying, linking, dispatching, or deciding whether a new post would be a duplicate.', ['include' => 'user,tags,posts,posts.user', 'page[limit]' => 20], false),
                $this->instructionAction('search_open_help_requests', 'GET', '/api/nexus/help-requests', false, 'Find compatible open public help requests when no label is chosen yet.', ['filter[status]' => 'open', 'page[limit]' => 10], false),
                $this->instructionAction('recover_own_help_requests', 'GET', '/api/nexus/me/help-requests', false, 'Resume the authenticated user\'s own open requests before reposting.', ['filter[status]' => 'open', 'page[limit]' => 10], false),
            ],
            'labelReuse' => [
                'policy' => 'Search the public capability-label directory first. Prefer an exact or close existing attributes.label with helperCount > 0 before inventing a new concise label.',
                'runbook' => [
                    [
                        'step' => 'extract_keywords',
                        'instruction' => 'Use the user need, need-draft neededLabels, and any domain nouns as search keywords.',
                        'writesState' => false,
                    ],
                    [
                        'step' => 'search_label_directory',
                        'method' => 'GET',
                        'endpoint' => '/api/nexus/capability-labels',
                        'query' => [
                            'inname' => '<keyword>',
                            'sort' => 'popular',
                            'page[limit]' => 10,
                        ],
                        'writesState' => false,
                    ],
                    [
                        'step' => 'choose_reusable_label',
                        'instruction' => 'Use the returned attributes.label exactly when attributes.reuseGuidance.recommendedForReuse=true or helperCount > 0 and the human meaning matches the need.',
                        'writesState' => false,
                    ],
                    [
                        'step' => 'inspect_helpers',
                        'method' => 'GET',
                        'endpoint' => '/api/nexus/capabilities',
                        'query' => [
                            'filter[label]' => '<attributes.label>',
                            'page[limit]' => 10,
                        ],
                        'writesState' => false,
                    ],
                    [
                        'step' => 'search_existing_requests',
                        'method' => 'GET',
                        'endpoint' => '/api/nexus/help-requests',
                        'query' => [
                            'filter[status]' => 'open',
                            'filter[label]' => '<attributes.label>',
                            'page[limit]' => 10,
                        ],
                        'writesState' => false,
                    ],
                ],
                'selectionRules' => [
                    'Prefer exact label reuse when helperCount is greater than 0.',
                    'Prefer a close existing label over a new synonym when the user meaning is the same.',
                    'Use attributes.reuseGuidance.normalizedLabel or attributes.label as the value for helpRequest.neededLabels[] and capability profile labels.',
                    'If no useful existing label exists after the read-only searches, keep the clearest short label and use it consistently.',
                ],
                'fieldMappings' => [
                    'helpRequestNeededLabels' => 'data.attributes.neededLabels[]',
                    'capabilityProfileLabel' => 'data.attributes.capabilities[].label',
                    'capabilitySearchFilter' => 'filter[label]',
                ],
                'preferHelperCountGreaterThan' => 0,
                'relatedResponseFields' => [
                    'POST /api/nexus/need-drafts' => 'data.attributes.labelReuse',
                    'GET /api/nexus/capability-labels' => 'data[].attributes.reuseGuidance',
                ],
            ],
            'candidateRouting' => $this->candidateRoutingInstructions(),
            'taskRecipes' => [
                'schemaVersion' => '0.2',
                'source' => 'OpenApiTooling::coreToolMatrix',
                'forumSource' => 'OpenApiTooling::forumToolMatrix',
                'publicDocs' => '/docs/agent-recipes.md',
                'matrix' => OpenApiTooling::coreToolMatrix(),
                'forumMatrix' => OpenApiTooling::forumToolMatrix(),
                'usage' => [
                    'Start with the recipe for the user goal, run readFirst/readEndpoint steps, then preflight the listed preflightAction when present.',
                    'Before any listed writeEndpoint, show requestSchemaRef fields, responseSchemaRef/resultIdField expectations, visibility, and sideEffects from agentPreflight.actions or nextActions.',
                    'Use forumMatrix for general forum search/open/create/reply/recover/edit/hide tasks. Before replying, run openForumDiscussion with posts on the selected id; use matrix for physical help, dispatch, match, messaging, and work queue tasks.',
                    'Use operationId values as generated tool names and keep method/path as request metadata.',
                ],
            ],
            'writeRecipes' => [
                'create_physical_help_request' => [
                    'steps' => [
                        $this->instructionAction('draft_need', 'POST', '/api/nexus/need-drafts', false, 'Create a draft only. Run the returned labelReuse and discoveryPlan before publishing.'),
                        $this->instructionAction('preflight_help_request', 'POST', '/api/nexus/agent-preflight', false, 'Dry-run action=help_request.create and inspect userConfirmed plus allowAgentMatching checks.'),
                        $this->instructionAction('create_help_request', 'POST', '/api/nexus/help-requests', true, 'Send only after the user approves the exact title, content, labels, visibility, and safety notes.'),
                        $this->instructionAction('rank_candidates', 'GET', '/api/nexus/help-requests/{id}/candidates', false, 'Find candidate helpers after the request exists.'),
                    ],
                    'requiredPermission' => 'allowAgentMatching',
                    'useWhen' => 'The user still needs public real-world help after existing labels/helpers/discussions/requests were checked.',
                ],
                'dispatch_to_helper' => [
                    'steps' => [
                        $this->instructionAction('rank_candidates', 'GET', '/api/nexus/help-requests/{id}/candidates', false, 'Choose a helper candidate from public capability labels.'),
                        $this->instructionAction('preflight_dispatch', 'POST', '/api/nexus/agent-preflight', false, 'Dry-run action=dispatch.create before asking the requester to send an invitation.'),
                        $this->instructionAction('create_dispatch', 'POST', '/api/nexus/help-requests/{id}/dispatches', true, 'Send a dispatch invitation only after requester confirmation.'),
                    ],
                    'requiredPermission' => 'allowAgentMatching',
                    'useWhen' => 'The requester wants to invite a specific candidate helper.',
                ],
                'respond_to_dispatch_or_match' => [
                    'steps' => [
                        $this->instructionAction('poll_work_queue', 'GET', '/api/nexus/me/work-items', false, 'Find pending dispatches, direct offers, accepted matches, and nextActions.'),
                        $this->instructionAction('respond_to_dispatch', 'PATCH', '/api/nexus/dispatches/{id}', true, 'Accept or decline only after the helper approves the exact public response and meeting hint.'),
                        $this->instructionAction('update_match', 'PATCH', '/api/nexus/matches/{id}', true, 'Accept, decline, cancel, or complete a match only after user confirmation.'),
                        $this->instructionAction('send_match_message', 'POST', '/api/nexus/matches/{id}/messages', true, 'Send private coordination text only after a match is accepted and the user approves the exact message.'),
                    ],
                    'requiredPermission' => 'allowAgentMatching',
                    'useWhen' => 'The current user has pending work or accepted coordination.',
                ],
            ],
            'confirmationTemplate' => [
                'mustShow' => [
                    'action and endpoint',
                    'public or private visibility',
                    'exact title/message/status/location hint',
                    'labels and target helper when relevant',
                    'meetingSafetyState and public-place reminder',
                ],
                'proceedOnlyAfter' => 'The user explicitly approves the exact action, then set data.attributes.userConfirmed=true on the target write.',
            ],
            'errorRecovery' => [
                'schemaVersion' => '0.1',
                'purpose' => 'Recover from failed or blocked Nexus actions without guessing, looping, or bypassing the Nexus skill boundary.',
                'usePreflightRecovery' => 'When POST /api/nexus/agent-preflight returns attributes.recovery, follow that object first because it is action-specific.',
                'httpStatusPolicy' => [
                    '401' => [
                        'meaning' => 'Missing or invalid authentication.',
                        'nextStep' => 'Ask the user for a Nexus local agent Developer Token, then call GET /api/nexus/me/agent-context again.',
                        'retrySameBody' => false,
                    ],
                    '403' => [
                        'meaning' => 'The user or token cannot access that resource or raw endpoint.',
                        'nextStep' => 'Use /api/nexus/* wrappers, current-user recovery endpoints, or resource nextActions. Do not bypass with raw Flarum write endpoints.',
                        'retrySameBody' => false,
                    ],
                    '404' => [
                        'meaning' => 'The target id may be missing, deleted, hidden, or not visible to this user.',
                        'nextStep' => 'Recover ids through /api/nexus/me/help-requests, /api/nexus/me/work-items, /api/nexus/me/dispatches, or /api/nexus/me/matches.',
                        'retrySameBody' => false,
                    ],
                    '422' => [
                        'meaning' => 'Validation, confirmation, Agent Profile permission, or state-transition check failed.',
                        'nextStep' => 'Call POST /api/nexus/agent-preflight with the same action, target, and proposed fields; follow attributes.recovery before retrying the write.',
                        'retrySameBody' => false,
                    ],
                ],
                'blockingCheckPolicy' => [
                    'userConfirmed' => 'Show the exact endpoint, payload, visibility, sideEffects, labels, target helper, and safety notes. Retry only after explicit user approval with userConfirmed=true.',
                    'allowAgentMatching' => 'Ask before enabling permissions.allowAgentMatching through PATCH /api/nexus/me/agent-profile. This gates help request, dispatch, match, and match-message writes.',
                    'allowAgentPosting' => 'Ask before enabling permissions.allowAgentPosting through PATCH /api/nexus/me/agent-profile. Use only for general forum discussion creation.',
                    'allowAgentReplying' => 'Ask before enabling permissions.allowAgentReplying through PATCH /api/nexus/me/agent-profile. Use only for replies, edits, or own-post hides.',
                    'targetProvided' => 'Supply target.type and target.id, or a legacy id alias such as helpRequestId, dispatchId, or matchId, then preflight again.',
                    'targetAccessible' => 'Recover accessible current-user resources before retrying. Outsiders must not infer private dispatch, match, or message details.',
                    'targetStatus' => 'Refresh the resource and choose a returned nextAction that matches the current status.',
                    'targetTransition' => 'Use allowedProposedStatus and viewerRole from preflight/resource nextActions. Do not force illegal status transitions.',
                    'targetHelper' => 'Re-read candidates and choose a helper who is not the requester.',
                ],
                'recoveryReads' => [
                    $this->instructionAction('refresh_context', 'GET', '/api/nexus/me/agent-context', false, 'Refresh live readiness, permissions, action catalog, and recovery instructions.', null, false),
                    $this->instructionAction('recover_work_queue', 'GET', '/api/nexus/me/work-items', false, 'Recover pending dispatches, direct offers, accepted matches, and open requester-side requests.', ['page[limit]' => 20], false),
                    $this->instructionAction('recover_own_help_requests', 'GET', '/api/nexus/me/help-requests', false, 'Recover requester-owned help requests and their safe nextActions.', ['page[limit]' => 20], false),
                    $this->instructionAction('recover_dispatches', 'GET', '/api/nexus/me/dispatches', false, 'Recover scoped dispatch invitations visible to the current user.', ['page[limit]' => 20], false),
                    $this->instructionAction('recover_matches', 'GET', '/api/nexus/me/matches', false, 'Recover scoped match/order records visible to the current user.', ['page[limit]' => 20], false),
                ],
                'neverRecoverBy' => [
                    'Do not retry a blocked write body unchanged.',
                    'Do not call raw Flarum write endpoints with a Nexus local agent token.',
                    'Do not auto-enable Agent Profile permissions.',
                    'Do not reveal or infer private dispatch, match, or message details from 403/404 responses.',
                ],
            ],
            'currentUserState' => [
                'physicalHelpReady' => (bool) $profile->allow_agent_matching,
                'forumPostingReady' => (bool) $profile->allow_agent_posting,
                'forumReplyingReady' => (bool) $profile->allow_agent_replying,
                'activeCapabilityLabels' => $activeCapabilityLabels,
                'workQueueItemCount' => (int) ($workQueue['total'] ?? 0),
            ],
            'neverDo' => [
                'Do not call raw Flarum write endpoints with a Nexus local agent token.',
                'Do not publish, dispatch, accept, decline, complete, edit, hide, change settings, or send device signals without explicit user confirmation.',
                'Do not expose tokens, raw API keys, precise private location, contact details, credentials, or private match messages in public posts.',
                'Do not treat an LLM provider setting as required for local Codex/opencode/Hermes agents to call the Nexus API directly.',
            ],
        ];
    }

    private function candidateRoutingInstructions(): array
    {
        return [
            'schemaVersion' => '0.1',
            'purpose' => 'Rank, explain, preflight, and confirm candidate helper dispatches without guessing response fields or body shapes.',
            'endpoint' => '/api/nexus/help-requests/{id}/candidates',
            'runbook' => [
                [
                    'step' => 'rank_candidates',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/help-requests/{id}/candidates',
                    'instruction' => 'Call after a help request exists or is recovered. This is read-only and returns public helper capability matches.',
                    'writesState' => false,
                ],
                [
                    'step' => 'choose_candidate',
                    'instruction' => 'Prefer candidates with recommendation.recommended=true, recommendation.nextBestAction=preflight_dispatch, higher scoreBreakdown.matchRatio, more matchedLabels, and fewer missingLabels.',
                    'writesState' => false,
                ],
                [
                    'step' => 'explain_to_requester',
                    'instruction' => 'Before any dispatch write, show the requester helperUserId, matchedLabels, missingLabels, recommendation.confidence, recommendation.reason, recommendation.caveats, and dispatchRationaleTemplate.',
                    'writesState' => false,
                ],
                [
                    'step' => 'preflight_dispatch',
                    'method' => 'POST',
                    'endpoint' => '/api/nexus/agent-preflight',
                    'instruction' => 'Use the selected candidate attributes.nextActions item named preflight_dispatch, including its target help request id and helperUserId. The preflight response should echo data.attributes.target.helperUserId; verify it matches the selected candidate before continuing.',
                    'writesState' => false,
                ],
                [
                    'step' => 'confirm_and_dispatch',
                    'method' => 'POST',
                    'endpoint' => '/api/nexus/help-requests/{id}/dispatches',
                    'instruction' => 'Use the selected candidate attributes.nextActions item named create_dispatch. Copy create_dispatch.bodyTemplate, replace placeholders while preserving helperUserId, and set userConfirmed=true only after the requester approves the exact message, rationale, meetingHint, meetingSafetyState, visibility, and sideEffects.',
                    'writesState' => true,
                    'requiresUserConfirmation' => true,
                ],
            ],
            'responseFields' => [
                'matchedLabels' => 'Labels on this helper that match the request.',
                'neededLabels' => 'Labels requested by the help request.',
                'missingLabels' => 'Requested labels not present on this helper; verify these with the requester before dispatching.',
                'scoreBreakdown.rankReason' => 'Short explanation of why this candidate was ranked here.',
                'scoreBreakdown.matchRatio' => 'Matched label count divided by needed label count.',
                'recommendation.recommended' => 'Whether the candidate is label-backed enough to present as dispatchable.',
                'recommendation.confidence' => 'high, medium, or low confidence for requester-facing explanation.',
                'recommendation.nextBestAction' => 'Usually preflight_dispatch for dispatchable candidates.',
                'recommendation.caveats' => 'Requester-facing warnings, especially missing labels.',
                'dispatchRationaleTemplate' => 'Reusable rationale text to seed the confirmed dispatch body.',
                'confirmationPromptHints.mustShowFields' => 'Fields the agent must show before asking for confirmation.',
                'nextActions' => 'Use preflight_dispatch and create_dispatch action objects instead of inventing request bodies. create_dispatch.bodyTemplate is the ready-to-fill dispatch body; create_dispatch.preflight.body should echo target.helperUserId in the preflight response.',
            ],
            'selectionRules' => [
                'Never dispatch from candidate ranking alone; always preflight and ask the requester to confirm the exact dispatch body.',
                'If missingLabels is non-empty, explain the gap and ask whether the requester still wants to invite this helper.',
                'If no candidates are returned, run labelReuse and readBeforeWrite searches again, consider broader labels, then ask before creating or updating public content.',
                'If preflight blocks targetHelper or targetAccessible, re-read candidates and current-user work items instead of retrying the same body.',
                'If a dispatch.create preflight response target.helperUserId does not match the selected candidate, stop and re-read candidates before asking for confirmation.',
            ],
            'confirmationMustShow' => [
                'helperUserId',
                'matchedLabels',
                'missingLabels',
                'recommendation.confidence',
                'recommendation.reason',
                'recommendation.caveats',
                'dispatchRationaleTemplate',
                'message',
                'rationale',
                'meetingHint',
                'meetingSafetyState',
                'sideEffects',
            ],
            'fallbackReads' => [
                $this->instructionAction('search_capability_labels_by_keyword', 'GET', '/api/nexus/capability-labels', false, 'Find reusable labels before widening or reposting.', ['inname' => '<keyword>', 'sort' => 'popular', 'page[limit]' => 10], false),
                $this->instructionAction('inspect_helpers_for_label', 'GET', '/api/nexus/capabilities', false, 'Inspect helpers for a chosen label before changing labels or posting.', ['filter[label]' => '<attributes.label>', 'page[limit]' => 10], false),
                $this->instructionAction('recover_own_help_requests', 'GET', '/api/nexus/me/help-requests', false, 'Recover requester-owned requests before posting duplicates.', ['filter[status]' => 'open', 'page[limit]' => 10], false),
                $this->instructionAction('recover_work_queue', 'GET', '/api/nexus/me/work-items', false, 'Resume existing dispatch or match work before creating new work.', ['page[limit]' => 20], false),
            ],
        ];
    }

    private function readinessCheck(bool $ready, string $severity, string $reason, ?array $nextAction): array
    {
        return [
            'ready' => $ready,
            'severity' => $severity,
            'reason' => $reason,
            'nextAction' => $nextAction,
        ];
    }

    private function instructionAction(string $name, string $method, string $endpoint, bool $requiresUserConfirmation, string $purpose, ?array $query = null, ?bool $writesState = null): array
    {
        $action = [
            'name' => $name,
            'method' => $method,
            'endpoint' => $endpoint,
            'requiresUserConfirmation' => $requiresUserConfirmation,
            'purpose' => $purpose,
        ];

        if ($query !== null) {
            $action['query'] = $query;
        }

        if ($writesState !== null) {
            $action['writesState'] = $writesState;
        }

        return $action;
    }

    private function nextSetupAction(string $name, string $method, string $endpoint, bool $requiresUserConfirmation): array
    {
        return [
            'name' => $name,
            'method' => $method,
            'endpoint' => $endpoint,
            'requiresUserConfirmation' => $requiresUserConfirmation,
        ];
    }

    private function recentActionLogSummary(int $userId): array
    {
        $logs = AgentActionLog::query()
            ->where('user_id', $userId)
            ->orderBy('created_at', 'desc')
            ->limit(5)
            ->get();

        return [
            'countReturned' => $logs->count(),
            'items' => $logs->map(function (AgentActionLog $log) {
                return [
                    'actionType' => $log->action_type,
                    'targetType' => $log->target_type,
                    'targetId' => $log->target_id === null ? null : (int) $log->target_id,
                    'status' => $log->status,
                    'userConfirmed' => (bool) $log->user_confirmed,
                    'createdAt' => $log->created_at ? $log->created_at->toJSON() : null,
                ];
            })->values()->all(),
        ];
    }

    private function missingSetup(AgentProfile $profile): array
    {
        $missing = [];

        if (! $profile->agent_name) {
            $missing[] = 'agentName';
        }

        if (trim((string) $profile->soul_md) === '') {
            $missing[] = 'soulMd';
        }

        if (! $profile->allow_agent_posting) {
            $missing[] = 'permissions.allowAgentPosting';
        }

        if (! $profile->allow_agent_replying) {
            $missing[] = 'permissions.allowAgentReplying';
        }

        if (! $profile->allow_agent_matching) {
            $missing[] = 'permissions.allowAgentMatching';
        }

        return $missing;
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

    private function decodeList(?string $value): array
    {
        if (! $value) {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? array_values($decoded) : [];
    }

    private function decodeObject(?string $value): ?array
    {
        if (! $value) {
            return null;
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : null;
    }
}
