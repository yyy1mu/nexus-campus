<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script must be run from the CLI.\n");
    exit(1);
}

$action = $argv[1] ?? '';

try {
    if ($action === 'create') {
        createFixture($argv[2] ?? '', $argv[3] ?? '');
    } elseif ($action === 'cleanup') {
        cleanupFixture($argv[2] ?? '');
    } else {
        throw new RuntimeException('Usage: php scripts/nexus-core-flow-fixture.php create <run-id> <fixture-path> | cleanup <fixture-path>');
    }
} catch (Throwable $e) {
    fwrite(STDERR, $e->getMessage()."\n");
    exit(1);
}

function createFixture(string $runId, string $fixturePath): void
{
    $runId = normalizeRunId($runId);

    if ($fixturePath === '') {
        throw new RuntimeException('fixture path is required.');
    }

    $pdo = connectPdo();
    $now = date('Y-m-d H:i:s');
    $suffix = substr(str_replace('-', '_', $runId), 0, 48);

    $pdo->beginTransaction();

    try {
        $requester = insertSmokeUser($pdo, "nexus_smoke_req_$suffix", "nexus-smoke-req-$runId@example.invalid", $now);
        $helper = insertSmokeUser($pdo, "nexus_smoke_helper_$suffix", "nexus-smoke-helper-$runId@example.invalid", $now);
        $outsider = insertSmokeUser($pdo, "nexus_smoke_outsider_$suffix", "nexus-smoke-outsider-$runId@example.invalid", $now);
        $requesterToken = insertApiKey($pdo, (int) $requester['id'], $now);
        $helperToken = insertApiKey($pdo, (int) $helper['id'], $now);
        $outsiderToken = insertApiKey($pdo, (int) $outsider['id'], $now);
        $requesterAgentToken = insertDeveloperToken($pdo, (int) $requester['id'], "Nexus local agent - smoke requester $runId", $now);
        $helperAgentToken = insertDeveloperToken($pdo, (int) $helper['id'], "Nexus local agent - smoke helper $runId", $now);

        $fixture = [
            'runId' => $runId,
            'createdAt' => gmdate('c'),
            'users' => [
                'requester' => [
                    'id' => (int) $requester['id'],
                    'username' => $requester['username'],
                    'auth' => 'Token '.$requesterToken,
                    'agentAuth' => 'Token '.$requesterAgentToken,
                ],
                'helper' => [
                    'id' => (int) $helper['id'],
                    'username' => $helper['username'],
                    'auth' => 'Token '.$helperToken,
                    'agentAuth' => 'Token '.$helperAgentToken,
                ],
                'outsider' => [
                    'id' => (int) $outsider['id'],
                    'username' => $outsider['username'],
                    'auth' => 'Token '.$outsiderToken,
                ],
            ],
        ];

        $absolutePath = absolutePath($fixturePath);
        $dir = dirname($absolutePath);

        if (! is_dir($dir) && ! mkdir($dir, 0700, true) && ! is_dir($dir)) {
            throw new RuntimeException("Could not create fixture directory: $dir");
        }

        $encoded = json_encode($fixture, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if ($encoded === false) {
            throw new RuntimeException('Could not encode fixture JSON.');
        }

        file_put_contents($absolutePath, $encoded."\n", LOCK_EX);
        chmod($absolutePath, 0600);
        $pdo->commit();

        echo 'created run='.$runId.' requesterUserId='.$requester['id'].' helperUserId='.$helper['id'].' outsiderUserId='.$outsider['id']."\n";
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
}

function cleanupFixture(string $fixturePath): void
{
    if ($fixturePath === '') {
        throw new RuntimeException('fixture path is required.');
    }

    $absolutePath = absolutePath($fixturePath);

    if (! is_file($absolutePath)) {
        echo "cleanup skipped: fixture file not found\n";
        return;
    }

    $fixture = json_decode((string) file_get_contents($absolutePath), true);
    if (! is_array($fixture)) {
        throw new RuntimeException('Could not parse fixture file.');
    }

    $runId = normalizeRunId((string) ($fixture['runId'] ?? ''));
    $userIds = [];

    foreach (['requester', 'helper', 'outsider'] as $role) {
        $id = (int) ($fixture['users'][$role]['id'] ?? 0);
        if ($id > 0) {
            $userIds[] = $id;
        }
    }

    $userIds = array_values(array_unique($userIds));
    $pdo = connectPdo();
    $pdo->beginTransaction();

    try {
        if ($userIds) {
            $helpRequestIds = selectColumnIn($pdo, 'SELECT id FROM nexus_help_requests WHERE requester_user_id IN (%s)', $userIds);
            $discussionIds = selectColumnIn($pdo, 'SELECT discussion_id FROM nexus_help_requests WHERE requester_user_id IN (%s)', $userIds);

            if ($runId !== '') {
                $like = '%'.$runId.'%';
                $stmt = $pdo->prepare('SELECT id FROM discussions WHERE title LIKE ?');
                $stmt->execute([$like]);
                $discussionIds = array_merge($discussionIds, array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN)));

                $stmt = $pdo->prepare('SELECT id FROM nexus_help_requests WHERE summary LIKE ? OR agent_context LIKE ?');
                $stmt->execute([$like, $like]);
                $helpRequestIds = array_merge($helpRequestIds, array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN)));
            }

            $helpRequestIds = array_values(array_unique(array_map('intval', $helpRequestIds)));
            $discussionIds = array_values(array_unique(array_map('intval', $discussionIds)));

            $matchIds = $helpRequestIds
                ? selectColumnIn($pdo, 'SELECT id FROM nexus_help_matches WHERE help_request_id IN (%s)', $helpRequestIds)
                : [];
            $dispatchIds = $helpRequestIds
                ? selectColumnIn($pdo, 'SELECT id FROM nexus_help_dispatches WHERE help_request_id IN (%s)', $helpRequestIds)
                : [];

            $matchIds = array_merge(
                $matchIds,
                selectColumnIn($pdo, 'SELECT id FROM nexus_help_matches WHERE helper_user_id IN (%s)', $userIds)
            );
            $dispatchIds = array_merge(
                $dispatchIds,
                selectColumnIn($pdo, 'SELECT id FROM nexus_help_dispatches WHERE requester_user_id IN (%s) OR helper_user_id IN (%s)', $userIds, $userIds)
            );

            $matchIds = array_values(array_unique(array_map('intval', $matchIds)));
            $dispatchIds = array_values(array_unique(array_map('intval', $dispatchIds)));

            deleteWhereIn($pdo, 'notifications', 'subject_id', $dispatchIds, 'type = '.$pdo->quote('nexusHelpDispatch'));
            deleteWhereIn($pdo, 'notifications', 'user_id', $userIds);
            deleteWhereIn($pdo, 'notifications', 'from_user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_help_match_messages', 'match_id', $matchIds);
            deleteWhereIn($pdo, 'nexus_help_match_messages', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_help_dispatches', 'id', $dispatchIds);
            deleteWhereIn($pdo, 'nexus_help_matches', 'id', $matchIds);
            deleteWhereIn($pdo, 'nexus_help_requests', 'id', $helpRequestIds);
            deleteWhereIn($pdo, 'discussion_tag', 'discussion_id', $discussionIds);
            deleteWhereIn($pdo, 'discussion_user', 'discussion_id', $discussionIds);
            deleteWhereIn($pdo, 'posts', 'discussion_id', $discussionIds);
            deleteWhereIn($pdo, 'discussions', 'id', $discussionIds);
            deleteWhereIn($pdo, 'api_keys', 'user_id', $userIds);
            deleteWhereIn($pdo, 'access_tokens', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_agent_action_logs', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_agent_profiles', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_user_capabilities', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_user_llm_settings', 'user_id', $userIds);
            deleteWhereIn($pdo, 'nexus_device_signals', 'user_id', $userIds);
            deleteWhereIn($pdo, 'users', 'id', $userIds);

            assertNoResiduals($pdo, $userIds, $helpRequestIds, $matchIds, $dispatchIds, $discussionIds);
        }

        $pdo->commit();
        unlink($absolutePath);

        echo 'cleaned run='.$runId."\n";
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
}

