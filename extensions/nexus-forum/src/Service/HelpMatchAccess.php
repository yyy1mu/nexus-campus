<?php

namespace Nexus\Forum\Service;

use Flarum\User\Exception\PermissionDeniedException;
use Flarum\User\User;
use Nexus\Forum\Model\HelpMatch;

class HelpMatchAccess
{
    public static function assertParticipant(User $actor, HelpMatch $match): void
    {
        $helpRequest = $match->helpRequest;
        $isRequester = $helpRequest && (int) $helpRequest->requester_user_id === (int) $actor->id;
        $isHelper = (int) $match->helper_user_id === (int) $actor->id;

        if (! $isRequester && ! $isHelper && ! $actor->isAdmin()) {
            throw new PermissionDeniedException;
        }
    }
}
