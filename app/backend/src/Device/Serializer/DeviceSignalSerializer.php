<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\DeviceSignal;

class DeviceSignalSerializer extends AbstractSerializer
{
    protected $type = 'nexus-device-signals';

    protected function getDefaultAttributes($signal): array
    {
        /** @var DeviceSignal $signal */
        return [
            'userId' => (int) $signal->user_id,
            'purpose' => $signal->purpose,
            'coarseGeohash' => $signal->coarse_geohash,
            'accuracyM' => $signal->accuracy_m === null ? null : (int) $signal->accuracy_m,
            'bluetoothSeen' => (bool) $signal->bluetooth_seen,
            'shakeDetected' => (bool) $signal->shake_detected,
            'gyroAvailable' => (bool) $signal->gyro_available,
            'payload' => $signal->payload ? json_decode($signal->payload, true) : null,
            'createdAt' => $this->formatDate($signal->created_at),
            'expiresAt' => $this->formatDate($signal->expires_at),
        ];
    }

    protected function user($signal)
    {
        return $this->hasOne($signal, BasicUserSerializer::class);
    }
}
