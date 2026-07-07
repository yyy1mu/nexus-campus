<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractShowController;
use Flarum\Http\RequestUtil;
use Nexus\Forum\Api\Serializer\AgentProfileSerializer;
use Nexus\Forum\Model\AgentProfile;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ShowMyAgentProfileController extends AbstractShowController
{
    public $serializer = AgentProfileSerializer::class;

    public $include = ['user'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        return $this->profileForUser((int) $actor->id)->setRelation('user', $actor);
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
}
