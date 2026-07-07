<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class AgentActionLog extends AbstractModel
{
    protected $table = 'nexus_agent_action_logs';

    public $timestamps = false;

    protected $dates = [
        'created_at',
    ];

    protected $casts = [
        'user_confirmed' => 'bool',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
