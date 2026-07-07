<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Nexus\Forum\Api\Serializer\UserCapabilitySerializer;
use Nexus\Forum\Model\UserCapability;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ShowMyCapabilitiesController extends AbstractListController
{
    public $serializer = UserCapabilitySerializer::class;

    public $include = ['user'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        return UserCapability::query()
            ->where('user_id', $actor->id)
            ->with('user')
            ->orderBy('label')
            ->get();
    }
}
