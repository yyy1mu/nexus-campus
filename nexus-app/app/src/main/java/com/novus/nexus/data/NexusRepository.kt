package com.novus.nexus.data

import com.novus.nexus.core.network.CapabilityLabelDto
import com.novus.nexus.core.network.DiscussionDto
import com.novus.nexus.core.network.HelpRequestDto
import com.novus.nexus.core.network.NexusApi
import javax.inject.Inject

data class CampusFeed(
    val discussions: List<DiscussionDto>,
    val helpRequests: List<HelpRequestDto>,
    val capabilityLabels: List<CapabilityLabelDto>,
)

interface NexusRepository {
    suspend fun loadCampusFeed(): CampusFeed
}

class NexusRepositoryImpl @Inject constructor(
    private val api: NexusApi,
) : NexusRepository {
    override suspend fun loadCampusFeed(): CampusFeed = CampusFeed(
        discussions = api.discussions().data.orEmpty(),
        helpRequests = api.helpRequests().data.orEmpty(),
        capabilityLabels = api.capabilityLabels().data.orEmpty(),
    )
}
