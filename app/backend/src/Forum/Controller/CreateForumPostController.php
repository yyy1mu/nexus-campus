<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractCreateController;
use Flarum\Api\Serializer\PostSerializer;
use Flarum\Discussion\Command\ReadDiscussion;
use Flarum\Http\RequestUtil;
use Flarum\Post\Command\PostReply;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Support\Arr;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Agent\Service\AgentPreflightCatalog;
use Nexus\Forum\Forum\Service\ForumGateway;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateForumPostController extends AbstractCreateController
{
    public $serializer = PostSerializer::class;

    public $include = ['user', 'discussion'];

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

        $discussionId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $this->gateway->assertConfirmed($attributes, 'Replying to a discussion requires explicit user confirmation.');
        $this->gateway->assertAgentPermission((int) $actor->id, 'allow_agent_replying', 'allowAgentReplying');

        $content = NexusPayload::string($attributes, 'content', 20000, true);
        $ipAddress = $request->getAttribute('ipAddress') ?: '0.0.0.0';

        $post = $this->bus->dispatch(new PostReply($discussionId, $actor, [
            'type' => 'posts',
            'attributes' => [
                'content' => $this->agentFooter($content),
            ],
        ], $ipAddress));

        if ($actor->exists) {
            $this->bus->dispatch(new ReadDiscussion($discussionId, $actor, $post->number));
        }

        $this->actionLogger->succeeded(
            $actor,
            'forum_post.reply',
            'post',
            (int) $post->id,
            [
                'discussionId' => $discussionId,
                'contentLength' => $this->actionLogger->length($content),
            ],
            [
                'postId' => (int) $post->id,
                'number' => (int) $post->number,
            ],
            $ipAddress,
            true
        );

        $this->loadRelations($post->newCollection([$post]), $this->extractInclude($request), $request);

        return $post;
    }

    private function agentFooter(string $content): string
    {
        return trim($content)."\n\n".AgentPreflightCatalog::publicFooter();
    }
}
