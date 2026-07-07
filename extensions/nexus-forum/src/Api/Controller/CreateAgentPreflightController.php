<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\User\Exception\NotAuthenticatedException;
use Illuminate\Support\Arr;
use Laminas\Diactoros\Response\JsonResponse;
use Nexus\Forum\Model\AgentProfile;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Service\AgentPreflightCatalog;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;

class CreateAgentPreflightController implements RequestHandlerInterface
{
    public function handle(ServerRequestInterface $request): ResponseInterface
    {
        $actor = RequestUtil::getActor($request);

        if ($actor->isGuest()) {
            throw new NotAuthenticatedException;
        }

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $action = trim((string) ($attributes['action'] ?? ''));

        if (! AgentPreflightCatalog::hasAction($action)) {
            throw new ValidationException([
                'action' => 'action must be one of: '.implode(', ', AgentPreflightCatalog::actionNames()).'.',
            ]);
        }

        $definition = AgentPreflightCatalog::definition($action);
        $profile = AgentProfile::query()->where('user_id', (int) $actor->id)->first();
        $userConfirmed = (bool) ($attributes['userConfirmed'] ?? false);
        $checks = [];
        $blocking = [];
        $nextActions = [];

        if ($definition['requiresConfirmation']) {
            $ready = $userConfirmed;
            $checks['userConfirmed'] = [
                'ready' => $ready,
                'required' => true,
                'reason' => $ready
                    ? 'The proposed action includes userConfirmed=true.'
                    : 'This action changes state and requires explicit user confirmation immediately before execution.',
            ];

            if (! $ready) {
                $blocking[] = 'userConfirmed';
                $nextActions[] = [
                    'name' => 'ask_user_to_confirm_exact_action',
                    'method' => null,
                    'endpoint' => null,
                    'requiresUserConfirmation' => true,
                ];
            }
        } else {
            $checks['userConfirmed'] = [
                'ready' => true,
                'required' => false,
                'reason' => 'This preflight action is draft/read-only and does not require userConfirmed=true.',
            ];
        }

        foreach ($definition['permissions'] as $permission) {
            $column = AgentPreflightCatalog::permissionColumn($permission);
            $ready = $profile && (bool) $profile->$column;

            $checks[$permission] = [
                'ready' => $ready,
                'required' => true,
                'reason' => $ready
                    ? "Agent Profile permissions.$permission is enabled."
                    : "Enable permissions.$permission in /api/nexus/me/agent-profile before this action.",
            ];

            if (! $ready) {
                $blocking[] = $permission;
                $nextActions[] = [
                    'name' => 'enable_'.$permission,
                    'method' => 'PATCH',
                    'endpoint' => '/api/nexus/me/agent-profile',
                    'requiresUserConfirmation' => true,
                ];
            }
        }

        $targetResult = $this->targetChecks($action, $attributes, $actor);
        $checks = array_merge($checks, $targetResult['checks']);
        $blocking = array_merge($blocking, $targetResult['blocking']);
        $nextActions = array_merge($nextActions, $targetResult['nextActions']);
        $blocking = array_values(array_unique($blocking));

        $recovery = $this->recovery($action, $definition, $blocking, $checks, $targetResult['target']);

        return new JsonResponse([
            'data' => [
                'type' => 'nexus-agent-preflights',
                'id' => $action,
                'attributes' => [
                    'action' => $action,
                    'endpoint' => $definition['endpoint'],
                    'purpose' => $definition['purpose'] ?? null,
                    'allowed' => count($blocking) === 0,
                    'requiresConfirmation' => (bool) $definition['requiresConfirmation'],
                    'requiredPermissions' => $definition['permissions'],
                    'targetType' => $definition['targetType'] ?? null,
                    'targetRequiredForPreflight' => (bool) ($definition['targetRequiredForPreflight'] ?? false),
                    'targetIdAliases' => $definition['targetIdAliases'] ?? [],
                    'proposedFields' => $definition['proposedFields'] ?? [],
                    'allowedProposedStatus' => $definition['allowedProposedStatus'] ?? [],
                    'writeBodySchemaRef' => $definition['writeBodySchemaRef'] ?? null,
                    'sideEffects' => $definition['sideEffects'] ?? [],
                    'target' => $targetResult['target'],
                    'blocking' => $blocking,
                    'checks' => $checks,
                    'recovery' => $recovery,
                    'nextActions' => $nextActions,
                    'notes' => [
                        'preflightOnly' => true,
                        'noDatabaseWrite' => true,
                        'stillUseTargetEndpoint' => true,
                    ],
                ],
            ],
        ], 200, [
            'content-type' => 'application/vnd.api+json',
        ]);
    }

