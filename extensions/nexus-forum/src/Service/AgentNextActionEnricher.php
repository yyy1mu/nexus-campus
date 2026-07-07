<?php

namespace Nexus\Forum\Service;

class AgentNextActionEnricher
{
    public function enrich(array $action, ?string $catalogAction = null): array
    {
        $catalogAction = $catalogAction ?: $this->catalogActionFrom($action);

        if (! $catalogAction || ! AgentPreflightCatalog::hasAction($catalogAction)) {
            return $action;
        }

        $definition = AgentPreflightCatalog::definition($catalogAction);
        $action['catalogAction'] = $catalogAction;
        $action['writeBodySchemaRef'] = $definition['writeBodySchemaRef'] ?? null;
        $action['proposedFields'] = $definition['proposedFields'] ?? [];
        $action['allowedProposedStatus'] = $definition['allowedProposedStatus'] ?? [];
        $action['sideEffects'] = $definition['sideEffects'] ?? [];

        if (! isset($action['requiredPermission']) && count($definition['permissions'] ?? []) === 1) {
            $action['requiredPermission'] = $definition['permissions'][0];
        }

        if (! array_key_exists('requiresUserConfirmation', $action)) {
            $action['requiresUserConfirmation'] = (bool) ($definition['requiresConfirmation'] ?? false);
        }

        return $action;
    }

    private function catalogActionFrom(array $action): ?string
    {
        $bodyAction = $action['body']['data']['attributes']['action'] ?? null;

        if (is_string($bodyAction) && $bodyAction !== '') {
            return $bodyAction;
        }

        $preflightAction = $action['preflight']['body']['data']['attributes']['action'] ?? null;

        if (is_string($preflightAction) && $preflightAction !== '') {
            return $preflightAction;
        }

        return null;
    }
}
