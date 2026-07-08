<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Illuminate\Support\Arr;
use Nexus\Forum\Agent\Serializer\CapabilityLabelSerializer;
use Nexus\Forum\Model\UserCapability;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListCapabilityLabelsController extends AbstractListController
{
    public $serializer = CapabilityLabelSerializer::class;

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $params = $request->getQueryParams();
        $queryText = Arr::get($params, 'filter.q')
            ?: Arr::get($params, 'filter.search')
            ?: Arr::get($params, 'inname')
            ?: Arr::get($params, 'q');
        $sort = (string) (Arr::get($params, 'sort') ?: 'popular');
        $limit = $this->extractLimit($request);
        $offset = $this->extractOffset($request);

        $query = UserCapability::query()
            ->where('is_active', true)
            ->orderBy('updated_at', 'desc');

        if ($queryText) {
            $normalized = NexusPayload::label((string) $queryText);
            $query->where(function ($query) use ($queryText, $normalized) {
                $query
                    ->where('label', 'like', '%'.$normalized.'%')
                    ->orWhere('name', 'like', '%'.(string) $queryText.'%')
                    ->orWhere('summary', 'like', '%'.(string) $queryText.'%');
            });
        }

        $capabilities = $query->limit(500)->get();
        $labels = [];

        foreach ($capabilities as $capability) {
            $label = (string) $capability->label;

            if (! isset($labels[$label])) {
                $labels[$label] = [
                    'id' => $label,
                    'label' => $label,
                    'name' => $capability->name ?: $label,
                    'helperIds' => [],
                    'helperCount' => 0,
                    'capabilityCount' => 0,
                    'sampleCapabilities' => [],
                    'createdAt' => $capability->created_at,
                    'updatedAt' => $capability->updated_at,
                ];
            }

            $labels[$label]['helperIds'][(int) $capability->user_id] = true;
            $labels[$label]['capabilityCount']++;

            if ($capability->updated_at && (! $labels[$label]['updatedAt'] || $capability->updated_at->gt($labels[$label]['updatedAt']))) {
                $labels[$label]['updatedAt'] = $capability->updated_at;
                $labels[$label]['name'] = $capability->name ?: $label;
            }

            if ($capability->created_at && (! $labels[$label]['createdAt'] || $capability->created_at->lt($labels[$label]['createdAt']))) {
                $labels[$label]['createdAt'] = $capability->created_at;
            }

            if (count($labels[$label]['sampleCapabilities']) < 3) {
                $labels[$label]['sampleCapabilities'][] = [
                    'userId' => (int) $capability->user_id,
                    'name' => $capability->name,
                    'summary' => $capability->summary,
                    'availability' => $capability->availability,
                    'serviceRadiusM' => $capability->service_radius_m === null ? null : (int) $capability->service_radius_m,
                    'updatedAt' => $capability->updated_at ? $capability->updated_at->toIso8601String() : null,
                ];
            }
        }

        $labels = array_values(array_map(function (array $label) {
            $label['helperCount'] = count($label['helperIds']);
            unset($label['helperIds']);

            return $label;
        }, $labels));

        usort($labels, function (array $a, array $b) use ($sort) {
            if ($sort === 'name') {
                return strcmp($a['label'], $b['label']);
            }

            if ($sort === 'activity') {
                $aTime = $a['updatedAt'] ? $a['updatedAt']->getTimestamp() : 0;
                $bTime = $b['updatedAt'] ? $b['updatedAt']->getTimestamp() : 0;

                return $bTime <=> $aTime;
            }

            $popular = $b['helperCount'] <=> $a['helperCount'];

            if ($popular !== 0) {
                return $popular;
            }

            return strcmp($a['label'], $b['label']);
        });

        return array_slice($labels, $offset, $limit);
    }
}