    private function recovery(string $action, array $definition, array $blocking, array $checks, array $target): array
    {
        $blocking = array_values(array_unique($blocking));
        $steps = [];

        foreach ($blocking as $blocker) {
            $steps[] = $this->recoveryStepForBlocker($blocker, $definition, $target);
        }

        if ($steps === []) {
            $steps[] = [
                'name' => 'call_target_endpoint_after_confirmation',
                'kind' => 'execute',
                'method' => $this->endpointMethod($definition['endpoint'] ?? ''),
                'endpoint' => $this->endpointPath($definition['endpoint'] ?? ''),
                'requiresUserConfirmation' => (bool) ($definition['requiresConfirmation'] ?? false),
                'reason' => 'Preflight did not find blocking checks. Still call the target endpoint; preflight is not the write.',
            ];
        }

        return [
            'schemaVersion' => '0.1',
            'status' => $blocking === [] ? 'ready_for_target_endpoint' : 'blocked_needs_recovery',
            'action' => $action,
            'blocking' => $blocking,
            'summary' => $blocking === []
                ? 'No blocking checks remain. Ask for exact confirmation if the action writes state, then call the target endpoint.'
                : 'Resolve the blocking checks before calling the target endpoint. Do not retry the same write body unchanged.',
            'retryPolicy' => [
                'retrySameBody' => $blocking === [],
                'preflightAgainAfterRecovery' => $blocking !== [],
                'targetEndpointStillRequired' => true,
            ],
            'steps' => $steps,
            'relatedChecks' => $this->relatedChecks($blocking, $checks),
        ];
    }

    private function recoveryStepForBlocker(string $blocker, array $definition, array $target): array
    {
        if ($blocker === 'userConfirmed') {
            return [
                'name' => 'ask_user_to_confirm_exact_action',
                'kind' => 'ask_user',
                'requiresUserConfirmation' => true,
                'reason' => 'The action writes state. Show the endpoint, exact payload, visibility, side effects, and safety notes before setting userConfirmed=true.',
                'showFields' => [
                    'endpoint',
                    'writeBodySchemaRef',
                    'proposedFields',
                    'sideEffects',
                    'target',
                ],
            ];
        }

        if (strpos($blocker, 'allowAgent') === 0) {
            return [
                'name' => 'enable_'.$blocker,
                'kind' => 'setup',
                'method' => 'PATCH',
                'endpoint' => '/api/nexus/me/agent-profile',
                'requiresUserConfirmation' => true,
                'reason' => "The user's Agent Profile permissions.$blocker is disabled. Ask before enabling it; never auto-enable permissions.",
                'bodyHint' => [
                    'data' => [
                        'type' => 'nexus-agent-profiles',
                        'attributes' => [
                            'userConfirmed' => true,
                            'permissions' => [
                                $blocker => true,
                            ],
                        ],
                    ],
                ],
            ];
        }

        if ($blocker === 'targetProvided' || $blocker === 'targetType') {
            return [
                'name' => 'supply_correct_target',
                'kind' => 'fix_request',
                'requiresUserConfirmation' => false,
                'reason' => 'Run a read endpoint first to recover the resource id, then preflight again with data.attributes.target.type and target.id.',
                'expectedTargetType' => $definition['targetType'] ?? null,
                'targetIdAliases' => $definition['targetIdAliases'] ?? [],
            ];
        }

        if ($blocker === 'targetExists' || $blocker === 'targetAccessible') {
            return [
                'name' => 'recover_accessible_resource',
                'kind' => 'read',
                'method' => 'GET',
                'endpoint' => $this->recoveryReadEndpointForTarget($definition['targetType'] ?? null),
                'requiresUserConfirmation' => false,
                'reason' => 'The target is missing or not accessible to the current user. Recover an accessible current-user resource before retrying.',
                'target' => $target,
            ];
        }

        if ($blocker === 'targetStatus' || $blocker === 'targetTransition' || $blocker === 'targetNotExpired') {
            return [
                'name' => 'refresh_target_state',
                'kind' => 'read',
                'method' => 'GET',
                'endpoint' => $this->recoveryReadEndpointForTarget($definition['targetType'] ?? null),
                'requiresUserConfirmation' => false,
                'reason' => 'The target state does not allow the proposed write. Refresh the resource, inspect viewerRole/status/nextActions, and choose a valid nextAction.',
                'allowedProposedStatus' => $definition['allowedProposedStatus'] ?? [],
                'target' => $target,
            ];
        }

        if ($blocker === 'targetHelper') {
            return [
                'name' => 'choose_different_helper',
                'kind' => 'read',
                'method' => 'GET',
                'endpoint' => '/api/nexus/help-requests/{id}/candidates',
                'requiresUserConfirmation' => false,
                'reason' => 'The proposed helper is invalid for this request. Re-read candidates and choose a different helper before preflighting again.',
            ];
        }

        return [
            'name' => 'inspect_blocking_check',
            'kind' => 'manual_review',
            'requiresUserConfirmation' => false,
            'reason' => "Inspect checks.$blocker.reason, refresh context, and preflight again before writing.",
            'blockingCheck' => $blocker,
        ];
    }

