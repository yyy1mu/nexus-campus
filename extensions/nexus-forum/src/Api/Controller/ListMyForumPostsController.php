<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Api\Serializer\PostSerializer;
use Flarum\Http\RequestUtil;
use Flarum\Post\PostRepository;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyForumPostsController extends AbstractListController
{
    public $serializer = PostSerializer::class;

    public $include = ['user', 'discussion'];

    public $optionalInclude = ['editedUser', 'hiddenUser', 'discussion.tags'];

    public $sortFields = ['number', 'createdAt'];

    public $sort = ['createdAt' => 'desc'];

    private PostRepository $posts;

    public function __construct(PostRepository $posts)
    {
        $this->posts = $posts;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);

        $query = $this->posts->queryVisibleTo($actor)
            ->where('posts.user_id', $actor->id)
            ->orderBy('posts.created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1);

        $posts = $query->get();

        if ($posts->count() > $limit) {
            $posts = $posts->slice(0, $limit)->values();
        }

        $this->loadRelations($posts, $this->extractInclude($request), $request);

        return $posts;
    }
}
