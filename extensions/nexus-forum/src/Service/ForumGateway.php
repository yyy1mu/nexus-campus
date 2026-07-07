<?php

namespace Nexus\Forum\Service;

use Flarum\Foundation\ValidationException;
use Flarum\Tags\Tag;

class ForumGateway
{
    private AgentAuthorization $authorization;

    public function __construct(AgentAuthorization $authorization)
    {
        $this->authorization = $authorization;
    }

    public function assertConfirmed(array $attributes, string $message): void
    {
        if (! (bool) ($attributes['userConfirmed'] ?? false)) {
            throw new ValidationException([
                'userConfirmed' => $message,
            ]);
        }
    }

    public function assertAgentPermission(int $userId, string $column, string $attributeName): void
    {
        $this->authorization->assertPermission($userId, $column, $attributeName, 'use this agent gateway action');
    }

    public function tagRelationshipFromAttributes(array $attributes): array
    {
        $tagIds = $this->tagIdsFromAttributes($attributes);

        return [
            'tags' => [
                'data' => array_map(function (int $id): array {
                    return ['type' => 'tags', 'id' => (string) $id];
                }, $tagIds),
            ],
        ];
    }

    public function tagIdsFromAttributes(array $attributes): array
    {
        $raw = $attributes['tagIds'] ?? $attributes['tags'] ?? [];

        if ($raw === null || $raw === '') {
            return [];
        }

        if (is_string($raw)) {
            $raw = preg_split('/[,\s]+/u', $raw, -1, PREG_SPLIT_NO_EMPTY);
        }

        if (! is_array($raw)) {
            throw new ValidationException(['tags' => 'tags must be an array of tag ids or slugs.']);
        }

        $ids = [];
        $slugs = [];

        foreach ($raw as $item) {
            if (is_array($item)) {
                $item = $item['id'] ?? $item['slug'] ?? '';
            }

            $value = trim((string) $item);

            if ($value === '') {
                continue;
            }

            if (ctype_digit($value)) {
                $ids[] = (int) $value;
            } else {
                $slugs[] = $value;
            }
        }

        if ($slugs) {
            $slugIds = Tag::query()
                ->whereIn('slug', array_values(array_unique($slugs)))
                ->pluck('id')
                ->all();

            foreach ($slugIds as $id) {
                $ids[] = (int) $id;
            }

            if (count($slugIds) !== count(array_unique($slugs))) {
                throw new ValidationException(['tags' => 'One or more tag slugs were not found.']);
            }
        }

        $ids = array_values(array_unique(array_filter($ids, fn (int $id): bool => $id > 0)));

        if (count($ids) > 8) {
            throw new ValidationException(['tags' => 'Too many tags.']);
        }

        return $ids;
    }
}