    private function relatedChecks(array $blocking, array $checks): array
    {
        $related = [];

        foreach ($blocking as $blocker) {
            if (isset($checks[$blocker])) {
                $related[$blocker] = $checks[$blocker];
            }
        }

        return $related;
    }

    private function recoveryReadEndpointForTarget(?string $targetType): string
    {
        if ($targetType === 'help_request') {
            return '/api/nexus/me/help-requests';
        }

        if ($targetType === 'help_dispatch') {
            return '/api/nexus/me/dispatches';
        }

        if ($targetType === 'help_match') {
            return '/api/nexus/me/matches';
        }

        return '/api/nexus/me/agent-context';
    }

    private function endpointMethod(string $endpoint): ?string
    {
        $parts = explode(' ', trim($endpoint), 2);

        return $parts[0] !== '' ? $parts[0] : null;
    }

    private function endpointPath(string $endpoint): ?string
    {
        $parts = explode(' ', trim($endpoint), 2);

        return $parts[1] ?? null;
    }

    private function targetChecks(string $action, array $attributes, $actor): array
    {
        $result = [
            'target' => [
                'supported' => false,
                'provided' => false,
            ],
            'checks' => [],
            'blocking' => [],
            'nextActions' => [],
        ];

        if (in_array($action, ['help_request.update', 'dispatch.create', 'match.offer'], true)) {
            return $this->helpRequestTargetChecks($action, $attributes, $actor, $result);
        }

        if ($action === 'dispatch.update') {
            return $this->dispatchTargetChecks($attributes, $actor, $result);
        }

        if (in_array($action, ['match.update', 'match_message.create'], true)) {
            return $this->matchTargetChecks($action, $attributes, $actor, $result);
        }

        return $result;
    }

