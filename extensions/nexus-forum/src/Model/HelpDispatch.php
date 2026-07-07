<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\User\User;

class HelpDispatch extends AbstractModel
{
    protected $table = 'nexus_help_dispatches';

    public $timestamps = true;

    protected $dates = [
        'created_at',
        'updated_at',
        'expires_at',
        'responded_at',
    ];

    public function helpRequest()
    {
        return $this->belongsTo(HelpRequest::class, 'help_request_id');
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_user_id');
    }

    public function helper()
    {
        return $this->belongsTo(User::class, 'helper_user_id');
    }

    public function match()
    {
        return $this->belongsTo(HelpMatch::class, 'match_id');
    }
}
