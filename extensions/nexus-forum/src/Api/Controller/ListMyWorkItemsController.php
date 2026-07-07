<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Nexus\Forum\Api\Serializer\WorkItemSerializer;
use Nexus\Forum\Service\WorkItemFeed;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyWorkItemsController extends AbstractListController
{
    public $serializer = WorkItemSerializer::class;

    private WorkItemFeed $workItemFeed;

    public function __construct(WorkItemFeed $workItemFeed)
    {
        $this->workItemFeed = $workItemFeed;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        return $this->workItemFeed->forRequest($request, (int) $actor->id);
    }
}
