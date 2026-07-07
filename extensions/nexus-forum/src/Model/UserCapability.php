<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class UserCapability extends AbstractModel
{
    protected $table = 'nexus_user_capabilities';

    public $timestamps = true;

    protected $casts = [
        'is_active' => 'bool',
        'service_radius_m' => 'int',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
