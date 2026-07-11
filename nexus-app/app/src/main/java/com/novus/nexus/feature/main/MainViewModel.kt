package com.novus.nexus.feature.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.novus.nexus.data.CampusFeed
import com.novus.nexus.data.NexusRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MainUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val feed: CampusFeed = CampusFeed(emptyList(), emptyList(), emptyList()),
    val error: String? = null,
)

@HiltViewModel
class MainViewModel @Inject constructor(
    private val repository: NexusRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    init { refresh(initial = true) }

    fun refresh(initial: Boolean = false) {
        viewModelScope.launch {
            _uiState.update { it.copy(loading = initial, refreshing = !initial, error = null) }
            runCatching { repository.loadCampusFeed() }
                .onSuccess { feed ->
                    _uiState.update { it.copy(loading = false, refreshing = false, feed = feed) }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            error = error.message ?: "无法连接 Nexus 服务",
                        )
                    }
                }
        }
    }
}