function insertSmokeUser(PDO $pdo, string $username, string $email, string $now): array
{
    $stmt = $pdo->prepare(
        'INSERT INTO users (username, email, is_email_confirmed, password, joined_at, discussion_count, comment_count) VALUES (?, ?, 1, ?, ?, 0, 0)'
    );
    $stmt->execute([
        substr($username, 0, 100),
        substr($email, 0, 254),
        password_hash(bin2hex(random_bytes(16)), PASSWORD_BCRYPT),
        $now,
    ]);

    return [
        'id' => (int) $pdo->lastInsertId(),
        'username' => substr($username, 0, 100),
    ];
}

function insertApiKey(PDO $pdo, int $userId, string $now): string
{
    $key = bin2hex(random_bytes(20));
    $stmt = $pdo->prepare('INSERT INTO api_keys (`key`, allowed_ips, scopes, user_id, created_at) VALUES (?, NULL, NULL, ?, ?)');
    $stmt->execute([$key, $userId, $now]);

    return $key;
}

function insertDeveloperToken(PDO $pdo, int $userId, string $title, string $now): string
{
    $token = bin2hex(random_bytes(20));
    $stmt = $pdo->prepare(
        'INSERT INTO access_tokens (token, user_id, created_at, last_activity_at, type, title, last_ip_address, last_user_agent) VALUES (?, ?, ?, NULL, ?, ?, NULL, NULL)'
    );
    $stmt->execute([$token, $userId, $now, 'developer', substr($title, 0, 150)]);

    return $token;
}

