<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpDispatchSerializer;
use Nexus\Forum\Model\HelpDispatch;
use Nexus\Forum\Model\HelpRequest;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListHelpDispatchesController extends AbstractListController
{
    public $serializer = HelpDispatchSerializer::class;

    public $include = ['helper'];

    public $optionalInclude = ['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $helpRequestId = (int) Arr::get($request->getQueryParams(), 'id');
        $helpRequest = HelpRequest::query()->findOrFail($helpRequestId);
        $query = HelpDispatch::query()->where('help_request_id', $helpRequest->id);

        if ((int) $helpRequest->requester_user_id !== (int) $actor->id && ! $actor->isAdmin()) {
            $query->where('helper_user_id', $actor->id);
        }

        return $query
            ->with(['helper', 'requester', 'helpRequest', 'helpRequest.discussion', 'match'])
            ->orderBy('created_at', 'desc')
            ->get();
    }
}
