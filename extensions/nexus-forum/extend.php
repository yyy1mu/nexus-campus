<?php

use Flarum\Extend;
use Nexus\Forum\Api\Controller\CreateDeviceSignalController;
use Nexus\Forum\Api\Controller\CreateForumDiscussionController;
use Nexus\Forum\Api\Controller\CreateForumPostController;
use Nexus\Forum\Api\Controller\CreateHelpDispatchController;
use Nexus\Forum\Api\Controller\CreateHelpMatchController;
use Nexus\Forum\Api\Controller\CreateHelpMatchMessageController;
use Nexus\Forum\Api\Controller\CreateHelpRequestController;
use Nexus\Forum\Api\Controller\CreateAgentPreflightController;
use Nexus\Forum\Api\Controller\CreateNeedDraftController;
use Nexus\Forum\Api\Controller\DeleteForumPostController;
use Nexus\Forum\Api\Controller\ListCapabilitiesController;
use Nexus\Forum\Api\Controller\ListCapabilityLabelsController;
use Nexus\Forum\Api\Controller\ListForumDiscussionsController;
use Nexus\Forum\Api\Controller\ListHelpDispatchesController;
use Nexus\Forum\Api\Controller\ListHelpCandidatesController;
use Nexus\Forum\Api\Controller\ListHelpMatchesController;
use Nexus\Forum\Api\Controller\ListHelpMatchMessagesController;
use Nexus\Forum\Api\Controller\ListHelpRequestsController;
use Nexus\Forum\Api\Controller\ListMyAgentActionLogsController;
use Nexus\Forum\Api\Controller\ListMyDeviceSignalsController;
use Nexus\Forum\Api\Controller\ListMyForumDiscussionsController;
use Nexus\Forum\Api\Controller\ListMyForumPostsController;
use Nexus\Forum\Api\Controller\ListMyHelpMatchesController;
use Nexus\Forum\Api\Controller\ListMyHelpDispatchesController;
use Nexus\Forum\Api\Controller\ListMyHelpRequestsController;
use Nexus\Forum\Api\Controller\ListMyWorkItemsController;
use Nexus\Forum\Api\Controller\ShowAgentHealthController;
use Nexus\Forum\Api\Controller\ShowForumDiscussionController;
use Nexus\Forum\Api\Controller\ShowLlmSettingsController;
use Nexus\Forum\Api\Controller\ShowHelpRequestController;
use Nexus\Forum\Api\Controller\ShowMyAgentContextController;
use Nexus\Forum\Api\Controller\ShowMyAgentProfileController;
use Nexus\Forum\Api\Controller\ShowMyCapabilitiesController;
use Nexus\Forum\Api\Controller\UpdateForumPostController;
use Nexus\Forum\Api\Controller\UpdateHelpDispatchController;
use Nexus\Forum\Api\Controller\UpdateHelpMatchController;
use Nexus\Forum\Api\Controller\UpdateHelpRequestController;
use Nexus\Forum\Api\Controller\UpdateLlmSettingsController;
use Nexus\Forum\Api\Controller\UpdateMyAgentProfileController;
use Nexus\Forum\Api\Controller\UpdateMyCapabilitiesController;
use Nexus\Forum\Http\Middleware\RestrictNexusAgentTokenWrites;
use Nexus\Forum\Notification\HelpDispatchBlueprint;
use Nexus\Forum\Api\Serializer\HelpDispatchSerializer;

