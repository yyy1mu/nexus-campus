<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class DeviceSignal extends AbstractModel
{
    protected $table = 'nexus_device_signals';

    public $timestamps = false;

    protected $dates = [
        'created_at',
        'expires_at',
    ];

    protected $casts = [
        'bluetooth_seen' => 'bool',
        'shake_detected' => 'bool',
        'gyro_available' => 'bool',
        'accuracy_m' => 'int',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
