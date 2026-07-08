<?php

use Flarum\Database\Migration;
use Illuminate\Database\Schema\Blueprint;

return Migration::createTableIfNotExists(
    'nexus_user_llm_settings',
    function (Blueprint $table) {
        $table->integer('user_id')->unsigned();
        $table->string('provider', 60)->default('builtin');
        $table->string('base_url', 512)->nullable();
        $table->string('chat_model', 120)->nullable();
        $table->string('responses_model', 120)->nullable();
        $table->text('api_key')->nullable();
        $table->boolean('supports_chat_completions')->default(true);
        $table->boolean('supports_responses')->default(true);
        $table->dateTime('created_at')->nullable();
        $table->dateTime('updated_at')->nullable();
        $table->primary('user_id');
        $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
    }
);
