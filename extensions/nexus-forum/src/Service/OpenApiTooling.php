<?php

namespace Nexus\Forum\Service;

class OpenApiTooling
{
    public const OPENAPI_VERSION = '0.7.43';

    public static function summary(): array
    {
        return [
            'openApiVersion' => self::OPENAPI_VERSION,
            'operationIdSource' => '/docs/openapi.json',
            'agentToolContract' => '/docs/agent-tools.json',
            'operationIdPolicy' => 'Use stable operationId values from /docs/openapi.json as local-agent tool names. Do not invent names from URL paths.',
            'toolNamePolicy' => 'Prefer /docs/agent-tools.json for goal-to-tool planning, use operationId for generated tools, keep method and path as request metadata, and use resource nextActions for target-specific writes.',
            'coreOperationIds' => self::coreOperationIds(),
            'coreToolMatrix' => self::coreToolMatrix(),
            'forumOperationIds' => self::forumOperationIds(),
            'forumToolMatrix' => self::forumToolMatrix(),
            'tags' => self::tags(),
        ];
    }

    public static function coreOperationIds(): array
    {
        return [
            'agentHealth' => 'nexusAgentHealthShow',
            'myAgentContext' => 'nexusMyAgentContextShow',
            'agentPreflight' => 'nexusAgentPreflightCreate',
            'needDrafts' => 'nexusNeedDraftCreate',
            'helpRequestsList' => 'nexusHelpRequestsList',
            'myHelpRequests' => 'nexusMyHelpRequestsList',
            'helpRequestShow' => 'nexusHelpRequestShow',
            'helpRequestCreate' => 'nexusHelpRequestCreate',
            'helpCandidatesList' => 'nexusHelpCandidatesList',
            'helpDispatchesList' => 'nexusHelpDispatchesList',
            'myDispatches' => 'nexusMyDispatchesList',
            'helpDispatchCreate' => 'nexusHelpDispatchCreate',
            'dispatchUpdate' => 'nexusDispatchUpdate',
            'helpMatchesList' => 'nexusHelpMatchesList',
            'myMatches' => 'nexusMyMatchesList',
            'matchCreate' => 'nexusHelpMatchCreate',
            'matchUpdate' => 'nexusMatchUpdate',
            'matchMessagesList' => 'nexusMatchMessagesList',
            'matchMessageCreate' => 'nexusMatchMessageCreate',
            'myWorkItems' => 'nexusMyWorkItemsList',
        ];
    }

