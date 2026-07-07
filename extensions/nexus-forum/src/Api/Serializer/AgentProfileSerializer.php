<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\AgentProfile;

class AgentProfileSerializer extends AbstractSerializer
{
    protected $type = 'nexus-agent-profiles';

    public function getId($profile)
    {
        return (string) $profile->user_id;
    }

    protected function getDefaultAttributes($profile): array
    {
        /** @var AgentProfile $profile */
        return [
            'userId' => (int) $profile->user_id,
            'agentName' => $profile->agent_name,
            'agentAvatarUrl' => $profile->agent_avatar_url,
            'soulMd' => $profile->soul_md,
            'interestTags' => $this->decodeList($profile->interest_tags),
            'skillTags' => $this->decodeList($profile->skill_tags),
            'helpTags' => $this->decodeList($profile->help_tags),
            'matchPreferences' => $this->decodeObject($profile->match_preferences),
            'permissions' => [
                'allowAgentPosting' => (bool) $profile->allow_agent_posting,
                'allowAgentReplying' => (bool) $profile->allow_agent_replying,
                'allowAgentMatching' => (bool) $profile->allow_agent_matching,
                'allowLocationMatching' => (bool) $profile->allow_location_matching,
                'locationVisibility' => $profile->location_visibility ?: 'off',
            ],
            'createdAt' => $this->formatDate($profile->created_at),
            'updatedAt' => $this->formatDate($profile->updated_at),
        ];
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

    protected function user($profile)
    {
        return $this->hasOne($profile, BasicUserSerializer::class);
    }
}
