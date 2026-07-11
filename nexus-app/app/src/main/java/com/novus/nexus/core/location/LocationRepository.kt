package com.novus.nexus.core.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.core.content.ContextCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import javax.inject.Inject
import kotlin.coroutines.resume

data class LocationFix(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val altitudeMeters: Double?,
    val provider: String?,
    val timestampMillis: Long,
)

class LocationRepository @Inject constructor(
    @param:ApplicationContext private val context: Context,
) {
    private val manager = context.getSystemService(LocationManager::class.java)

    fun hasFinePermission(): Boolean = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_FINE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    suspend fun currentLocation(): LocationFix {
        check(hasFinePermission()) { "需要精确位置权限" }
        check(manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) { "请先开启系统 GPS 定位" }

        return try {
            withTimeout(30_000) {
                suspendCancellableCoroutine { continuation ->
                    lateinit var listener: LocationListener
                    listener = LocationListener { location ->
                        manager.removeUpdates(listener)
                        if (continuation.isActive) {
                            continuation.resume(
                                LocationFix(
                                    latitude = location.latitude,
                                    longitude = location.longitude,
                                    accuracyMeters = location.accuracy,
                                    altitudeMeters = if (location.hasAltitude()) location.altitude else null,
                                    provider = location.provider,
                                    timestampMillis = location.time,
                                ),
                            )
                        }
                    }
                    continuation.invokeOnCancellation { manager.removeUpdates(listener) }
                    manager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        0L,
                        0f,
                        listener,
                        Looper.getMainLooper(),
                    )
                }
            }
        } catch (_: kotlinx.coroutines.TimeoutCancellationException) {
            throw IllegalStateException("GPS 定位超时，请移到室外或靠近窗户后重试")
        }
    }
}
