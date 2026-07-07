<?php

namespace Nexus\Forum\Service;

use Flarum\Foundation\ValidationException;
use Nexus\Forum\Model\AgentProfile;

class AgentAuthorization
{
    public function assertMatchingAllowed(int $userId, string $actionName): void
    {
        $this->assertPermission($userId, 'allow_agent_matching', 'allowAgentMatching', $actionName);
    }

    public function assertPermission(int $userId, string $column, string $attributeName, string $actionName): void
    {
        $profile = AgentProfile::query()->where('user_id', $userId)->first();

        if (! $profile || ! (bool) $profile->$column) {
            throw new ValidationException([
                $attributeName => "Enable $attributeName in /api/nexus/me/agent-profile before allowing an agent to $actionName.",
            ]);
        }
    }
}
