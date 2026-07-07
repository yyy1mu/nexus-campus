<?php

use Flarum\Database\Migration;
use Illuminate\Database\Schema\Blueprint;

return Migration::createTableIfNotExists(
    'nexus_help_dispatches',
    function (Blueprint $table) {
        $table->increments('id');
        $table->integer('help_request_id')->unsigned();
        $table->integer('requester_user_id')->unsigned();
        $table->integer('helper_user_id')->unsigned();
        $table->integer('match_id')->unsigned()->nullable();
        $table->string('status', 40)->default('pending');
        $table->text('message')->nullable();
        $table->text('rationale')->nullable();
        $table->text('response_message')->nullable();
        $table->string('meeting_hint', 255)->nullable();
        $table->string('meeting_safety_state', 40)->default('not_arranged');
        $table->dateTime('expires_at')->nullable();
        $table->dateTime('responded_at')->nullable();
        $table->dateTime('created_at')->nullable();
        $table->dateTime('updated_at')->nullable();

        $table->unique(['help_request_id', 'helper_user_id']);
        $table->index(['helper_user_id', 'status']);
        $table->index(['help_request_id', 'status']);
        $table->foreign('help_request_id')->references('id')->on('nexus_help_requests')->cascadeOnDelete();
        $table->foreign('requester_user_id')->references('id')->on('users')->cascadeOnDelete();
        $table->foreign('helper_user_id')->references('id')->on('users')->cascadeOnDelete();
        $table->foreign('match_id')->references('id')->on('nexus_help_matches')->nullOnDelete();
    }
);
