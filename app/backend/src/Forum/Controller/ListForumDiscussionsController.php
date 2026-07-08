<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Api\Serializer\DiscussionSerializer;
use Flarum\Discussion\Discussion;
use Flarum\Discussion\Filter\DiscussionFilterer;
use Flarum\Discussion\Search\DiscussionSearcher;
use Flarum\Http\RequestUtil;
use Flarum\Http\UrlGenerator;
use Flarum\Query\QueryCriteria;
use Illuminate\Support\Arr;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListForumDiscussionsController extends AbstractListController
{
    public $serializer = DiscussionSerializer::class;

    public $include = ['user', 'lastPostedUser', 'mostRelevantPost', 'mostRelevantPost.user'];

    public $optionalInclude = ['firstPost', 'lastPost', 'tags'];

    public $sort = ['lastPostedAt' => 'desc'];

    public $sortFields = ['lastPostedAt', 'commentCount', 'createdAt'];

    private DiscussionFilterer $filterer;

    private DiscussionSearcher $searcher;

    private UrlGenerator $url;

    public function __construct(DiscussionFilterer $filterer, DiscussionSearcher $searcher, UrlGenerator $url)
    {
        $this->filterer = $filterer;
        $this->searcher = $searcher;
        $this->url = $url;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $filters = $this->extractFilter($request);
        $q = Arr::get($request->getQueryParams(), 'q');

        if ($q && ! array_key_exists('q', $filters)) {
            $filters['q'] = $q;
        }

        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);
        $sort = $this->extractSort($request);
        $criteria = new QueryCriteria($actor, $filters, $sort, $this->sortIsDefault($request));
        $results = array_key_exists('q', $filters)
            ? $this->searcher->search($criteria, $limit, $offset)
            : $this->filterer->filter($criteria, $limit, $offset);

        $document->addPaginationLinks(
            $this->url->to('api')->route('nexus.forum.discussions.index'),
            $request->getQueryParams(),
            $offset,
            $limit,
            $results->areMoreResults() ? null : 0
        );

        Discussion::setStateUser($actor);

        $discussions = $results->getResults();
        $include = array_merge($this->extractInclude($request), ['state']);

        if (in_array('mostRelevantPost.user', $include, true)) {
            $include[] = 'mostRelevantPost.user.groups';

            if (! in_array('mostRelevantPost', $include, true)) {
                $include[] = 'mostRelevantPost';
            }
        }

        $this->loadRelations($discussions, $include, $request);

        if ($relations = array_intersect($include, ['firstPost', 'lastPost', 'mostRelevantPost'])) {
            foreach ($discussions as $discussion) {
                foreach ($relations as $relation) {
                    if ($discussion->$relation) {
                        $discussion->$relation->discussion = $discussion;
                    }
                }
            }
        }

        return $discussions;
    }
}
