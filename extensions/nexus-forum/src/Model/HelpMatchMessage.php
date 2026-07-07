<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class HelpMatchMessage extends AbstractModel
{
    protected $table = 'nexus_help_match_messages';

    public $timestamps = true;

    protected $dates = [
        'created_at',
        'updated_at',
    ];

    public function match()
    {
        return $this->belongsTo(HelpMatch::class, 'match_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
