<?php

use Flarum\Extend;
use Nexus\Forum\Device\Controller\CreateDeviceSignalController;
use Nexus\Forum\Forum\Controller\CreateForumDiscussionController;
use Nexus\Forum\Forum\Controller\CreateForumPostController;
use Nexus\Forum\Help\Controller\CreateHelpDispatchController;
use Nexus\Forum\Help\Controller\CreateHelpMatchController;
use Nexus\Forum\Help\Controller\CreateHelpMatchMessageController;
use Nexus\Forum\Help\Controller\CreateHelpRequestController;
use Nexus\Forum\Agent\Controller\CreateAgentPreflightController;
use Nexus\Forum\Agent\Controller\CreateNeedDraftController;
use Nexus\Forum\Forum\Controller\DeleteForumPostController;
use Nexus\Forum\Agent\Controller\ListCapabilitiesController;
use Nexus\Forum\Agent\Controller\ListCapabilityLabelsController;
use Nexus\Forum\Forum\Controller\ListForumDiscussionsController;
use Nexus\Forum\Help\Controller\ListHelpDispatchesController;
use Nexus\Forum\Help\Controller\ListHelpCandidatesController;
use Nexus\Forum\Help\Controller\ListHelpMatchesController;
use Nexus\Forum\Help\Controller\ListHelpMatchMessagesController;
use Nexus\Forum\Help\Controller\ListHelpRequestsController;
use Nexus\Forum\Agent\Controller\ListMyAgentActionLogsController;
use Nexus\Forum\Device\Controller\ListMyDeviceSignalsController;
use Nexus\Forum\Forum\Controller\ListMyForumDiscussionsController;
use Nexus\Forum\Forum\Controller\ListMyForumPostsController;
use Nexus\Forum\Help\Controller\ListMyHelpMatchesController;
use Nexus\Forum\Help\Controller\ListMyHelpDispatchesController;
use Nexus\Forum\Help\Controller\ListMyHelpRequestsController;
use Nexus\Forum\Help\Controller\ListMyWorkItemsController;
use Nexus\Forum\Agent\Controller\ShowAgentHealthController;
use Nexus\Forum\Forum\Controller\ShowForumDiscussionController;
use Nexus\Forum\Agent\Controller\ShowLlmSettingsController;
use Nexus\Forum\Help\Controller\ShowHelpRequestController;
use Nexus\Forum\Agent\Controller\ShowMyAgentContextController;
use Nexus\Forum\Agent\Controller\ShowMyAgentProfileController;
use Nexus\Forum\Agent\Controller\ShowMyCapabilitiesController;
use Nexus\Forum\Forum\Controller\UpdateForumPostController;
use Nexus\Forum\Help\Controller\UpdateHelpDispatchController;
use Nexus\Forum\Help\Controller\UpdateHelpMatchController;
use Nexus\Forum\Help\Controller\UpdateHelpRequestController;
use Nexus\Forum\Agent\Controller\UpdateLlmSettingsController;
use Nexus\Forum\Agent\Controller\UpdateMyAgentProfileController;
use Nexus\Forum\Agent\Controller\UpdateMyCapabilitiesController;
use Nexus\Forum\Http\Middleware\RestrictNexusAgentTokenWrites;
use Nexus\Forum\Notification\HelpDispatchBlueprint;
use Nexus\Forum\Help\Serializer\HelpDispatchSerializer;

return [
    (new Extend\Frontend('forum'))
        ->js(__DIR__.'/../frontend/dist/forum.js'),

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
