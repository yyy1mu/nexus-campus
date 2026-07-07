<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Api\Serializer\UserCapabilitySerializer;
use Nexus\Forum\Model\UserCapability;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateMyCapabilitiesController extends AbstractListController
{
    public $serializer = UserCapabilitySerializer::class;

    public $include = ['user'];

    private AgentActionLogger $actionLogger;

    public function __construct(AgentActionLogger $actionLogger)
    {
        $this->actionLogger = $actionLogger;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $items = Arr::get($attributes, 'capabilities', []);

        if (! is_array($items)) {
            throw new ValidationException([
                'capabilities' => 'capabilities must be an array.',
            ]);
        }

        if (! Arr::has($request->getParsedBody(), 'data.attributes.capabilities')) {
            throw new ValidationException([
                'capabilities' => 'Request body must include data.attributes.capabilities and data.attributes.userConfirmed.',
            ]);
        }

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Updating public capability labels requires explicit user confirmation.',
            ]);
        }

        if (count($items) > 30) {
            throw new ValidationException([
                'capabilities' => 'Too many capabilities.',
            ]);
        }

        $seen = [];

        foreach ($items as $item) {
            if (! is_array($item)) {
                continue;
            }

            $label = NexusPayload::label((string) ($item['label'] ?? $item['name'] ?? ''));
            if ($label === '') {
                continue;
            }

            $seen[] = $label;
            $capability = UserCapability::query()
                ->where('user_id', $actor->id)
                ->where('label', $label)
                ->first();

            if (! $capability) {
                $capability = new UserCapability;
                $capability->user_id = $actor->id;
                $capability->label = $label;
            }

            $capability->name = NexusPayload::string($item, 'name', 120, false) ?: $label;
            $capability->summary = NexusPayload::string($item, 'summary', 1000, false);
            $capability->availability = NexusPayload::string($item, 'availability', 80, false);
            $radius = $item['serviceRadiusM'] ?? null;
            $capability->service_radius_m = $radius === null || $radius === '' ? null : min(max((int) $radius, 0), 100000);
            $capability->is_active = array_key_exists('isActive', $item) ? (bool) $item['isActive'] : true;
            $capability->save();
        }

        UserCapability::query()
            ->where('user_id', $actor->id)
            ->when($seen, function ($query) use ($seen) {
                $query->whereNotIn('label', $seen);
            })
            ->update(['is_active' => false]);

        $capabilities = UserCapability::query()
            ->where('user_id', $actor->id)
            ->with('user')
            ->orderBy('label')
            ->get();

        $this->actionLogger->succeeded(
            $actor,
            'capabilities.update',
            'user_capabilities',
            (int) $actor->id,
            [
                'submittedCount' => count($items),
                'labels' => array_values(array_unique($seen)),
            ],
            [
                'returnedCount' => $capabilities->count(),
                'activeCount' => $capabilities->where('is_active', true)->count(),
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $capabilities;
    }
}
