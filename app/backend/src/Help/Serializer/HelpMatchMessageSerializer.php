<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;
use Flarum\Api\Serializer\BasicUserSerializer;
use Nexus\Forum\Model\HelpMatchMessage;

class HelpMatchMessageSerializer extends AbstractSerializer
{
    protected $type = 'nexus-help-match-messages';

    protected function getDefaultAttributes($message): array
    {
        /** @var HelpMatchMessage $message */
        return [
            'matchId' => (int) $message->match_id,
            'userId' => (int) $message->user_id,
            'content' => $message->content,
            'agentContext' => $message->agent_context ? json_decode($message->agent_context, true) : null,
            'createdAt' => $this->formatDate($message->created_at),
            'updatedAt' => $this->formatDate($message->updated_at),
        ];
    }

    protected function user($message)
    {
        return $this->hasOne($message, BasicUserSerializer::class);
    }

    protected function match($message)
    {
        return $this->hasOne($message, HelpMatchSerializer::class);
    }
}
