<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;

class NeedDraftSerializer extends AbstractSerializer
{
    protected $type = 'nexus-need-drafts';

    public function getId($draft)
    {
        return (string) $draft['id'];
    }

    protected function getDefaultAttributes($draft): array
    {
        $attributes = $draft;
        unset($attributes['id']);

        return $attributes;
    }
}
