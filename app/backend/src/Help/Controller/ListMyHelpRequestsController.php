<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpRequestSerializer;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyHelpRequestsController extends AbstractListController
{
    public $serializer = HelpRequestSerializer::class;

    public $include = ['discussion', 'requester'];

    public $optionalInclude = ['discussion', 'requester', 'matches', 'matches.helper', 'dispatches', 'dispatches.helper'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $params = $request->getQueryParams();
        $status = Arr::get($params, 'filter.status') ?: Arr::get($params, 'status');
        $label = Arr::get($params, 'filter.label') ?: Arr::get($params, 'label');
        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);

        $query = HelpRequest::query()
            ->where('requester_user_id', $actor->id)
            ->whereHas('discussion', function ($query) use ($actor) {
                $query->whereVisibleTo($actor);
            });

        if ($status) {
            $query->where('status', (string) $status);
        }

        if ($label) {
            $label = NexusPayload::label((string) $label);
            $query->where(function ($query) use ($label) {
                $query->where('category_label', $label)
                    ->orWhere('needed_labels', 'like', '%"'.$label.'"%');
            });
        }

        $helpRequests = $query
            ->orderBy('updated_at', 'desc')
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get();

        if ($helpRequests->count() > $limit) {
            $helpRequests = $helpRequests->slice(0, $limit)->values();
        }

        $this->loadRelations($helpRequests, $this->extractInclude($request), $request);

        return $helpRequests;
    }
}
