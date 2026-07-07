<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;

class UserLlmSettings extends AbstractModel
{
    protected $table = 'nexus_user_llm_settings';

    protected $primaryKey = 'user_id';

    public $incrementing = false;

    public $timestamps = true;

    protected $casts = [
        'supports_chat_completions' => 'bool',
        'supports_responses' => 'bool',
    ];
}
