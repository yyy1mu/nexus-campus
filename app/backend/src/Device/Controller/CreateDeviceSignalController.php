<?php

namespace Nexus\Forum\Api\Controller;

use Carbon\Carbon;
use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Device\Serializer\DeviceSignalSerializer;
use Nexus\Forum\Model\DeviceSignal;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateDeviceSignalController extends AbstractCreateController
{
    public $serializer = DeviceSignalSerializer::class;

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
        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Sending device signals requires explicit user confirmation.',
            ]);
        }

        $signal = new DeviceSignal;
        $signal->user_id = $actor->id;
        $signal->purpose = NexusPayload::oneOf($attributes, 'purpose', ['linkgo', 'help-nearby', 'presence'], 'linkgo');
        $signal->coarse_geohash = NexusPayload::string($attributes, 'coarseGeohash', 32, false);
        $accuracy = $attributes['accuracyM'] ?? null;
        $signal->accuracy_m = $accuracy === null || $accuracy === '' ? null : min(max((int) $accuracy, 0), 100000);
        $signal->bluetooth_seen = (bool) ($attributes['bluetoothSeen'] ?? false);
        $signal->shake_detected = (bool) ($attributes['shakeDetected'] ?? false);
        $signal->gyro_available = (bool) ($attributes['gyroAvailable'] ?? false);
        $signal->payload = NexusPayload::jsonOrNull($attributes['payload'] ?? null, 'payload');
        $signal->created_at = Carbon::now();
        $signal->expires_at = Carbon::now()->addMinutes(15);
        $signal->save();
        $signal->setRelation('user', $actor);

        $this->actionLogger->succeeded(
            $actor,
            'device_signal.create',
            'device_signal',
            (int) $signal->id,
            [
                'purpose' => $signal->purpose,
                'coarseGeohashSet' => $signal->coarse_geohash !== null,
                'accuracyM' => $signal->accuracy_m,
                'bluetoothSeen' => (bool) $signal->bluetooth_seen,
                'shakeDetected' => (bool) $signal->shake_detected,
                'gyroAvailable' => (bool) $signal->gyro_available,
                'payloadKeys' => $this->actionLogger->keys($attributes['payload'] ?? null),
            ],
            [
                'expiresAt' => $signal->expires_at ? $signal->expires_at->toIso8601String() : null,
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $signal;
    }
}
