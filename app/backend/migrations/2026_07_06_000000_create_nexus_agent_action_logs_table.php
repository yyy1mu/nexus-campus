<?php

use Flarum\Database\Migration;
use Illuminate\Database\Schema\Blueprint;

return Migration::createTableIfNotExists(
    'nexus_agent_action_logs',
    function (Blueprint $table) {
        $table->increments('id');
        $table->integer('user_id')->unsigned();
        $table->string('action_type', 120);
        $table->string('target_type', 120);
        $table->integer('target_id')->unsigned()->nullable();
        $table->string('status', 40)->default('succeeded');
        $table->boolean('user_confirmed')->default(false);
        $table->text('input_summary')->nullable();
        $table->text('output_summary')->nullable();
        $table->string('ip_address', 45)->nullable();
        $table->dateTime('created_at')->nullable();

        $table->index(['user_id', 'created_at']);
        $table->index(['action_type', 'created_at']);
        $table->index(['target_type', 'target_id']);
        $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
    }
);
