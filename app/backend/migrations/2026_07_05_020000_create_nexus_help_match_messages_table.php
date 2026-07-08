<?php

use Flarum\Database\Migration;
use Illuminate\Database\Schema\Blueprint;

return Migration::createTableIfNotExists(
    'nexus_help_match_messages',
    function (Blueprint $table) {
        $table->increments('id');
        $table->integer('match_id')->unsigned();
        $table->integer('user_id')->unsigned();
        $table->text('content');
        $table->text('agent_context')->nullable();
        $table->dateTime('created_at')->nullable();
        $table->dateTime('updated_at')->nullable();

        $table->index(['match_id', 'created_at']);
        $table->foreign('match_id')->references('id')->on('nexus_help_matches')->cascadeOnDelete();
        $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
    }
);
