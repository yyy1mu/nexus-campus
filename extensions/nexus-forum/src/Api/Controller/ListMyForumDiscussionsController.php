<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Api\Serializer\DiscussionSerializer;
use Flarum\Discussion\Discussion;
use Flarum\Http\RequestUtil;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyForumDiscussionsController extends AbstractListController
{
    public $serializer = DiscussionSerializer::class;

    public $include = ['user', 'lastPostedUser'];

    public $optionalInclude = ['firstPost', 'lastPost', 'tags'];

    public $sortFields = ['lastPostedAt', 'commentCount', 'createdAt'];

    public $sort = ['createdAt' => 'desc'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);

        $query = Discussion::query()
            ->whereVisibleTo($actor)
            ->where('user_id', $actor->id)
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1);

        $discussions = $query->get();

        if ($discussions->count() > $limit) {
            $discussions = $discussions->slice(0, $limit)->values();
        }

        $this->loadRelations($discussions, $this->extractInclude($request), $request);

        return $discussions;
    }
}
