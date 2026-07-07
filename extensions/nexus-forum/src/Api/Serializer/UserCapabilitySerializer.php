<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\UserCapability;

class UserCapabilitySerializer extends AbstractSerializer
{
    protected $type = 'nexus-user-capabilities';

    protected function getDefaultAttributes($capability): array
    {
        /** @var UserCapability $capability */
        return [
            'userId' => (int) $capability->user_id,
            'label' => $capability->label,
            'name' => $capability->name,
            'summary' => $capability->summary,
            'availability' => $capability->availability,
            'serviceRadiusM' => $capability->service_radius_m === null ? null : (int) $capability->service_radius_m,
            'isActive' => (bool) $capability->is_active,
            'createdAt' => $this->formatDate($capability->created_at),
            'updatedAt' => $this->formatDate($capability->updated_at),
        ];
    }

    protected function user($capability)
    {
        return $this->hasOne($capability, BasicUserSerializer::class);
    }
}