    private function helpRequestTargetChecks(string $action, array $attributes, $actor, array $result): array
    {
        $targetId = $this->extractTargetId($attributes, ['helpRequestId']);
        $expectedType = 'help_request';
        $result['target'] = [
            'supported' => true,
            'provided' => $targetId !== null,
            'expectedType' => $expectedType,
            'id' => $targetId,
        ];

        $this->checkTargetType($attributes, $expectedType, $result);

        if ($targetId === null) {
            $this->addCheck($result, 'targetProvided', true, false, 'No help request target id was supplied, so resource-specific preflight checks were skipped.');
            $this->addSupplyTargetAction($result, 'helpRequestId');

            return $result;
        }

        $helpRequest = HelpRequest::query()->find($targetId);
        $this->addCheck($result, 'targetExists', $helpRequest !== null, true, $helpRequest ? 'The help request exists.' : 'The help request target was not found.');

        if (! $helpRequest) {
            return $result;
        }

        $role = $this->helpRequestRole($helpRequest, $actor);
        $result['target'] += [
            'type' => $expectedType,
            'status' => $helpRequest->status,
            'viewerRole' => $role,
            'requesterUserId' => (int) $helpRequest->requester_user_id,
        ];

        if ($action === 'help_request.update') {
            $ready = in_array($role, ['requester', 'admin'], true);
            $this->addCheck($result, 'targetAccessible', $ready, true, $ready
                ? "The current user can update this help request as $role."
                : 'Only the requester or an admin can update this help request.');

            return $result;
        }

        $open = in_array($helpRequest->status, ['open', 'matching'], true);
        $this->addCheck($result, 'targetStatus', $open, true, $open
            ? 'The help request is open for routing.'
            : 'Only open or matching help requests can receive dispatches or match offers.');

        if ($action === 'dispatch.create') {
            $ready = in_array($role, ['requester', 'admin'], true);
            $this->addCheck($result, 'targetAccessible', $ready, true, $ready
                ? "The current user can dispatch this help request as $role."
                : 'Only the requester or an admin can dispatch this help request.');

            $helperUserId = $this->extractInt($attributes, ['helperUserId', 'target.helperUserId', 'proposed.helperUserId', 'proposedAttributes.helperUserId', 'body.data.attributes.helperUserId']);
            if ($helperUserId !== null) {
                $result['target']['helperUserId'] = $helperUserId;
                $notSelf = $helperUserId !== (int) $helpRequest->requester_user_id;
                $this->addCheck($result, 'targetHelper', $notSelf, true, $notSelf
                    ? 'The proposed helper is not the requester.'
                    : 'A requester cannot dispatch their own request to themselves.');
            }
        }

        if ($action === 'match.offer') {
            $ready = $role !== 'requester';
            $this->addCheck($result, 'targetAccessible', $ready, true, $ready
                ? 'The current user can offer help on this request.'
                : 'The requester cannot offer a match on their own request.');
        }

        return $result;
    }

    private function dispatchTargetChecks(array $attributes, $actor, array $result): array
    {
        $targetId = $this->extractTargetId($attributes, ['dispatchId']);
        $expectedType = 'help_dispatch';
        $result['target'] = [
            'supported' => true,
            'provided' => $targetId !== null,
            'expectedType' => $expectedType,
            'id' => $targetId,
        ];

        $this->checkTargetType($attributes, $expectedType, $result);

        if ($targetId === null) {
            $this->addCheck($result, 'targetProvided', true, false, 'No dispatch target id was supplied, so resource-specific preflight checks were skipped.');
            $this->addSupplyTargetAction($result, 'dispatchId');

            return $result;
        }

        $dispatch = HelpDispatch::query()->with('helpRequest')->find($targetId);

        if (! $dispatch) {
            $this->addCheck($result, 'targetAccessible', false, true, 'The dispatch target was not found or is not accessible to this user.');
            return $result;
        }

        $role = $this->dispatchRole($dispatch, $actor);
        $accessible = in_array($role, ['requester', 'helper', 'admin'], true);
        $this->addCheck($result, 'targetAccessible', $accessible, true, $accessible
            ? "The current user can see this dispatch as $role."
            : 'The dispatch target was not found or is not accessible to this user.');

        if (! $accessible) {
            return $result;
        }

        $this->addCheck($result, 'targetExists', true, true, 'The dispatch exists.');
        $status = $this->proposedStatus($attributes);
        $result['target'] += [
            'type' => $expectedType,
            'status' => $dispatch->status,
            'proposedStatus' => $status,
            'viewerRole' => $role,
            'helpRequestId' => (int) $dispatch->help_request_id,
            'requesterUserId' => (int) $dispatch->requester_user_id,
            'helperUserId' => (int) $dispatch->helper_user_id,
            'matchId' => $dispatch->match_id === null ? null : (int) $dispatch->match_id,
        ];

        $pending = $dispatch->status === 'pending';
        $this->addCheck($result, 'targetStatus', $pending, true, $pending
            ? 'The dispatch is pending and can still receive a response.'
            : 'Resolved dispatches cannot be accepted, declined, or cancelled.');

        if ($status !== null) {
            $transitionAllowed = $this->dispatchTransitionAllowed($status, $role);
            $this->addCheck($result, 'targetTransition', $transitionAllowed, true, $transitionAllowed
                ? "The proposed dispatch status '$status' is allowed for $role."
                : "The proposed dispatch status '$status' is not allowed for this viewer role.");

            if ($status === 'accepted') {
                $notExpired = ! $dispatch->expires_at || ! $dispatch->expires_at->isPast();
                $this->addCheck($result, 'targetNotExpired', $notExpired, true, $notExpired
                    ? 'The dispatch is not expired.'
                    : 'This dispatch has expired and cannot be accepted.');
            }
        } else {
            $this->addCheck($result, 'targetTransition', true, false, 'No proposed status was supplied; role and pending-state checks were performed only.');
        }

        return $result;
    }

