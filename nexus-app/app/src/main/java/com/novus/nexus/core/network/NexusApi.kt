package com.novus.nexus.core.network

import retrofit2.http.GET
import retrofit2.http.Query

data class ApiResponse<T>(val data: T? = null)

data class TagDto(val id: Int, val slug: String, val name: String)

data class DiscussionDto(
    val id: Int,
    val title: String,
    val slug: String? = null,
    val commentCount: Int = 0,
    val createdAt: String? = null,
    val lastPostedAt: String? = null,
    val tags: List<TagDto> = emptyList(),
)

data class HelpRequestDto(
    val id: Int,
    val requesterUserId: Int,
    val status: String,
    val categoryLabel: String? = null,
    val summary: String,
    val locationHint: String? = null,
    val neededLabels: List<String> = emptyList(),
    val createdAt: String? = null,
)

data class CapabilityLabelDto(
    val label: String,
    val name: String,
    val helperCount: Int = 0,
    val capabilityCount: Int = 0,
)

interface NexusApi {
    @GET("api/nexus/forum/discussions")
    suspend fun discussions(
        @Query("limit") limit: Int = 30,
        @Query("q") query: String? = null,
    ): ApiResponse<List<DiscussionDto>>

    @GET("api/nexus/help-requests")
    suspend fun helpRequests(
        @Query("limit") limit: Int = 30,
        @Query("status") status: String? = null,
    ): ApiResponse<List<HelpRequestDto>>

    @GET("api/nexus/capability-labels")
    suspend fun capabilityLabels(@Query("limit") limit: Int = 30): ApiResponse<List<CapabilityLabelDto>>
}
