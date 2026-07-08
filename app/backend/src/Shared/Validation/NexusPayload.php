<?php

namespace Nexus\Forum\Service;

use Flarum\Foundation\ValidationException;

class NexusPayload
{
    public static function string(array $attributes, string $key, int $max = 255, bool $required = false): ?string
    {
        $value = $attributes[$key] ?? null;

        if ($value === null || trim((string) $value) === '') {
            if ($required) {
                throw new ValidationException([$key => "$key is required."]);
            }

            return null;
        }

        $value = trim((string) $value);

        if (mb_strlen($value) > $max) {
            throw new ValidationException([$key => "$key is too long."]);
        }

        return $value;
    }

    public static function oneOf(array $attributes, string $key, array $allowed, string $default): string
    {
        $value = (string) ($attributes[$key] ?? $default);

        if (! in_array($value, $allowed, true)) {
            throw new ValidationException([$key => "$key must be one of: ".implode(', ', $allowed).'.']);
        }

        return $value;
    }

    public static function stringList(array $attributes, string $key, int $maxItems = 12): array
    {
        $value = $attributes[$key] ?? [];

        if ($value === null || $value === '') {
            return [];
        }

        if (is_string($value)) {
            $value = preg_split('/[,，\s]+/u', $value, -1, PREG_SPLIT_NO_EMPTY);
        }

        if (! is_array($value)) {
            throw new ValidationException([$key => "$key must be an array of labels."]);
        }

        $items = [];

        foreach ($value as $item) {
            $label = self::label((string) $item);
            if ($label !== '') {
                $items[$label] = $label;
            }
        }

        $items = array_values($items);

        if (count($items) > $maxItems) {
            throw new ValidationException([$key => "$key has too many labels."]);
        }

        return $items;
    }

    public static function label(string $value): string
    {
        $value = trim(mb_strtolower($value));
        $value = preg_replace('/[^\pL\pN_-]+/u', '-', $value);
        $value = trim($value, '-_');

        return mb_substr($value, 0, 80);
    }

    public static function jsonOrNull($value, string $key): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (! is_array($value)) {
            throw new ValidationException([$key => "$key must be an object."]);
        }

        $encoded = json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($encoded === false || strlen($encoded) > 4000) {
            throw new ValidationException([$key => "$key is too large."]);
        }

        return $encoded;
    }
}
