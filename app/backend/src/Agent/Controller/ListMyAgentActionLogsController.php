<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Agent\Serializer\AgentActionLogSerializer;
use Nexus\Forum\Model\AgentActionLog;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyAgentActionLogsController extends AbstractListController
{
    public $serializer = AgentActionLogSerializer::class;

    public $optionalInclude = ['user'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $params = $request->getQueryParams();
        $actionType = Arr::get($params, 'filter.actionType') ?: Arr::get($params, 'actionType');
        $targetType = Arr::get($params, 'filter.targetType') ?: Arr::get($params, 'targetType');
        $limit = min(max((int) Arr::get($params, 'page.limit', 20), 1), 50);
        $offset = max((int) Arr::get($params, 'page.offset', 0), 0);

        $query = AgentActionLog::query()
            ->where('user_id', $actor->id);

        if ($actionType) {
            $query->where('action_type', (string) $actionType);
        }

        if ($targetType) {
            $query->where('target_type', (string) $targetType);
        }

        return $query
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get()
            ->take($limit);
    }
}