function connectPdo(): PDO
{
    $config = require dirname(__DIR__).'/config.php';
    $database = $config['database'];

    return new PDO(
        'mysql:host='.$database['host'].';port='.$database['port'].';dbname='.$database['database'].';charset=utf8mb4',
        $database['username'],
        $database['password'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
}

function normalizeRunId(string $runId): string
{
    $runId = strtolower(trim($runId));

    if (! preg_match('/^[a-z0-9][a-z0-9-]{2,80}$/', $runId)) {
        throw new RuntimeException('run id must contain only lowercase letters, numbers, and hyphens.');
    }

    return $runId;
}

function absolutePath(string $path): string
{
    if (preg_match('/^([A-Za-z]:[\\\\\/]|\/)/', $path)) {
        return $path;
    }

    return dirname(__DIR__).'/'.str_replace('\\', '/', $path);
}

function selectColumnIn(PDO $pdo, string $sqlTemplate, array ...$idSets): array
{
    $params = [];
    $sql = $sqlTemplate;

    foreach ($idSets as $ids) {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (! $ids) {
            return [];
        }

        $placeholder = implode(',', array_fill(0, count($ids), '?'));
        $sql = preg_replace('/%s/', $placeholder, $sql, 1);
        array_push($params, ...$ids);
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
}

function deleteWhereIn(PDO $pdo, string $table, string $column, array $ids, ?string $extraWhere = null): void
{
    $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));

    if (! $ids) {
        return;
    }

    $sql = 'DELETE FROM `'.$table.'` WHERE `'.$column.'` IN ('.implode(',', array_fill(0, count($ids), '?')).')';
    if ($extraWhere) {
        $sql .= ' AND '.$extraWhere;
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($ids);
}

function assertNoResiduals(
    PDO $pdo,
    array $userIds,
    array $helpRequestIds,
    array $matchIds,
    array $dispatchIds,
    array $discussionIds
): void {
    $checks = [
        'users' => countWhereIn($pdo, 'users', 'id', $userIds),
        'api_keys' => countWhereIn($pdo, 'api_keys', 'user_id', $userIds),
        'access_tokens' => countWhereIn($pdo, 'access_tokens', 'user_id', $userIds),
        'notifications_user' => countWhereIn($pdo, 'notifications', 'user_id', $userIds),
        'notifications_from_user' => countWhereIn($pdo, 'notifications', 'from_user_id', $userIds),
        'nexus_agent_profiles' => countWhereIn($pdo, 'nexus_agent_profiles', 'user_id', $userIds),
        'nexus_user_capabilities' => countWhereIn($pdo, 'nexus_user_capabilities', 'user_id', $userIds),
        'nexus_user_llm_settings' => countWhereIn($pdo, 'nexus_user_llm_settings', 'user_id', $userIds),
        'nexus_device_signals' => countWhereIn($pdo, 'nexus_device_signals', 'user_id', $userIds),
        'nexus_agent_action_logs' => countWhereIn($pdo, 'nexus_agent_action_logs', 'user_id', $userIds),
        'nexus_help_requests' => countWhereIn($pdo, 'nexus_help_requests', 'id', $helpRequestIds),
        'nexus_help_matches' => countWhereIn($pdo, 'nexus_help_matches', 'id', $matchIds),
        'nexus_help_dispatches' => countWhereIn($pdo, 'nexus_help_dispatches', 'id', $dispatchIds),
        'nexus_help_match_messages_by_match' => countWhereIn($pdo, 'nexus_help_match_messages', 'match_id', $matchIds),
        'nexus_help_match_messages_by_user' => countWhereIn($pdo, 'nexus_help_match_messages', 'user_id', $userIds),
        'discussions' => countWhereIn($pdo, 'discussions', 'id', $discussionIds),
        'posts' => countWhereIn($pdo, 'posts', 'discussion_id', $discussionIds),
        'discussion_tag' => countWhereIn($pdo, 'discussion_tag', 'discussion_id', $discussionIds),
        'discussion_user' => countWhereIn($pdo, 'discussion_user', 'discussion_id', $discussionIds),
    ];

    $residuals = [];

    foreach ($checks as $name => $count) {
        echo 'residual '.$name.'='.$count."\n";

        if ($count > 0) {
            $residuals[$name] = $count;
        }
    }

    if ($residuals) {
        throw new RuntimeException('Cleanup left residual rows: '.json_encode($residuals, JSON_UNESCAPED_SLASHES));
    }
}

function countWhereIn(PDO $pdo, string $table, string $column, array $ids): int
{
    $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));

    if (! $ids) {
        return 0;
    }

    $sql = 'SELECT COUNT(*) FROM `'.$table.'` WHERE `'.$column.'` IN ('.implode(',', array_fill(0, count($ids), '?')).')';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($ids);

    return (int) $stmt->fetchColumn();
}
