<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpRequestSerializer;
use Nexus\Forum\Model\HelpRequest;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListHelpRequestsController extends AbstractListController
{
    public $serializer = HelpRequestSerializer::class;

    public $include = ['discussion', 'requester'];

    public $optionalInclude = ['discussion', 'requester'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $params = $request->getQueryParams();
        $status = Arr::get($params, 'filter.status') ?: Arr::get($params, 'status');
        $label = Arr::get($params, 'filter.label') ?: Arr::get($params, 'label');
        $requesterUserId = Arr::get($params, 'filter.requesterUserId') ?: Arr::get($params, 'requesterUserId');
        $limit = min(max((int) Arr::get($params, 'page.limit', 20), 1), 50);
        $offset = max((int) Arr::get($params, 'page.offset', 0), 0);

        $query = HelpRequest::query()
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

        if ($requesterUserId) {
            $query->where('requester_user_id', (int) $requesterUserId);
        }

        return $query
            ->with(['discussion', 'requester'])
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get()
            ->take($limit);
    }
}