    public static function coreToolMatrix(): array
    {
        return [
            'createHelpRequest' => [
                'goal' => 'Create a public real-world help request only after read-before-write discovery and exact requester confirmation.',
                'readFirst' => [
                    self::readStep('draft_need', 'POST', '/api/nexus/need-drafts', 'nexusNeedDraftCreate', '#/components/schemas/NeedDraftDocument'),
                    self::readStep('search_labels', 'GET', '/api/nexus/capability-labels?inname=<keyword>&sort=popular&page%5Blimit%5D=10', 'nexusCapabilityLabelsList', '#/components/schemas/CapabilityLabelCollectionDocument'),
                    self::readStep('search_open_requests', 'GET', '/api/nexus/help-requests?filter%5Bstatus%5D=open', 'nexusHelpRequestsList', '#/components/schemas/HelpRequestCollectionDocument'),
                ],
                'preflightAction' => 'help_request.create',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'POST /api/nexus/help-requests',
                'writeOperationId' => 'nexusHelpRequestCreate',
                'requestSchemaRef' => '#/components/schemas/HelpRequestInput',
                'responseSchemaRef' => '#/components/schemas/HelpRequestDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
            ],
            'findCandidateHelpers' => [
                'goal' => 'Rank existing public helper candidates for one help request before dispatching or creating duplicate public content.',
                'readFirst' => [
                    self::readStep('show_help_request', 'GET', '/api/nexus/help-requests/{id}', 'nexusHelpRequestShow', '#/components/schemas/HelpRequestDocument'),
                ],
                'readEndpoint' => 'GET /api/nexus/help-requests/{id}/candidates',
                'readOperationId' => 'nexusHelpCandidatesList',
                'responseSchemaRef' => '#/components/schemas/HelpCandidateCollectionDocument',
                'resultIdField' => 'data[].id and data[].attributes.helperUserId',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => false,
            ],
            'dispatchToHelper' => [
                'goal' => 'Invite one selected candidate helper to a requester-owned open help request.',
                'readFirst' => [
                    self::readStep('rank_candidates', 'GET', '/api/nexus/help-requests/{id}/candidates', 'nexusHelpCandidatesList', '#/components/schemas/HelpCandidateCollectionDocument'),
                ],
                'preflightAction' => 'dispatch.create',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'POST /api/nexus/help-requests/{id}/dispatches',
                'writeOperationId' => 'nexusHelpDispatchCreate',
                'requestSchemaRef' => '#/components/schemas/HelpDispatchInput',
                'responseSchemaRef' => '#/components/schemas/HelpDispatchDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
            ],
            'respondToDispatch' => [
                'goal' => 'Let the helper accept or decline a pending dispatch, or let the requester cancel it.',
                'readFirst' => [
                    self::readStep('poll_work_queue', 'GET', '/api/nexus/me/work-items', 'nexusMyWorkItemsList', '#/components/schemas/WorkItemCollectionDocument'),
                    self::readStep('poll_dispatches', 'GET', '/api/nexus/me/dispatches?filter%5Bstatus%5D=pending', 'nexusMyDispatchesList', '#/components/schemas/HelpDispatchCollectionDocument'),
                ],
                'preflightAction' => 'dispatch.update',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'PATCH /api/nexus/dispatches/{id}',
                'writeOperationId' => 'nexusDispatchUpdate',
                'requestSchemaRef' => '#/components/schemas/HelpDispatchUpdateInput',
                'responseSchemaRef' => '#/components/schemas/HelpDispatchDocument',
                'resultIdField' => 'data.id and data.attributes.matchId when accepted',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
            ],
            'respondToMatchOffer' => [
                'goal' => 'Let a requester accept or decline a direct helper offer, or let a participant cancel/complete a match.',
                'readFirst' => [
                    self::readStep('poll_work_queue', 'GET', '/api/nexus/me/work-items', 'nexusMyWorkItemsList', '#/components/schemas/WorkItemCollectionDocument'),
                    self::readStep('poll_matches', 'GET', '/api/nexus/me/matches', 'nexusMyMatchesList', '#/components/schemas/HelpMatchCollectionDocument'),
                ],
                'preflightAction' => 'match.update',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'PATCH /api/nexus/matches/{id}',
                'writeOperationId' => 'nexusMatchUpdate',
                'requestSchemaRef' => '#/components/schemas/MatchUpdateInput',
                'responseSchemaRef' => '#/components/schemas/HelpMatchDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
            ],
            'sendMatchMessage' => [
                'goal' => 'Send private requester/helper coordination text after a match is accepted.',
                'readFirst' => [
                    self::readStep('poll_matches', 'GET', '/api/nexus/me/matches?filter%5Bstatus%5D=accepted', 'nexusMyMatchesList', '#/components/schemas/HelpMatchCollectionDocument'),
                    self::readStep('list_messages', 'GET', '/api/nexus/matches/{id}/messages', 'nexusMatchMessagesList', '#/components/schemas/HelpMatchMessageCollectionDocument'),
                ],
                'preflightAction' => 'match_message.create',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'POST /api/nexus/matches/{id}/messages',
                'writeOperationId' => 'nexusMatchMessageCreate',
                'requestSchemaRef' => '#/components/schemas/MatchMessageInput',
                'responseSchemaRef' => '#/components/schemas/HelpMatchMessageDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentMatching',
            ],
            'pollWorkQueue' => [
                'goal' => 'Resume current-user requester/helper work without knowing resource ids in advance.',
                'readEndpoint' => 'GET /api/nexus/me/work-items',
                'readOperationId' => 'nexusMyWorkItemsList',
                'responseSchemaRef' => '#/components/schemas/WorkItemCollectionDocument',
                'resultIdField' => 'data[].id, data[].attributes.kind, dispatchId, matchId, and nextActions',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => false,
            ],
        ];
    }

    public static function forumOperationIds(): array
    {
        return [
            'forumDiscussionsList' => 'nexusForumDiscussionsList',
            'forumDiscussionShow' => 'nexusForumDiscussionShow',
            'forumDiscussionCreate' => 'nexusForumDiscussionCreate',
            'forumDiscussionPostCreate' => 'nexusForumDiscussionPostCreate',
            'forumPostUpdate' => 'nexusForumPostUpdate',
            'forumPostDelete' => 'nexusForumPostDelete',
            'myForumDiscussions' => 'nexusMyForumDiscussionsList',
            'myForumPosts' => 'nexusMyForumPostsList',
        ];
    }

