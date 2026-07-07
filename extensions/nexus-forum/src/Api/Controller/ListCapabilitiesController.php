<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\UserCapabilitySerializer;
use Nexus\Forum\Model\UserCapability;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListCapabilitiesController extends AbstractListController
{
    public $serializer = UserCapabilitySerializer::class;

    public $include = ['user'];

    public $optionalInclude = ['user'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $query = UserCapability::query()->where('is_active', true);
        $params = $request->getQueryParams();
        $label = Arr::get($params, 'filter.label') ?: Arr::get($params, 'label');
        $userId = Arr::get($params, 'filter.userId') ?: Arr::get($params, 'userId');
        $limit = min(max((int) Arr::get($params, 'page.limit', 20), 1), 50);
        $offset = max((int) Arr::get($params, 'page.offset', 0), 0);

        if ($label) {
            $query->where('label', NexusPayload::label((string) $label));
        }

        if ($userId) {
            $query->where('user_id', (int) $userId);
        }

        $capabilities = $query
            ->with('user')
            ->orderBy('updated_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get();

        return $capabilities->take($limit);
    }
}
