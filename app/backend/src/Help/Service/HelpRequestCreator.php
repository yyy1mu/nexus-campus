<?php

namespace Nexus\Forum\Service;

use Flarum\Discussion\Command\ReadDiscussion;
use Flarum\Discussion\Command\StartDiscussion;
use Flarum\Foundation\ValidationException;
use Flarum\Settings\SettingsRepositoryInterface;
use Flarum\Tags\Tag;
use Flarum\User\User;
use Illuminate\Contracts\Bus\Dispatcher;
use Nexus\Forum\Model\HelpRequest;

class HelpRequestCreator
{
    private Dispatcher $bus;

    private SettingsRepositoryInterface $settings;

    private AgentActionLogger $actionLogger;

    private AgentAuthorization $authorization;

    public function __construct(
        Dispatcher $bus,
        SettingsRepositoryInterface $settings,
        AgentActionLogger $actionLogger,
        AgentAuthorization $authorization
    )
    {
        $this->bus = $bus;
        $this->settings = $settings;
        $this->actionLogger = $actionLogger;
        $this->authorization = $authorization;
    }

    public function create(User $actor, array $attributes, string $ipAddress): HelpRequest
    {
        $actor->assertRegistered();

        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => 'Creating a public help request requires explicit user confirmation.',
            ]);
        }

        $this->authorization->assertMatchingAllowed((int) $actor->id, 'create Nexus help requests');

        $title = NexusPayload::string($attributes, 'title', 120, true);
        $summary = NexusPayload::string($attributes, 'summary', 2000, true);
        $content = NexusPayload::string($attributes, 'content', 20000, false) ?: $summary;
        $categoryLabel = NexusPayload::label((string) ($attributes['categoryLabel'] ?? 'help'));
        $neededLabels = NexusPayload::stringList($attributes, 'neededLabels', 12);
        $urgency = NexusPayload::oneOf($attributes, 'urgency', ['low', 'normal', 'soon', 'urgent'], 'normal');
        $locationHint = NexusPayload::string($attributes, 'locationHint', 255, false);
        $meetingSafetyState = NexusPayload::oneOf(
            $attributes,
            'meetingSafetyState',
            ['not_arranged', 'public_place_suggested', 'public_place_confirmed'],
            'not_arranged'
        );
        $agentContext = NexusPayload::jsonOrNull($attributes['agentContext'] ?? null, 'agentContext');
        $tagId = $this->helpTagId();

        $discussionData = [
            'type' => 'discussions',
            'attributes' => [
                'title' => $title,
                'content' => $this->composeContent($content, $neededLabels, $locationHint, $urgency),
            ],
            'relationships' => [
                'tags' => [
                    'data' => [
                        ['type' => 'tags', 'id' => (string) $tagId],
                    ],
                ],
            ],
        ];

        $discussion = $this->bus->dispatch(new StartDiscussion($actor, $discussionData, $ipAddress));

        if ($actor->exists) {
            $this->bus->dispatch(new ReadDiscussion($discussion->id, $actor, 1));
        }

        $helpRequest = new HelpRequest;
        $helpRequest->discussion_id = $discussion->id;
        $helpRequest->requester_user_id = $actor->id;
        $helpRequest->status = 'open';
        $helpRequest->category_label = $categoryLabel ?: 'help';
        $helpRequest->needed_labels = json_encode($neededLabels, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $helpRequest->summary = $summary;
        $helpRequest->urgency = $urgency;
        $helpRequest->location_hint = $locationHint;
        $helpRequest->meeting_safety_state = $meetingSafetyState;
        $helpRequest->agent_context = $agentContext;
        $helpRequest->save();

        $helpRequest->setRelation('discussion', $discussion);
        $helpRequest->setRelation('requester', $actor);

        $this->actionLogger->succeeded(
            $actor,
            'help_request.create',
            'help_request',
            (int) $helpRequest->id,
            [
                'title' => $title,
                'summaryLength' => $this->actionLogger->length($summary),
                'contentLength' => $this->actionLogger->length($content),
                'categoryLabel' => $helpRequest->category_label,
                'neededLabels' => $neededLabels,
                'urgency' => $urgency,
                'locationHintSet' => $locationHint !== null,
                'meetingSafetyState' => $meetingSafetyState,
                'agentContextKeys' => $this->actionLogger->keys($attributes['agentContext'] ?? null),
            ],
            [
                'discussionId' => (int) $discussion->id,
                'status' => $helpRequest->status,
            ],
            $ipAddress,
            true
        );

        return $helpRequest;
    }

    private function helpTagId(): int
    {
        $configured = (int) $this->settings->get('nexus-forum.help_tag_id', 0);

        if ($configured > 0) {
            return $configured;
        }

        $tag = Tag::where('slug', 'help')->first();

        if (! $tag) {
            throw new ValidationException([
                'tag' => 'The help tag is not configured.',
            ]);
        }

        return (int) $tag->id;
    }

    private function composeContent(string $content, array $neededLabels, ?string $locationHint, string $urgency): string
    {
        $lines = [trim($content)];

        $meta = [];

        if ($neededLabels) {
            $meta[] = 'Capability labels: #'.implode(' #', $neededLabels);
        }

        if ($locationHint) {
            $meta[] = 'Location hint: '.$locationHint;
        }

        if ($urgency !== 'normal') {
            $meta[] = 'Urgency: '.$urgency;
        }

        if ($meta) {
            $lines[] = '';
            $lines[] = implode("\n", $meta);
        }

        $lines[] = '';
        $lines[] = AgentPreflightCatalog::helpFooter();

        return implode("\n", $lines);
    }
}
