<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\DeviceSignalSerializer;
use Nexus\Forum\Model\DeviceSignal;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListMyDeviceSignalsController extends AbstractListController
{
    public $serializer = DeviceSignalSerializer::class;

    public $include = ['user'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $params = $request->getQueryParams();
        $purpose = Arr::get($params, 'filter.purpose') ?: Arr::get($params, 'purpose');
        $includeExpired = $this->truthy(Arr::get($params, 'filter.includeExpired') ?? Arr::get($params, 'includeExpired'));
        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);

        $query = DeviceSignal::query()
            ->where('user_id', $actor->id);

        if ($purpose) {
            $query->where('purpose', (string) $purpose);
        }

        if (! $includeExpired) {
            $query->where(function ($query) {
                $query
                    ->whereNull('expires_at')
                    ->orWhere('expires_at', '>', Carbon::now());
            });
        }

        $signals = $query
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->skip($offset)
            ->take($limit + 1)
            ->get();

        if ($signals->count() > $limit) {
            $signals = $signals->slice(0, $limit)->values();
        }

        return $signals;
    }

    private function truthy($value): bool
    {
        return in_array($value, [true, 1, '1', 'true', 'yes', 'on'], true);
    }
}
