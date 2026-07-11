package com.novus.nexus.feature.location

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.novus.nexus.core.location.LocationFix
import com.novus.nexus.core.location.LocationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LocationUiState(
    val locating: Boolean = false,
    val location: LocationFix? = null,
    val error: String? = null,
)

@HiltViewModel
class LocationViewModel @Inject constructor(
    private val repository: LocationRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(LocationUiState())
    val uiState: StateFlow<LocationUiState> = _uiState.asStateFlow()

    fun hasPermission(): Boolean = repository.hasFinePermission()

    fun locate() {
        if (!hasPermission()) {
            _uiState.update { it.copy(error = "请授予精确位置权限") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(locating = true, error = null) }
            runCatching { repository.currentLocation() }
                .onSuccess { fix -> _uiState.update { it.copy(locating = false, location = fix) } }
                .onFailure { error ->
                    _uiState.update { it.copy(locating = false, error = error.message ?: "定位失败") }
                }
        }
    }
}
