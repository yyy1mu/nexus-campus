<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Api\Serializer\DiscussionSerializer;
use Flarum\Discussion\Command\ReadDiscussion;
use Flarum\Discussion\Command\StartDiscussion;
use Flarum\Http\RequestUtil;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Support\Arr;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Agent\Service\AgentPreflightCatalog;
use Nexus\Forum\Forum\Service\ForumGateway;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateForumDiscussionController extends AbstractCreateController
{
    public $serializer = DiscussionSerializer::class;

    public $include = ['user', 'firstPost', 'lastPost'];

    public $optionalInclude = ['tags'];

    private Dispatcher $bus;

    private ForumGateway $gateway;

    private AgentActionLogger $actionLogger;

    public function __construct(Dispatcher $bus, ForumGateway $gateway, AgentActionLogger $actionLogger)
    {
        $this->bus = $bus;
        $this->gateway = $gateway;
        $this->actionLogger = $actionLogger;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $this->gateway->assertConfirmed($attributes, 'Creating a public discussion requires explicit user confirmation.');
        $this->gateway->assertAgentPermission((int) $actor->id, 'allow_agent_posting', 'allowAgentPosting');

        $title = NexusPayload::string($attributes, 'title', 120, true);
        $content = NexusPayload::string($attributes, 'content', 20000, true);
        $ipAddress = $request->getAttribute('ipAddress') ?: '0.0.0.0';

        $discussionData = [
            'type' => 'discussions',
            'attributes' => [
                'title' => $title,
                'content' => $this->agentFooter($content),
            ],
            'relationships' => $this->gateway->tagRelationshipFromAttributes($attributes),
        ];

        $discussion = $this->bus->dispatch(new StartDiscussion($actor, $discussionData, $ipAddress));

        if ($actor->exists) {
            $this->bus->dispatch(new ReadDiscussion($discussion->id, $actor, 1));
        }

        $this->actionLogger->succeeded(
            $actor,
            'forum_discussion.create',
            'discussion',
            (int) $discussion->id,
            [
                'title' => $title,
                'contentLength' => $this->actionLogger->length($content),
                'tagIds' => $this->gateway->tagIdsFromAttributes($attributes),
            ],
            [
                'discussionId' => (int) $discussion->id,
                'firstPostId' => $discussion->first_post_id === null ? null : (int) $discussion->first_post_id,
            ],
            $ipAddress,
            true
        );

        $this->loadRelations($discussion->newCollection([$discussion]), $this->extractInclude($request), $request);

        return $discussion;
    }

    private function agentFooter(string $content): string
    {
        return trim($content)."\n\n".AgentPreflightCatalog::publicFooter();
    }
}
