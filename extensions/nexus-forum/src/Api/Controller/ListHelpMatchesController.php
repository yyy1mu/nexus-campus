<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Flarum\User\Exception\PermissionDeniedException;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpMatchSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpRequest;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListHelpMatchesController extends AbstractListController
{
    public $serializer = HelpMatchSerializer::class;

    public $include = ['helper'];

    public $optionalInclude = ['helper', 'helpRequest', 'helpRequest.discussion'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();
        $helpRequestId = (int) Arr::get($request->getQueryParams(), 'id');
        $helpRequest = HelpRequest::query()->findOrFail($helpRequestId);

        if ((int) $helpRequest->requester_user_id !== (int) $actor->id && ! $actor->isAdmin()) {
            $query = HelpMatch::query()->where('helper_user_id', $actor->id);
        } else {
            $query = HelpMatch::query();
        }

        return $query
            ->where('help_request_id', $helpRequestId)
            ->with(['helper', 'helpRequest', 'helpRequest.discussion'])
            ->orderBy('created_at', 'desc')
            ->get();
    }
}
