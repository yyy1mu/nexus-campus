<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class HelpMatch extends AbstractModel
{
    protected $table = 'nexus_help_matches';

    public $timestamps = true;

    protected $dates = [
        'created_at',
        'updated_at',
        'accepted_at',
        'completed_at',
    ];

    public function helpRequest()
    {
        return $this->belongsTo(HelpRequest::class, 'help_request_id');
    }

    public function helper()
    {
        return $this->belongsTo(User::class, 'helper_user_id');
    }

    public function messages()
    {
        return $this->hasMany(HelpMatchMessage::class, 'match_id');
    }
}