    private function matchTargetChecks(string $action, array $attributes, $actor, array $result): array
    {
        $targetId = $this->extractTargetId($attributes, ['matchId']);
        $expectedType = 'help_match';
        $result['target'] = [
            'supported' => true,
            'provided' => $targetId !== null,
            'expectedType' => $expectedType,
            'id' => $targetId,
        ];

        $this->checkTargetType($attributes, $expectedType, $result);

        if ($targetId === null) {
            $this->addCheck($result, 'targetProvided', true, false, 'No match target id was supplied, so resource-specific preflight checks were skipped.');
            $this->addSupplyTargetAction($result, 'matchId');

            return $result;
        }

        $match = HelpMatch::query()->with('helpRequest')->find($targetId);

        if (! $match) {
            $this->addCheck($result, 'targetAccessible', false, true, 'The match target was not found or is not accessible to this user.');
            return $result;
        }

        $role = $this->matchRole($match, $actor);
        $accessible = in_array($role, ['requester', 'helper', 'admin'], true);
        $this->addCheck($result, 'targetAccessible', $accessible, true, $accessible
            ? "The current user can access this match as $role."
            : 'The match target was not found or is not accessible to this user.');

        if (! $accessible) {
            return $result;
        }

        $this->addCheck($result, 'targetExists', true, true, 'The match exists.');
        $status = $this->proposedStatus($attributes);
        $result['target'] += [
            'type' => $expectedType,
            'status' => $match->status,
            'proposedStatus' => $status,
            'viewerRole' => $role,
            'helpRequestId' => (int) $match->help_request_id,
            'helperUserId' => (int) $match->helper_user_id,
        ];

        if ($action === 'match_message.create') {
            $accepted = $match->status === 'accepted';
            $this->addCheck($result, 'targetStatus', $accepted, true, $accepted
                ? 'The match is accepted and can receive private coordination messages.'
                : 'Match messages can only be sent after the match is accepted.');

            return $result;
        }

        $active = in_array($match->status, ['offered', 'accepted'], true);
        $this->addCheck($result, 'targetStatus', $active, true, $active
            ? 'The match is active and can still be updated.'
            : 'Resolved matches cannot be reopened or changed.');

        if ($status !== null) {
            $transitionAllowed = $this->matchTransitionAllowed($match->status, $status, $role);
            $this->addCheck($result, 'targetTransition', $transitionAllowed, true, $transitionAllowed
                ? "The proposed match status '$status' is allowed for $role."
                : "Cannot move this match from {$match->status} to $status for this viewer role.");
        } else {
            $this->addCheck($result, 'targetTransition', true, false, 'No proposed status was supplied; role and active-state checks were performed only.');
        }

        return $result;
    }

