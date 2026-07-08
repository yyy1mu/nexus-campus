<?php

$dbHost = getenv('NEXUS_DB_HOST') ?: 'localhost';
$dbPort = getenv('NEXUS_DB_PORT') ?: '3306';
$dbName = getenv('NEXUS_DB_DATABASE') ?: 'nexus_flarum';
$dbUser = getenv('NEXUS_DB_USERNAME') ?: 'nexus';
$dbPassword = getenv('NEXUS_DB_PASSWORD') ?: '';
$baseUrl = getenv('NEXUS_BASE_URL') ?: 'http://localhost:8080';
$agentUserId = (int) (getenv('NEXUS_AGENT_USER_ID') ?: 1);

$pdo = new PDO("mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4", $dbUser, $dbPassword, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$key = bin2hex(random_bytes(20));
$stmt = $pdo->prepare('INSERT INTO api_keys (`key`, allowed_ips, scopes, user_id, created_at) VALUES (?, NULL, NULL, ?, NOW())');
$stmt->execute([$key, $agentUserId]);

$dir = __DIR__ . '/storage/nexus';
if (! is_dir($dir)) {
    mkdir($dir, 0700, true);
}

$content = implode("\n", [
    'NEXUS_BASE_URL=' . $baseUrl,
    'NEXUS_AGENT_USER_ID=' . $agentUserId,
    'NEXUS_AGENT_TOKEN=' . $key,
    'NEXUS_AGENT_AUTH=Token ' . $key,
    '',
]);

file_put_contents($dir . '/agent-api.env', $content);
chmod($dir . '/agent-api.env', 0600);

echo 'created api key id=' . $pdo->lastInsertId() . PHP_EOL;
