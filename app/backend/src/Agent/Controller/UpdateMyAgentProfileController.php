<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractShowController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Agent\Serializer\AgentProfileSerializer;
use Nexus\Forum\Model\AgentProfile;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateMyAgentProfileController extends AbstractShowController
{
    public $serializer = AgentProfileSerializer::class;

    public $include = ['user'];

    private AgentActionLogger $actionLogger;

    public function __construct(AgentActionLogger $actionLogger)
    {
        $this->actionLogger = $actionLogger;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating your Nexus agent profile requires explicit user confirmation.',
            ]);
        }

        $profile = AgentProfile::query()->where('user_id', $actor->id)->first();

        if (! $profile) {
            $profile = new AgentProfile;
            $profile->user_id = $actor->id;
            $profile->allow_agent_posting = false;
            $profile->allow_agent_replying = false;
            $profile->allow_agent_matching = false;
            $profile->allow_location_matching = false;
            $profile->location_visibility = 'off';
        }

        if (array_key_exists('agentName', $attributes)) {
            $profile->agent_name = NexusPayload::string($attributes, 'agentName', 120, false);
        }

        if (array_key_exists('agentAvatarUrl', $attributes)) {
            $profile->agent_avatar_url = NexusPayload::string($attributes, 'agentAvatarUrl', 512, false);
        }

        if (array_key_exists('soulMd', $attributes)) {
            $profile->soul_md = NexusPayload::string($attributes, 'soulMd', 12000, false);
        }

        if (array_key_exists('interestTags', $attributes)) {
            $profile->interest_tags = $this->encodeList(NexusPayload::stringList($attributes, 'interestTags', 40));
        }

        if (array_key_exists('skillTags', $attributes)) {
            $profile->skill_tags = $this->encodeList(NexusPayload::stringList($attributes, 'skillTags', 40));
        }

        if (array_key_exists('helpTags', $attributes)) {
            $profile->help_tags = $this->encodeList(NexusPayload::stringList($attributes, 'helpTags', 40));
        }

        if (array_key_exists('matchPreferences', $attributes)) {
            $profile->match_preferences = NexusPayload::jsonOrNull($attributes['matchPreferences'], 'matchPreferences');
        }

        if (array_key_exists('permissions', $attributes)) {
            $permissions = $attributes['permissions'];

            if (! is_array($permissions)) {
                throw new ValidationException([
                    'permissions' => 'permissions must be an object.',
                ]);
            }

            if (array_key_exists('allowAgentPosting', $permissions)) {
                $profile->allow_agent_posting = (bool) $permissions['allowAgentPosting'];
            }

            if (array_key_exists('allowAgentReplying', $permissions)) {
                $profile->allow_agent_replying = (bool) $permissions['allowAgentReplying'];
            }

            if (array_key_exists('allowAgentMatching', $permissions)) {
                $profile->allow_agent_matching = (bool) $permissions['allowAgentMatching'];
            }

            if (array_key_exists('allowLocationMatching', $permissions)) {
                $profile->allow_location_matching = (bool) $permissions['allowLocationMatching'];
            }

            if (array_key_exists('locationVisibility', $permissions)) {
                $profile->location_visibility = NexusPayload::oneOf(
                    $permissions,
                    'locationVisibility',
                    ['off', 'coarse', 'help_only', 'event_only', 'friends_only'],
                    'off'
                );
            }
        }

        $profile->save();
        $profile->setRelation('user', $actor);

        $this->actionLogger->succeeded(
            $actor,
            'agent_profile.update',
            'agent_profile',
            (int) $actor->id,
            [
                'agentNameSet' => $profile->agent_name !== null,
                'agentAvatarUrlSet' => $profile->agent_avatar_url !== null,
                'soulMdLength' => $this->actionLogger->length($profile->soul_md),
                'interestTagCount' => count($this->decodeList($profile->interest_tags)),
                'skillTagCount' => count($this->decodeList($profile->skill_tags)),
                'helpTagCount' => count($this->decodeList($profile->help_tags)),
                'matchPreferenceKeys' => $this->actionLogger->keys($attributes['matchPreferences'] ?? null),
                'permissionKeys' => $this->actionLogger->keys($attributes['permissions'] ?? null),
            ],
            [
                'locationVisibility' => $profile->location_visibility,
                'allowAgentPosting' => (bool) $profile->allow_agent_posting,
                'allowAgentReplying' => (bool) $profile->allow_agent_replying,
                'allowAgentMatching' => (bool) $profile->allow_agent_matching,
                'allowLocationMatching' => (bool) $profile->allow_location_matching,
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $profile;
    }

    private function encodeList(array $items): ?string
    {
        if (! $items) {
            return null;
        }

        return json_encode(array_values($items), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }

    private function decodeList(?string $value): array
    {
        if (! $value) {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? array_values($decoded) : [];
    }
}
