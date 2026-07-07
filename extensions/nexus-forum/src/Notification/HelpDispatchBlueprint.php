<?php

namespace Nexus\Forum\Notification;

use Flarum\Notification\Blueprint\BlueprintInterface;
use Nexus\Forum\Model\HelpDispatch;

class HelpDispatchBlueprint implements BlueprintInterface
{
    private HelpDispatch $dispatch;

    public function __construct(HelpDispatch $dispatch)
    {
        $this->dispatch = $dispatch;
    }

    public function getSubject()
    {
        return $this->dispatch;
    }

    public function getFromUser()
    {
        return $this->dispatch->requester;
    }

    public function getData()
    {
        $helpRequest = $this->dispatch->helpRequest;

        return [
            'dispatchId' => (int) $this->dispatch->id,
            'helpRequestId' => (int) $this->dispatch->help_request_id,
            'discussionId' => $helpRequest ? (int) $helpRequest->discussion_id : null,
        ];
    }

    public static function getType()
    {
        return 'nexusHelpDispatch';
    }

    public static function getSubjectModel()
    {
        return HelpDispatch::class;
    }
}
