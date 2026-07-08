<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractShowController;
use Flarum\Api\Serializer\PostSerializer;
use Flarum\Foundation\ValidationException;
use Flarum\Http\RequestUtil;
use Flarum\Post\Command\EditPost;
use Flarum\Post\PostRepository;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Support\Arr;
use Nexus\Forum\Shared\Logging\AgentActionLogger;
use Nexus\Forum\Forum\Service\ForumGateway;
use Nexus\Forum\Shared\Validation\NexusPayload;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class UpdateForumPostController extends AbstractShowController
{
    public $serializer = PostSerializer::class;

    public $include = ['user', 'discussion', 'editedUser'];

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

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $postId = (int) Arr::get($request->getQueryParams(), 'id');
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $this->gateway->assertConfirmed($attributes, 'Editing a post requires explicit user confirmation.');
        $this->gateway->assertAgentPermission((int) $actor->id, 'allow_agent_replying', 'allowAgentReplying');

        $postBefore = $this->posts->findOrFail($postId, $actor);

        if ((int) $postBefore->user_id !== (int) $actor->id) {
            throw new ValidationException(['postId' => 'Agents may only edit their own posts through this endpoint.']);
        }

        $content = NexusPayload::string($attributes, 'content', 20000, true);

        $post = $this->bus->dispatch(new EditPost($postId, $actor, [
            'type' => 'posts',
            'attributes' => [
                'content' => $this->agentFooter($content),
            ],
        ]));

        $this->actionLogger->succeeded(
            $actor,
            'forum_post.edit',
            'post',
            (int) $post->id,
            [
                'postId' => $postId,
                'contentLength' => $this->actionLogger->length($content),
            ],
            [
                'postId' => (int) $post->id,
                'discussionId' => (int) $post->discussion_id,
            ],
            $request->getAttribute('ipAddress') ?: null,
            true
        );

        $this->loadRelations($post->newCollection([$post]), $this->extractInclude($request), $request);

        return $post;
    }

    private function agentFooter(string $content): string
    {
        return trim($content)."\n\n".'Edited by Nexus Agent after explicit user confirmation.';
    }
}
