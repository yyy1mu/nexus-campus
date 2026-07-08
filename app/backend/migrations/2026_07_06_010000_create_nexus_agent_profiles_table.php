<?php

use Illuminate\Database\Schema\Blueprint;

return [
    'up' => function ($schema) {
        if (! $schema->hasTable('nexus_agent_profiles')) {
            $schema->create('nexus_agent_profiles', function (Blueprint $table) {
                $table->integer('user_id')->unsigned();
                $table->string('agent_name', 120)->nullable();
                $table->string('agent_avatar_url', 512)->nullable();
                $table->text('soul_md')->nullable();
                $table->text('interest_tags')->nullable();
                $table->text('skill_tags')->nullable();
                $table->text('help_tags')->nullable();
                $table->text('match_preferences')->nullable();
                $table->boolean('allow_agent_posting')->default(false);
                $table->boolean('allow_agent_replying')->default(false);
                $table->boolean('allow_agent_matching')->default(false);
                $table->boolean('allow_location_matching')->default(false);
                $table->string('location_visibility', 40)->default('off');
                $table->dateTime('created_at')->nullable();
                $table->dateTime('updated_at')->nullable();

                $table->primary('user_id');
                $table->index(['allow_agent_matching', 'location_visibility'], 'nexus_agent_profiles_match_idx');
                $table->foreign('user_id', 'nexus_agent_profiles_user_fk')->references('id')->on('users')->cascadeOnDelete();
            });

            return;
        }

        $connection = $schema->getConnection();
        $indexes = collect($connection->select('SHOW INDEX FROM nexus_agent_profiles'))
            ->pluck('Key_name')
            ->all();

        if (! in_array('nexus_agent_profiles_match_idx', $indexes, true)) {
            $schema->table('nexus_agent_profiles', function (Blueprint $table) {
                $table->index(['allow_agent_matching', 'location_visibility'], 'nexus_agent_profiles_match_idx');
            });
        }

        $constraints = collect($connection->select(
            'SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? AND REFERENCED_TABLE_NAME IS NOT NULL',
            ['nexus_agent_profiles', 'user_id']
        ))->pluck('CONSTRAINT_NAME')->all();

        if (! in_array('nexus_agent_profiles_user_fk', $constraints, true)) {
            $schema->table('nexus_agent_profiles', function (Blueprint $table) {
                $table->foreign('user_id', 'nexus_agent_profiles_user_fk')->references('id')->on('users')->cascadeOnDelete();
            });
        }
    },
    'down' => function ($schema) {
        $schema->dropIfExists('nexus_agent_profiles');
    },
];
