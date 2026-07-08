<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpDispatchSerializer;
use Nexus\Forum\Model\HelpDispatch;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyHelpDispatchesController extends AbstractListController
{
    public $serializer = HelpDispatchSerializer::class;

    public $include = ['requester', 'helpRequest', 'helpRequest.discussion'];

    public $optionalInclude = ['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $status = Arr::get($request->getQueryParams(), 'filter.status');
        $limit = min(max((int) Arr::get($request->getQueryParams(), 'page.limit', 20), 1), 50);
        $query = HelpDispatch::query()
            ->where('helper_user_id', $actor->id)
            ->with(['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match']);

        if ($status) {
            $query->where('status', (string) $status);
        }

        return $query
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get();
    }
}