    private function addCheck(array &$result, string $name, bool $ready, bool $required, string $reason): void
    {
        $result['checks'][$name] = [
            'ready' => $ready,
            'required' => $required,
            'reason' => $reason,
        ];

        if ($required && ! $ready) {
            $result['blocking'][] = $name;
        }
    }

    private function checkTargetType(array $attributes, string $expectedType, array &$result): void
    {
        $type = Arr::get($attributes, 'target.type');

        if (! $type) {
            return;
        }

        $ready = (string) $type === $expectedType;
        $this->addCheck($result, 'targetType', $ready, true, $ready
            ? "The target type is $expectedType."
            : "target.type should be $expectedType for this action.");
    }

    private function addSupplyTargetAction(array &$result, string $field): void
    {
        $result['nextActions'][] = [
            'name' => 'supply_target_id',
            'method' => null,
            'endpoint' => null,
            'requiresUserConfirmation' => false,
            'purpose' => "Include data.attributes.target.id or data.attributes.$field to enable resource-specific dry-run checks.",
        ];
    }

    private function extractTargetId(array $attributes, array $aliases): ?int
    {
        return $this->extractInt($attributes, array_merge(['target.id', 'targetId'], $aliases));
    }

    private function extractInt(array $attributes, array $paths): ?int
    {
        foreach ($paths as $path) {
            $value = Arr::get($attributes, $path);

            if ($value !== null && is_numeric($value) && (int) $value > 0) {
                return (int) $value;
            }
        }

        return null;
    }

    private function proposedStatus(array $attributes): ?string
    {
        $status = Arr::get($attributes, 'proposed.status')
            ?: Arr::get($attributes, 'proposedAttributes.status')
            ?: Arr::get($attributes, 'body.data.attributes.status')
            ?: Arr::get($attributes, 'status');

        return $status === null || $status === '' ? null : (string) $status;
    }

    private function helpRequestRole(HelpRequest $helpRequest, $actor): string
    {
        if ((int) $helpRequest->requester_user_id === (int) $actor->id) {
            return 'requester';
        }

        return $actor->isAdmin() ? 'admin' : 'outsider';
    }

    private function dispatchRole(HelpDispatch $dispatch, $actor): string
    {
        if ((int) $dispatch->helper_user_id === (int) $actor->id) {
            return 'helper';
        }

        if ((int) $dispatch->requester_user_id === (int) $actor->id) {
            return 'requester';
        }

        return $actor->isAdmin() ? 'admin' : 'outsider';
    }

    private function matchRole(HelpMatch $match, $actor): string
    {
        if ((int) $match->helper_user_id === (int) $actor->id) {
            return 'helper';
        }

        $helpRequest = $match->helpRequest;
        if ($helpRequest && (int) $helpRequest->requester_user_id === (int) $actor->id) {
            return 'requester';
        }

        return $actor->isAdmin() ? 'admin' : 'outsider';
    }

    private function dispatchTransitionAllowed(string $status, string $role): bool
    {
        if (in_array($status, ['accepted', 'declined'], true)) {
            return $role === 'helper';
        }

        if ($status === 'cancelled') {
            return in_array($role, ['requester', 'admin'], true);
        }

        return false;
    }

    private function matchTransitionAllowed(string $currentStatus, string $nextStatus, string $role): bool
    {
        if ($nextStatus === 'offered') {
            return $currentStatus === 'offered';
        }

        if ($currentStatus === 'offered' && in_array($nextStatus, ['accepted', 'declined'], true)) {
            return in_array($role, ['requester', 'admin'], true);
        }

        if (in_array($currentStatus, ['offered', 'accepted'], true) && $nextStatus === 'cancelled') {
            return in_array($role, ['requester', 'helper', 'admin'], true);
        }

        if ($currentStatus === 'accepted' && $nextStatus === 'completed') {
            return in_array($role, ['requester', 'helper', 'admin'], true);
        }

        return $currentStatus === $nextStatus && in_array($currentStatus, ['offered', 'accepted'], true);
    }
}
