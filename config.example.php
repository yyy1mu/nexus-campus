<?php

return [
    'debug' => true,
    'database' => [
        'driver' => 'mysql',
        'host' => getenv('NEXUS_DB_HOST') ?: 'localhost',
        'port' => (int) (getenv('NEXUS_DB_PORT') ?: 3306),
        'database' => getenv('NEXUS_DB_DATABASE') ?: 'nexus_flarum',
        'username' => getenv('NEXUS_DB_USERNAME') ?: 'nexus',
        'password' => getenv('NEXUS_DB_PASSWORD') ?: 'change-me',
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'strict' => false,
        'engine' => 'InnoDB',
        'prefix_indexes' => true,
    ],
    'url' => getenv('NEXUS_FORUM_URL') ?: 'http://localhost:8080',
    'paths' => [
        'api' => 'api',
        'admin' => 'admin',
    ],
    'headers' => [
        'poweredByHeader' => true,
        'referrerPolicy' => 'same-origin',
    ],
];
