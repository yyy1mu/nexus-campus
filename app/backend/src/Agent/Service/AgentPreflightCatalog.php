<?php

namespace Nexus\Forum\Service;

class AgentPreflightCatalog
{
    private const AGENT_PUBLIC_FOOTER = 'Posted by Nexus Agent after explicit user confirmation.';
    private const AGENT_HELP_FOOTER = 'Drafted by Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.';
    private const AGENT_MATCH_OFFER_FOOTER = 'Offered through Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.';
    private const AGENT_DISPATCH_ACCEPT_FOOTER = 'Accepted through Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.';

    private const PERMISSION_COLUMNS = [
        'allowAgentPosting' => 'allow_agent_posting',
        'allowAgentReplying' => 'allow_agent_replying',
        'allowAgentMatching' => 'allow_agent_matching',
        'allowLocationMatching' => 'allow_location_matching',
    ];

    public static function actions(): array
    {
        return self::catalog();
    }

    public static function actionNames(): array
    {
        return array_keys(self::catalog());
    }

    public static function hasAction(string $action): bool
    {
        return array_key_exists($action, self::catalog());
    }

    public static function definition(string $action): array
    {
        return self::catalog()[$action];
    }

    public static function permissionColumn(string $permission): string
    {
        return self::PERMISSION_COLUMNS[$permission];
    }

    public static function publicFooter(): string
    {
        return self::AGENT_PUBLIC_FOOTER;
    }

    public static function helpFooter(): string
    {
        return self::AGENT_HELP_FOOTER;
    }

    public static function matchOfferFooter(): string
    {
        return self::AGENT_MATCH_OFFER_FOOTER;
    }

    public static function dispatchAcceptFooter(): string
    {
        return self::AGENT_DISPATCH_ACCEPT_FOOTER;
    }

