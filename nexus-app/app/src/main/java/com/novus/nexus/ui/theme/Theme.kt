package com.novus.nexus.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val NexusColors = lightColorScheme(
    primary = Color(0xFF2166E8),
    onPrimary = Color.White,
    secondary = Color(0xFF15877B),
    background = Color(0xFFF6F7F8),
    surface = Color.White,
    onSurface = Color(0xFF141B27),
    onSurfaceVariant = Color(0xFF687386),
    outlineVariant = Color(0xFFDDE2E8),
)

@Composable
fun NexusTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = NexusColors, content = content)
}
