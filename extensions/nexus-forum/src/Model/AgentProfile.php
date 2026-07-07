<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class AgentProfile extends AbstractModel
{
    protected $table = 'nexus_agent_profiles';

    protected $primaryKey = 'user_id';

    public $incrementing = false;

    public $timestamps = true;

    protected $casts = [
        'user_id' => 'int',
        'allow_agent_posting' => 'bool',
        'allow_agent_replying' => 'bool',
        'allow_agent_matching' => 'bool',
        'allow_location_matching' => 'bool',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
