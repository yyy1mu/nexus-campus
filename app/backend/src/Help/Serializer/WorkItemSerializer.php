<?php

namespace Nexus\Forum\Api\Serializer;

use Flarum\Api\Serializer\AbstractSerializer;

class WorkItemSerializer extends AbstractSerializer
{
    protected $type = 'nexus-work-items';

    public function getId($item)
    {
        return (string) $item['id'];
    }

    protected function getDefaultAttributes($item): array
    {
        return [
            'kind' => $item['kind'],
            'role' => $item['role'],
            'action' => $item['action'],
            'status' => $item['status'],
            'priority' => (int) $item['priority'],
            'title' => $item['title'],
            'summary' => $item['summary'],
            'helpRequestId' => $item['helpRequestId'],
            'dispatchId' => $item['dispatchId'],
            'matchId' => $item['matchId'],
            'discussionId' => $item['discussionId'],
            'discussionUrl' => $item['discussionUrl'],
            'requesterUserId' => $item['requesterUserId'],
            'helperUserId' => $item['helperUserId'],
            'neededLabels' => $item['neededLabels'],
            'meetingSafetyState' => $item['meetingSafetyState'],
            'nextActions' => $item['nextActions'],
            'createdAt' => $this->formatDate($item['createdAt']),
            'updatedAt' => $this->formatDate($item['updatedAt']),
        ];
    }
}
