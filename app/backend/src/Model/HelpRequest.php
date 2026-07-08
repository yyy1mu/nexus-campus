<?php

namespace Nexus\Forum\Model;

use Flarum\Database\AbstractModel;
use Flarum\Discussion\Discussion;
use Flarum\User\User;

class HelpRequest extends AbstractModel
{
    protected $table = 'nexus_help_requests';

    public $timestamps = true;

    protected $dates = [
        'created_at',
        'updated_at',
        'closed_at',
    ];

    public function discussion()
    {
        return $this->belongsTo(Discussion::class, 'discussion_id');
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_user_id');
    }

    public function matches()
    {
        return $this->hasMany(HelpMatch::class, 'help_request_id');
    }

    public function dispatches()
    {
        return $this->hasMany(HelpDispatch::class, 'help_request_id');
    }
}