    public static function forumToolMatrix(): array
    {
        return [
            'searchForumDiscussions' => [
                'goal' => 'Search existing public forum discussions before creating new public content.',
                'readEndpoint' => 'GET /api/nexus/forum/discussions?q=<keyword>&page%5Blimit%5D=10',
                'readOperationId' => 'nexusForumDiscussionsList',
                'responseSchemaRef' => '#/components/schemas/JsonApiDocument',
                'resultIdField' => 'data[].id and data[].attributes.title',
                'requiresAuthentication' => false,
                'requiresUserConfirmation' => false,
            ],
            'openForumDiscussion' => [
                'goal' => 'Open one visible forum discussion with posts before replying, dispatching, linking, or creating duplicate public content.',
                'readEndpoint' => 'GET /api/nexus/forum/discussions/{id}?include=user,tags,posts,posts.user&page%5Blimit%5D=20',
                'readOperationId' => 'nexusForumDiscussionShow',
                'responseSchemaRef' => '#/components/schemas/JsonApiDocument',
                'resultIdField' => 'data.id and included posts',
                'requiresAuthentication' => false,
                'requiresUserConfirmation' => false,
            ],
            'createForumDiscussion' => [
                'goal' => 'Create a general public forum discussion only after searching existing discussions and exact user confirmation.',
                'readFirst' => [
                    self::readStep('search_forum_discussions', 'GET', '/api/nexus/forum/discussions?q=<keyword>&page%5Blimit%5D=10', 'nexusForumDiscussionsList', '#/components/schemas/JsonApiDocument'),
                    self::readStep('list_tags', 'GET', '/api/tags', 'flarumTagsList', '#/components/schemas/JsonApiDocument'),
                ],
                'preflightAction' => 'forum_discussion.create',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'POST /api/nexus/forum/discussions',
                'writeOperationId' => 'nexusForumDiscussionCreate',
                'requestSchemaRef' => '#/components/schemas/ForumDiscussionInput',
                'responseSchemaRef' => '#/components/schemas/FlarumDiscussionDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentPosting',
            ],
            'replyToForumDiscussion' => [
                'goal' => 'Reply to an existing public forum discussion only after reading the target discussion and exact user confirmation.',
                'readFirst' => [
                    self::readStep('search_forum_discussions', 'GET', '/api/nexus/forum/discussions?q=<keyword>&include=user,tags,firstPost&page%5Blimit%5D=10', 'nexusForumDiscussionsList', '#/components/schemas/JsonApiDocument'),
                    self::readStep('open_forum_discussion', 'GET', '/api/nexus/forum/discussions/{id}?include=user,tags,posts,posts.user&page%5Blimit%5D=20', 'nexusForumDiscussionShow', '#/components/schemas/JsonApiDocument'),
                ],
                'preflightAction' => 'forum_post.reply',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'POST /api/nexus/forum/discussions/{id}/posts',
                'writeOperationId' => 'nexusForumDiscussionPostCreate',
                'requestSchemaRef' => '#/components/schemas/ForumPostInput',
                'responseSchemaRef' => '#/components/schemas/FlarumPostDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentReplying',
            ],
            'recoverMyForumDiscussions' => [
                'goal' => 'Recover the current user\'s own forum discussions before editing, replying, linking, or reporting what the agent previously posted.',
                'readEndpoint' => 'GET /api/nexus/me/discussions?page%5Blimit%5D=20',
                'readOperationId' => 'nexusMyForumDiscussionsList',
                'responseSchemaRef' => '#/components/schemas/FlarumDiscussionCollectionDocument',
                'resultIdField' => 'data[].id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => false,
            ],
            'recoverMyForumPosts' => [
                'goal' => 'Recover the current user\'s own forum posts before edit or hide operations.',
                'readEndpoint' => 'GET /api/nexus/me/posts?page%5Blimit%5D=20',
                'readOperationId' => 'nexusMyForumPostsList',
                'responseSchemaRef' => '#/components/schemas/FlarumPostCollectionDocument',
                'resultIdField' => 'data[].id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => false,
            ],
            'editOwnForumPost' => [
                'goal' => 'Edit one current-user-owned forum post only after recovering the post id and exact user confirmation.',
                'readFirst' => [
                    self::readStep('recover_my_posts', 'GET', '/api/nexus/me/posts?page%5Blimit%5D=20', 'nexusMyForumPostsList', '#/components/schemas/FlarumPostCollectionDocument'),
                ],
                'preflightAction' => 'forum_post.edit',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'PATCH /api/nexus/forum/posts/{id}',
                'writeOperationId' => 'nexusForumPostUpdate',
                'requestSchemaRef' => '#/components/schemas/ForumPostInput',
                'responseSchemaRef' => '#/components/schemas/FlarumPostDocument',
                'resultIdField' => 'data.id',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentReplying',
            ],
            'hideOwnForumPost' => [
                'goal' => 'Hide one current-user-owned forum post only after recovering the post id and exact user confirmation.',
                'readFirst' => [
                    self::readStep('recover_my_posts', 'GET', '/api/nexus/me/posts?page%5Blimit%5D=20', 'nexusMyForumPostsList', '#/components/schemas/FlarumPostCollectionDocument'),
                ],
                'preflightAction' => 'forum_post.delete',
                'preflightOperationId' => 'nexusAgentPreflightCreate',
                'writeEndpoint' => 'DELETE /api/nexus/forum/posts/{id}',
                'writeOperationId' => 'nexusForumPostDelete',
                'requestSchemaRef' => '#/components/schemas/ForumPostDeleteInput',
                'responseSchemaRef' => '204 No Content',
                'resultIdField' => 'HTTP 204',
                'requiresAuthentication' => true,
                'requiresUserConfirmation' => true,
                'requiredPermission' => 'allowAgentReplying',
            ],
        ];
    }

    public static function tags(): array
    {
        return [
            'Nexus Discovery',
            'Nexus Agent Skill',
            'Nexus Help Requests',
            'Nexus Dispatches',
            'Nexus Matches',
            'Nexus Forum Gateway',
            'Flarum Auth',
        ];
    }

    private static function readStep(string $name, string $method, string $endpoint, string $operationId, string $responseSchemaRef): array
    {
        return [
            'name' => $name,
            'method' => $method,
            'endpoint' => $endpoint,
            'operationId' => $operationId,
            'responseSchemaRef' => $responseSchemaRef,
            'writesState' => false,
        ];
    }
}