return [
    (new Extend\Frontend('forum'))
        ->js(__DIR__.'/js/dist/forum.js'),

    new Extend\Locales(__DIR__.'/locale'),

    (new Extend\Middleware('api'))
        ->insertAfter(Flarum\Http\Middleware\AuthenticateWithHeader::class, RestrictNexusAgentTokenWrites::class),

    (new Extend\Routes('api'))
        ->get('/nexus/agent-health', 'nexus.agent-health.show', ShowAgentHealthController::class)
        ->get('/nexus/llm-settings', 'nexus.llm-settings.show', ShowLlmSettingsController::class)
        ->patch('/nexus/llm-settings', 'nexus.llm-settings.update', UpdateLlmSettingsController::class)
        ->post('/nexus/agent-preflight', 'nexus.agent-preflight.create', CreateAgentPreflightController::class)
        ->post('/nexus/need-drafts', 'nexus.need-drafts.create', CreateNeedDraftController::class)
        ->get('/nexus/me/agent-context', 'nexus.me.agent-context.show', ShowMyAgentContextController::class)
        ->get('/nexus/me/agent-profile', 'nexus.me.agent-profile.show', ShowMyAgentProfileController::class)
        ->patch('/nexus/me/agent-profile', 'nexus.me.agent-profile.update', UpdateMyAgentProfileController::class)
        ->get('/nexus/capability-labels', 'nexus.capability-labels.index', ListCapabilityLabelsController::class)
        ->get('/nexus/capabilities', 'nexus.capabilities.index', ListCapabilitiesController::class)
        ->get('/nexus/me/capabilities', 'nexus.me.capabilities.show', ShowMyCapabilitiesController::class)
        ->patch('/nexus/me/capabilities', 'nexus.me.capabilities.update', UpdateMyCapabilitiesController::class)
        ->get('/nexus/me/action-logs', 'nexus.me.action-logs.index', ListMyAgentActionLogsController::class)
        ->get('/nexus/me/device-signals', 'nexus.me.device-signals.index', ListMyDeviceSignalsController::class)
        ->get('/nexus/me/discussions', 'nexus.me.forum.discussions.index', ListMyForumDiscussionsController::class)
        ->get('/nexus/me/posts', 'nexus.me.forum.posts.index', ListMyForumPostsController::class)
        ->get('/nexus/me/help-requests', 'nexus.me.help-requests.index', ListMyHelpRequestsController::class)
        ->get('/nexus/me/dispatches', 'nexus.me.dispatches.index', ListMyHelpDispatchesController::class)
        ->get('/nexus/me/matches', 'nexus.me.matches.index', ListMyHelpMatchesController::class)
        ->get('/nexus/me/work-items', 'nexus.me.work-items.index', ListMyWorkItemsController::class)
        ->get('/nexus/forum/discussions', 'nexus.forum.discussions.index', ListForumDiscussionsController::class)
        ->get('/nexus/forum/discussions/{id:\d+}', 'nexus.forum.discussions.show', ShowForumDiscussionController::class)
        ->post('/nexus/forum/discussions', 'nexus.forum.discussions.create', CreateForumDiscussionController::class)
        ->post('/nexus/forum/discussions/{id:\d+}/posts', 'nexus.forum.posts.create', CreateForumPostController::class)
        ->patch('/nexus/forum/posts/{id:\d+}', 'nexus.forum.posts.update', UpdateForumPostController::class)
        ->delete('/nexus/forum/posts/{id:\d+}', 'nexus.forum.posts.delete', DeleteForumPostController::class)
        ->get('/nexus/help-requests', 'nexus.help-requests.index', ListHelpRequestsController::class)
        ->post('/nexus/help-requests', 'nexus.help-requests.create', CreateHelpRequestController::class)
        ->get('/nexus/help-requests/{id:\d+}', 'nexus.help-requests.show', ShowHelpRequestController::class)
        ->patch('/nexus/help-requests/{id:\d+}', 'nexus.help-requests.update', UpdateHelpRequestController::class)
        ->get('/nexus/help-requests/{id:\d+}/candidates', 'nexus.help-requests.candidates.index', ListHelpCandidatesController::class)
        ->get('/nexus/help-requests/{id:\d+}/dispatches', 'nexus.help-requests.dispatches.index', ListHelpDispatchesController::class)
        ->post('/nexus/help-requests/{id:\d+}/dispatches', 'nexus.help-requests.dispatches.create', CreateHelpDispatchController::class)
        ->get('/nexus/help-requests/{id:\d+}/matches', 'nexus.help-requests.matches.index', ListHelpMatchesController::class)
        ->post('/nexus/help-requests/{id:\d+}/matches', 'nexus.help-requests.matches.create', CreateHelpMatchController::class)
        ->patch('/nexus/dispatches/{id:\d+}', 'nexus.dispatches.update', UpdateHelpDispatchController::class)
        ->patch('/nexus/matches/{id:\d+}', 'nexus.matches.update', UpdateHelpMatchController::class)
        ->get('/nexus/matches/{id:\d+}/messages', 'nexus.matches.messages.index', ListHelpMatchMessagesController::class)
        ->post('/nexus/matches/{id:\d+}/messages', 'nexus.matches.messages.create', CreateHelpMatchMessageController::class)
        ->post('/nexus/device-signals', 'nexus.device-signals.create', CreateDeviceSignalController::class),

    (new Extend\Settings)
        ->default('nexus-forum.default_llm_provider', 'builtin')
        ->default('nexus-forum.default_llm_chat_model', 'gpt-4o-mini')
        ->default('nexus-forum.default_llm_responses_model', 'gpt-4.1-mini')
        ->default('nexus-forum.default_llm_base_url', '')
        ->default('nexus-forum.help_tag_id', '1')
        ->serializeToForum('nexusDocsUrl', 'nexus-forum.docs_url', null, '/docs/')
        ->serializeToForum('nexusAgentManifestUrl', 'nexus-forum.agent_manifest_url', null, '/.well-known/nexus-agent.json')
        ->serializeToForum('nexusDefaultLlmProvider', 'nexus-forum.default_llm_provider', null, 'builtin')
        ->serializeToForum('nexusDefaultLlmChatModel', 'nexus-forum.default_llm_chat_model', null, 'gpt-4o-mini')
        ->serializeToForum('nexusDefaultLlmResponsesModel', 'nexus-forum.default_llm_responses_model', null, 'gpt-4.1-mini')
        ->serializeToForum('nexusDefaultLlmBaseUrl', 'nexus-forum.default_llm_base_url', null, ''),

    (new Extend\Notification())
        ->type(HelpDispatchBlueprint::class, HelpDispatchSerializer::class, ['alert']),
];
