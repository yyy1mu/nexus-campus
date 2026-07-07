<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\HelpMatchSerializer;
use Nexus\Forum\Model\HelpMatch;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyHelpMatchesController extends AbstractListController
{
    public $serializer = HelpMatchSerializer::class;

    public $include = ['helper', 'helpRequest', 'helpRequest.discussion', 'helpRequest.requester'];

    public $optionalInclude = ['helper', 'helpRequest', 'helpRequest.discussion', 'helpRequest.requester', 'messages'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $params = $request->getQueryParams();
        $status = Arr::get($params, 'filter.status') ?: Arr::get($params, 'status');
        $role = Arr::get($params, 'filter.role') ?: Arr::get($params, 'role');
        $limit = min(max((int) Arr::get($params, 'page.limit', 20), 1), 50);
        $offset = max((int) Arr::get($params, 'page.offset', 0), 0);

        if ($role && ! in_array($role, ['requester', 'helper'], true)) {
            throw new ValidationException([
                'role' => 'role must be requester or helper.',
            ]);
        }

        $query = HelpMatch::query()
            ->with(['helper', 'helpRequest', 'helpRequest.discussion', 'helpRequest.requester']);

        if ($role === 'helper') {
            $query->where('helper_user_id', $actor->id);
        } elseif ($role === 'requester') {
            $query->whereHas('helpRequest', function ($query) use ($actor) {
                $query->where('requester_user_id', $actor->id);
            });
        } else {
            $query->where(function ($query) use ($actor) {
                $query
                    ->where('helper_user_id', $actor->id)
                    ->orWhereHas('helpRequest', function ($query) use ($actor) {
                        $query->where('requester_user_id', $actor->id);
                    });
            });
        }

        if ($status) {
            $query->where('status', (string) $status);
        }

        return $query
            ->orderBy('updated_at', 'desc')
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get()
            ->take($limit);
    }
}