    private static function catalog(): array
    {
        return [
        'need_draft' => [
            'endpoint' => 'POST /api/nexus/need-drafts',
            'requiresConfirmation' => false,
            'permissions' => [],
            'purpose' => 'Classify a raw natural-language user need, return a draft and read-only discoveryPlan, and avoid publishing or writing database state.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['rawUserNeed', 'intent', 'locationHint'],
            'writeBodySchemaRef' => '#/components/schemas/NeedDraftInput',
            'sideEffects' => self::sideEffects([
                'writesDatabase' => false,
                'createsPublicContent' => false,
                'createsActionLog' => false,
                'visibility' => 'private_to_calling_agent_response',
            ]),
            'examplePreflightBody' => [
                'data' => [
                    'type' => 'nexus-agent-preflights',
                    'attributes' => [
                        'action' => 'need_draft',
                    ],
                ],
            ],
        ],
        'forum_discussion.create' => [
            'endpoint' => 'POST /api/nexus/forum/discussions',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentPosting'],
            'purpose' => 'Create a general forum discussion through the Nexus gateway after the user confirms the exact public title, body, and tags.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['title', 'content', 'tagIds', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/ForumDiscussionInput',
            'sideEffects' => self::sideEffects([
                'createsPublicContent' => true,
                'createsPublicDiscussion' => true,
                'visibility' => 'public_forum',
                'serverAppendedFooter' => self::AGENT_PUBLIC_FOOTER,
            ]),
            'examplePreflightBody' => self::example('forum_discussion.create'),
        ],
        'forum_post.reply' => [
            'endpoint' => 'POST /api/nexus/forum/discussions/{id}/posts',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentReplying'],
            'purpose' => 'Reply to an existing forum discussion through the Nexus gateway after the user confirms the exact public reply.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => ['discussion id in endpoint path'],
            'proposedFields' => ['content', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/ForumPostInput',
            'sideEffects' => self::sideEffects([
                'createsPublicContent' => true,
                'createsPublicReply' => true,
                'visibility' => 'public_forum',
                'serverAppendedFooter' => self::AGENT_PUBLIC_FOOTER,
            ]),
            'examplePreflightBody' => self::example('forum_post.reply'),
        ],
        'forum_post.edit' => [
            'endpoint' => 'PATCH /api/nexus/forum/posts/{id}',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentReplying'],
            'purpose' => 'Edit the current user\'s own forum post through the Nexus gateway after exact user confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => ['post id in endpoint path'],
            'proposedFields' => ['content', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/ForumPostInput',
            'sideEffects' => self::sideEffects([
                'updatesPublicContent' => true,
                'visibility' => 'public_forum',
                'serverAppendedFooter' => 'Edited by Nexus Agent after explicit user confirmation.',
            ]),
            'examplePreflightBody' => self::example('forum_post.edit'),
        ],
        'forum_post.delete' => [
            'endpoint' => 'DELETE /api/nexus/forum/posts/{id}',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentReplying'],
            'purpose' => 'Hide the current user\'s own forum post through the Nexus gateway after exact user confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => ['post id in endpoint path'],
            'proposedFields' => ['reason', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/ForumPostDeleteInput',
            'sideEffects' => self::sideEffects([
                'updatesPublicContent' => true,
                'softDeletesOwnPost' => true,
                'visibility' => 'public_forum_post_hidden',
            ]),
            'examplePreflightBody' => self::example('forum_post.delete'),
        ],
        'agent_profile.update' => [
            'endpoint' => 'PATCH /api/nexus/me/agent-profile',
            'requiresConfirmation' => true,
            'permissions' => [],
            'purpose' => 'Update the current user\'s private Agent Profile, soul.md metadata, preferences, or authorization switches after explicit confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['agentName', 'soulMd', 'interestTags', 'skillTags', 'helpTags', 'matchPreferences', 'permissions', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/AgentProfileInput',
            'sideEffects' => self::sideEffects([
                'visibility' => 'current_user_private_profile',
                'containsPrivateProfileData' => true,
            ]),
            'examplePreflightBody' => self::example('agent_profile.update'),
        ],
        'capabilities.update' => [
            'endpoint' => 'PATCH /api/nexus/me/capabilities',
            'requiresConfirmation' => true,
            'permissions' => [],
            'purpose' => 'Update the current user\'s public helper capability labels after explicit confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['capabilities', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/CapabilityCollectionInput',
            'sideEffects' => self::sideEffects([
                'updatesPublicProfile' => true,
                'visibility' => 'public_capability_labels',
            ]),
            'examplePreflightBody' => self::example('capabilities.update'),
        ],
        'help_request.create' => [
            'endpoint' => 'POST /api/nexus/help-requests',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Create a public real-world help request only after read-before-write discovery and exact requester confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['title', 'summary', 'content', 'neededLabels', 'categoryLabel', 'urgency', 'locationHint', 'meetingSafetyState', 'agentContext', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/HelpRequestInput',
            'sideEffects' => self::sideEffects([
                'createsHelpRequest' => true,
                'createsPublicContent' => true,
                'createsPublicDiscussion' => true,
                'visibility' => 'public_help_board_and_forum',
                'serverAppendedFooter' => self::AGENT_HELP_FOOTER,
            ]),
            'examplePreflightBody' => self::example('help_request.create'),
        ],
        'help_request.update' => [
            'endpoint' => 'PATCH /api/nexus/help-requests/{id}',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Update the requester-owned help request status, safe meeting state, public-safe location hint, summary, or labels.',
            'targetType' => 'help_request',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'helpRequestId'],
            'proposedFields' => ['status', 'meetingSafetyState', 'locationHint', 'summary', 'neededLabels', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/HelpRequestUpdateInput',
            'sideEffects' => self::sideEffects([
                'updatesHelpRequest' => true,
                'visibility' => 'public_help_metadata',
            ]),
            'examplePreflightBody' => self::targetExample('help_request.update', 'help_request', ['status' => 'closed']),
        ],
        'dispatch.create' => [
            'endpoint' => 'POST /api/nexus/help-requests/{id}/dispatches',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Invite one candidate helper to a requester-owned open help request after requester confirmation.',
            'targetType' => 'help_request',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'helpRequestId'],
            'proposedFields' => ['helperUserId', 'message', 'rationale', 'meetingHint', 'meetingSafetyState', 'expiresAt', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/HelpDispatchInput',
            'sideEffects' => self::sideEffects([
                'createsDispatch' => true,
                'createsNotification' => true,
                'visibility' => 'requester_helper_scoped_dispatch',
            ]),
            'examplePreflightBody' => self::targetExample('dispatch.create', 'help_request', ['helperUserId' => 2]),
        ],
        'dispatch.update' => [
            'endpoint' => 'PATCH /api/nexus/dispatches/{id}',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Accept, decline, or cancel a scoped dispatch invitation after the acting participant confirms the exact response.',
            'targetType' => 'help_dispatch',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'dispatchId'],
            'proposedFields' => ['status', 'responseMessage', 'message', 'meetingHint', 'meetingSafetyState', 'userConfirmed'],
            'allowedProposedStatus' => ['accepted', 'declined', 'cancelled'],
            'writeBodySchemaRef' => '#/components/schemas/HelpDispatchUpdateInput',
            'sideEffects' => self::sideEffects([
                'updatesDispatch' => true,
                'mayCreateMatch' => true,
                'mayCreatePublicReply' => true,
                'visibility' => 'requester_helper_scoped_dispatch',
                'serverAppendedFooterWhenAccepted' => self::AGENT_DISPATCH_ACCEPT_FOOTER,
            ]),
            'examplePreflightBody' => self::targetExample('dispatch.update', 'help_dispatch', ['status' => 'accepted']),
        ],
        'match.offer' => [
            'endpoint' => 'POST /api/nexus/help-requests/{id}/matches',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Offer help on another user\'s open help request after the helper confirms the exact public offer.',
            'targetType' => 'help_request',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'helpRequestId'],
            'proposedFields' => ['message', 'meetingHint', 'meetingSafetyState', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/MatchInput',
            'sideEffects' => self::sideEffects([
                'createsMatchOffer' => true,
                'createsPublicReply' => true,
                'visibility' => 'public_help_thread_and_scoped_match',
                'serverAppendedFooter' => self::AGENT_MATCH_OFFER_FOOTER,
            ]),
            'examplePreflightBody' => self::targetExample('match.offer', 'help_request', ['message' => 'I can help at a public campus spot.']),
        ],
        'match.update' => [
            'endpoint' => 'PATCH /api/nexus/matches/{id}',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Accept, decline, cancel, or complete a match after the acting participant confirms the exact state change.',
            'targetType' => 'help_match',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'matchId'],
            'proposedFields' => ['status', 'meetingHint', 'meetingSafetyState', 'userConfirmed'],
            'allowedProposedStatus' => ['offered', 'accepted', 'declined', 'cancelled', 'completed'],
            'writeBodySchemaRef' => '#/components/schemas/MatchUpdateInput',
            'sideEffects' => self::sideEffects([
                'updatesMatch' => true,
                'mayUpdateHelpRequestStatus' => true,
                'visibility' => 'requester_helper_scoped_match',
            ]),
            'examplePreflightBody' => self::targetExample('match.update', 'help_match', ['status' => 'accepted']),
        ],
        'match_message.create' => [
            'endpoint' => 'POST /api/nexus/matches/{id}/messages',
            'requiresConfirmation' => true,
            'permissions' => ['allowAgentMatching'],
            'purpose' => 'Send a private requester/helper coordination message only after the match is accepted and the user confirms the exact text.',
            'targetType' => 'help_match',
            'targetRequiredForPreflight' => true,
            'targetIdAliases' => ['target.id', 'targetId', 'matchId'],
            'proposedFields' => ['content', 'agentContext', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/MatchMessageInput',
            'sideEffects' => self::sideEffects([
                'createsPrivateMessage' => true,
                'visibility' => 'requester_helper_private_match_message',
            ]),
            'examplePreflightBody' => self::targetExample('match_message.create', 'help_match', ['content' => 'Let us meet at the library front desk.']),
        ],
        'device_signal.create' => [
            'endpoint' => 'POST /api/nexus/device-signals',
            'requiresConfirmation' => true,
            'permissions' => [],
            'purpose' => 'Upload a coarse, short-lived current-user device/location placeholder for future Linkgo/mobile integration after confirmation.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['purpose', 'coarseGeohash', 'accuracyM', 'bluetoothSeen', 'shakeDetected', 'gyroAvailable', 'payload', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/DeviceSignalInput',
            'sideEffects' => self::sideEffects([
                'storesShortLivedDeviceSignal' => true,
                'visibility' => 'current_user_private_device_signal',
            ]),
            'examplePreflightBody' => self::example('device_signal.create'),
        ],
        'llm_settings.update' => [
            'endpoint' => 'PATCH /api/nexus/llm-settings',
            'requiresConfirmation' => true,
            'permissions' => [],
            'purpose' => 'Update the current user\'s optional forum-side LLM provider metadata after confirmation; local agents can still call Nexus APIs without this.',
            'targetType' => null,
            'targetRequiredForPreflight' => false,
            'targetIdAliases' => [],
            'proposedFields' => ['provider', 'baseUrl', 'apiKey', 'chatModel', 'responsesModel', 'supportsChatCompletions', 'supportsResponses', 'userConfirmed'],
            'writeBodySchemaRef' => '#/components/schemas/LlmSettingsInput',
            'sideEffects' => self::sideEffects([
                'storesPrivateLlmSettings' => true,
                'storesWriteOnlyApiKey' => true,
                'visibility' => 'current_user_private_llm_settings',
            ]),
            'examplePreflightBody' => self::example('llm_settings.update'),
        ],
        ];
    }

    private static function sideEffects(array $overrides = []): array
    {
        return array_merge([
            'writesDatabase' => true,
            'createsPublicContent' => false,
            'createsPublicDiscussion' => false,
            'createsPublicReply' => false,
            'createsNotification' => false,
            'createsActionLog' => true,
            'visibility' => 'current_user_scoped',
        ], $overrides);
    }

    private static function example(string $action): array
    {
        return [
            'data' => [
                'type' => 'nexus-agent-preflights',
                'attributes' => [
                    'action' => $action,
                    'userConfirmed' => false,
                ],
            ],
        ];
    }

    private static function targetExample(string $action, string $targetType, array $proposed): array
    {
        $attributes = [
            'action' => $action,
            'userConfirmed' => false,
            'target' => [
                'type' => $targetType,
                'id' => 1,
            ],
        ];

        if ($proposed !== []) {
            $attributes['proposed'] = $proposed;
        }

        return [
            'data' => [
                'type' => 'nexus-agent-preflights',
                'attributes' => $attributes,
            ],
        ];
    }
}
