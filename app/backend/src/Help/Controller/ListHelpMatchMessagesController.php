<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractListController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpMatchMessageSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpMatchMessage;
use Nexus\Forum\Help\Access\HelpMatchAccess;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class ListHelpMatchMessagesController extends AbstractListController
{
    public $serializer = HelpMatchMessageSerializer::class;

    public $include = ['user'];

    public $optionalInclude = ['user', 'match'];

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $matchId = (int) Arr::get($request->getQueryParams(), 'id');
        $match = HelpMatch::query()->with('helpRequest')->findOrFail($matchId);
        HelpMatchAccess::assertParticipant($actor, $match);

        return HelpMatchMessage::query()
            ->where('match_id', $match->id)
            ->with(['user', 'match'])
            ->orderBy('created_at')
            ->get();
    }
}
