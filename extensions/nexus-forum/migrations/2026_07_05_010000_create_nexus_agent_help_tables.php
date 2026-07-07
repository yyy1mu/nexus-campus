<?php

use Flarum\Database\Migration;
use Illuminate\Database\Schema\Blueprint;

return [
    'up' => function ($schema) {
        if (! $schema->hasTable('nexus_user_capabilities')) {
            $schema->create('nexus_user_capabilities', function (Blueprint $table) {
                $table->increments('id');
                $table->integer('user_id')->unsigned();
                $table->string('label', 80);
                $table->string('name', 120);
                $table->text('summary')->nullable();
                $table->string('availability', 80)->nullable();
                $table->integer('service_radius_m')->unsigned()->nullable();
                $table->boolean('is_active')->default(true);
                $table->dateTime('created_at')->nullable();
                $table->dateTime('updated_at')->nullable();

                $table->unique(['user_id', 'label']);
                $table->index(['label', 'is_active']);
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }

        if (! $schema->hasTable('nexus_help_requests')) {
            $schema->create('nexus_help_requests', function (Blueprint $table) {
                $table->increments('id');
                $table->integer('discussion_id')->unsigned()->unique();
                $table->integer('requester_user_id')->unsigned();
                $table->string('status', 40)->default('open');
                $table->string('category_label', 80)->nullable();
                $table->text('needed_labels')->nullable();
                $table->text('summary')->nullable();
                $table->string('urgency', 40)->default('normal');
                $table->string('location_hint', 255)->nullable();
                $table->string('meeting_safety_state', 40)->default('not_arranged');
                $table->text('agent_context')->nullable();
                $table->dateTime('created_at')->nullable();
                $table->dateTime('updated_at')->nullable();
                $table->dateTime('closed_at')->nullable();

                $table->index(['status', 'category_label']);
                $table->index(['requester_user_id', 'status']);
                $table->foreign('discussion_id')->references('id')->on('discussions')->cascadeOnDelete();
                $table->foreign('requester_user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }

        if (! $schema->hasTable('nexus_help_matches')) {
            $schema->create('nexus_help_matches', function (Blueprint $table) {
                $table->increments('id');
                $table->integer('help_request_id')->unsigned();
                $table->integer('helper_user_id')->unsigned();
                $table->string('status', 40)->default('offered');
                $table->text('message')->nullable();
                $table->string('meeting_hint', 255)->nullable();
                $table->string('meeting_safety_state', 40)->default('not_arranged');
                $table->dateTime('created_at')->nullable();
                $table->dateTime('updated_at')->nullable();
                $table->dateTime('accepted_at')->nullable();
                $table->dateTime('completed_at')->nullable();

                $table->unique(['help_request_id', 'helper_user_id']);
                $table->index(['help_request_id', 'status']);
                $table->foreign('help_request_id')->references('id')->on('nexus_help_requests')->cascadeOnDelete();
                $table->foreign('helper_user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }

        if (! $schema->hasTable('nexus_device_signals')) {
            $schema->create('nexus_device_signals', function (Blueprint $table) {
                $table->increments('id');
                $table->integer('user_id')->unsigned();
                $table->string('purpose', 80)->default('linkgo');
                $table->string('coarse_geohash', 32)->nullable();
                $table->integer('accuracy_m')->unsigned()->nullable();
                $table->boolean('bluetooth_seen')->default(false);
                $table->boolean('shake_detected')->default(false);
                $table->boolean('gyro_available')->default(false);
                $table->text('payload')->nullable();
                $table->dateTime('created_at')->nullable();
                $table->dateTime('expires_at')->nullable();

                $table->index(['purpose', 'created_at']);
                $table->index(['user_id', 'created_at']);
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }
    },
    'down' => function ($schema) {
        $schema->dropIfExists('nexus_device_signals');
        $schema->dropIfExists('nexus_help_matches');
        $schema->dropIfExists('nexus_help_requests');
        $schema->dropIfExists('nexus_user_capabilities');
    },
];
