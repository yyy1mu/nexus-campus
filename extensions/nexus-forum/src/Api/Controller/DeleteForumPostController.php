<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractDeleteController;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\Post\Command\EditPost;
use Flarum\Post\PostRepository;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Support\Arr;
use Nexus\Forum\Service\AgentActionLogger;
use Nexus\Forum\Service\ForumGateway;
use Nexus\Forum\Service\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;

class DeleteForumPostController extends AbstractDeleteController
{
    private Dispatcher $bus;

    private ForumGateway $gateway;

    private AgentActionLogger $actionLogger;

    private PostRepository $posts;

    public function __construct(Dispatcher $bus, ForumGateway $gateway, AgentActionLogger $actionLogger, PostRepository $posts)
    {
        $this->bus = $bus;
        $this->gateway = $gateway;
        $this->actionLogger = $actionLogger;
        $this->posts = $posts;
    }

    protected function delete(ServerRequestInterface $request)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $postId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $this->gateway->assertConfirmed($attributes, 'Deleting a post requires explicit user confirmation.');
        $this->gateway->assertAgentPermission((int) $actor->id, 'allow_agent_replying', 'allowAgentReplying');

        $reason = NexusPayload::string($attributes, 'reason', 500, false);
        $post = $this->posts->findOrFail($postId, $actor);

        if ((int) $post->user_id !== (int) $actor->id) {
            throw new ValidationException(['postId' => 'Agents may only delete their own posts through this endpoint.']);
        }

        $discussionId = (int) $post->discussion_id;
        $postNumber = (int) $post->number;

        $this->bus->dispatch(new EditPost($postId, $actor, [
            'type' => 'posts',
            'attributes' => [
                'isHidden' => true,
                'reason' => $reason,
            ],
        ]));

        $this->actionLogger->succeeded(
            $actor,
            'forum_post.delete',
            'post',
            $postId,
            [
                'postId' => $postId,
                'discussionId' => $discussionId,
                'reasonLength' => $this->actionLogger->length($reason),
            ],
            [
                'deleted' => false,
                'hidden' => true,
                'number' => $postNumber,
            ],
            $request->getAttribute('ipAddress') ?: null,
            true
        );
    }
}
