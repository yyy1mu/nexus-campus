<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpMatchMessageSerializer;
use Nexus\Forum\Model\HelpMatch;
use Nexus\Forum\Model\HelpMatchMessage;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Shared\Authorization\AgentAuthorization;
use Nexus\Forum\Help\Access\HelpMatchAccess;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateHelpMatchMessageController extends AbstractCreateController
{
    public $serializer = HelpMatchMessageSerializer::class;

    public $include = ['user', 'match'];

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    public function __construct(AgentActionLogger $actionLogger, AgentAuthorization $authorization)
    {
        $this->actionLogger = $actionLogger;
        $this->authorization = $authorization;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $matchId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $match = HelpMatch::query()->with('helpRequest')->findOrFail($matchId);
        HelpMatchAccess::assertParticipant($actor, $match);

        if ($match->status !== 'accepted') {
            throw new ValidationException([
                'status' => 'Match coordination messages can only be sent after the match is accepted.',
            ]);
        }

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Sending a match message requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'send Nexus match coordination messages');

        $message = new HelpMatchMessage;
        $message->match_id = $match->id;
        $message->user_id = $actor->id;
        $message->content = NexusPayload::string($attributes, 'content', 4000, true);
        $message->agent_context = NexusPayload::jsonOrNull($attributes['agentContext'] ?? null, 'agentContext');
        $message->save();
        $message->setRelation('user', $actor);
        $message->setRelation('match', $match);

        $this->actionLogger->succeeded(
            $actor,
            'match_message.create',
            'help_match_message',
            (int) $message->id,
            [
                'matchId' => (int) $match->id,
                'helpRequestId' => $match->help_request_id === null ? null : (int) $match->help_request_id,
                'contentLength' => $this->actionLogger->length($message->content),
                'agentContextKeys' => $this->actionLogger->keys($attributes['agentContext'] ?? null),
            ],
            [
                'matchStatus' => $match->status,
            ],
            (string) $request->getAttribute('ipAddress'),
            true
        );

        return $message;
    }
}
