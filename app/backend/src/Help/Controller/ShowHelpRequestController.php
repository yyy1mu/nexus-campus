<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractShowController;
use Flarum\Http\RequestUtil;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpRequestSerializer;
use Nexus\Forum\Model\HelpRequest;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ShowHelpRequestController extends AbstractShowController
{
    public $serializer = HelpRequestSerializer::class;

    public $include = ['discussion', 'requester'];

    public $optionalInclude = ['discussion', 'requester'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $id = (int) Arr::get($request->getQueryParams(), 'id');
        $helpRequest = HelpRequest::query()
            ->with(['discussion', 'requester'])
            ->findOrFail($id);

        if (! $helpRequest->discussion || ! $helpRequest->discussion->newQuery()->where('id', $helpRequest->discussion_id)->whereVisibleTo($actor)->exists()) {
            throw new ModelNotFoundException;
        }

        return $helpRequest;
    }
}
