package com.novus.nexus.ui

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.novus.nexus.core.network.CapabilityLabelDto
import com.novus.nexus.core.network.DiscussionDto
import com.novus.nexus.core.network.HelpRequestDto
import com.novus.nexus.feature.main.MainUiState
import com.novus.nexus.feature.main.MainViewModel
import com.novus.nexus.feature.location.LocationViewModel
import java.text.DateFormat
import java.util.Date
import java.util.Locale

private enum class Destination(val route: String, val label: String, val icon: ImageVector) {
    Home("home", "动态", Icons.Outlined.Home),
    Discussions("discussions", "讨论", Icons.Outlined.Forum),
    Help("help", "求助", Icons.AutoMirrored.Outlined.HelpOutline),
    Location("location", "定位", Icons.Outlined.LocationOn),
    Agent("agent", "Agent", Icons.Outlined.Groups),
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun NexusApp(viewModel: MainViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Nexus Campus", fontWeight = FontWeight.Bold)
                        Text(
                            "校园协作网络",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh() }, enabled = !state.refreshing) {
                        if (state.refreshing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        else Icon(Icons.Outlined.Refresh, "刷新")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface),
            )
        },
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                Destination.entries.forEach { destination ->
                    NavigationBarItem(
                        selected = currentRoute == destination.route,
                        onClick = {
                            navController.navigate(destination.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(destination.icon, destination.label) },
                        label = { Text(destination.label) },
                    )
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Destination.Home.route,
            modifier = Modifier.padding(padding),
        ) {
            composable(Destination.Home.route) { HomeScreen(state, viewModel::refresh) }
            composable(Destination.Discussions.route) { DiscussionsScreen(state, viewModel::refresh) }
            composable(Destination.Help.route) { HelpScreen(state, viewModel::refresh) }
            composable(Destination.Location.route) { LocationScreen() }
            composable(Destination.Agent.route) { AgentScreen(state, viewModel::refresh) }
        }
    }
}

@Composable
private fun HomeScreen(state: MainUiState, retry: () -> Unit) = FeedContainer(state, retry) {
    item {
        HeroCard(
            title = "校园协作正在发生",
            detail = "${state.feed.helpRequests.count { it.status == "open" }} 个求助等待响应，" +
                "${state.feed.capabilityLabels.sumOf { it.helperCount }} 位能力贡献者在线。",
        )
        SectionTitle("最新动态", "来自校园社区和已认证 Agent")
    }
    items(state.feed.discussions.take(12), key = { "discussion-${it.id}" }) { DiscussionCard(it) }
    if (state.feed.helpRequests.isNotEmpty()) {
        item { SectionTitle("最近求助", "等待校园能力网络响应") }
        items(state.feed.helpRequests.take(8), key = { "help-${it.id}" }) { HelpCard(it) }
    }
}

@Composable
private fun DiscussionsScreen(state: MainUiState, retry: () -> Unit) = FeedContainer(state, retry) {
    item { SectionTitle("全部讨论", "浏览 Nexus 校园社区中的公开讨论") }
    items(state.feed.discussions, key = { it.id }) { DiscussionCard(it) }
}

@Composable
private fun HelpScreen(state: MainUiState, retry: () -> Unit) = FeedContainer(state, retry) {
    item { SectionTitle("校园求助", "寻找能提供真实帮助的同学") }
    items(state.feed.helpRequests, key = { it.id }) { HelpCard(it) }
}

@Composable
private fun AgentScreen(state: MainUiState, retry: () -> Unit) = FeedContainer(state, retry) {
    item { SectionTitle("Agent 能力网络", "复用能力标签，连接合适的协作者") }
    items(state.feed.capabilityLabels, key = { it.label }) { CapabilityCard(it) }
}

@Composable
private fun LocationScreen(viewModel: LocationViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        if (grants[Manifest.permission.ACCESS_FINE_LOCATION] == true) viewModel.locate()
    }
    val requestLocation = {
        if (viewModel.hasPermission()) viewModel.locate()
        else permissionLauncher.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
        )
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(14.dp),
    ) {
        item { SectionTitle("当前位置", "使用设备 GPS 与系统高精度定位服务") }
        item {
            Card(shape = RoundedCornerShape(8.dp)) {
                Column(Modifier.fillMaxWidth().padding(20.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.LocationOn, null, Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary)
                        Text(
                            if (state.location == null) "尚未定位" else "定位成功",
                            Modifier.padding(start = 12.dp),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    state.location?.let { location ->
                        Spacer(Modifier.height(18.dp))
                        LocationValue("纬度", String.format(Locale.US, "%.6f", location.latitude))
                        LocationValue("经度", String.format(Locale.US, "%.6f", location.longitude))
                        LocationValue("精度", String.format(Locale.US, "± %.1f 米", location.accuracyMeters))
                        location.altitudeMeters?.let {
                            LocationValue("海拔", String.format(Locale.US, "%.1f 米", it))
                        }
                        LocationValue("来源", location.provider ?: "系统融合定位")
                        LocationValue("更新时间", DateFormat.getDateTimeInstance().format(Date(location.timestampMillis)))
                    }
                    state.error?.let {
                        Text(it, Modifier.padding(top = 14.dp), color = MaterialTheme.colorScheme.error)
                    }
                    Button(
                        onClick = requestLocation,
                        enabled = !state.locating,
                        modifier = Modifier.fillMaxWidth().padding(top = 20.dp),
                    ) {
                        if (state.locating) {
                            CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                            Text("正在获取 GPS…", Modifier.padding(start = 10.dp))
                        } else {
                            Icon(Icons.Outlined.LocationOn, null)
                            Text(if (state.location == null) "获取真实位置" else "重新定位", Modifier.padding(start = 8.dp))
                        }
                    }
                }
            }
        }
        item {
            Text(
                "位置只保留在当前设备内。只有在你明确确认后，后续功能才会把位置作为设备信号提交给 Nexus。",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun LocationValue(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
        Text(label, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun FeedContainer(
    state: MainUiState,
    retry: () -> Unit,
    content: androidx.compose.foundation.lazy.LazyListScope.() -> Unit,
) {
    when {
        state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        state.error != null && state.feed.discussions.isEmpty() -> ErrorState(state.error, retry)
        else -> LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

@Composable
private fun HeroCard(title: String, detail: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
        Column(Modifier.fillMaxWidth().padding(20.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun SectionTitle(title: String, subtitle: String) {
    Column(Modifier.padding(top = 8.dp, bottom = 2.dp)) {
        Text(title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun DiscussionCard(item: DiscussionDto) {
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            if (item.tags.isNotEmpty()) Text(item.tags.joinToString(" · ") { it.name }, color = MaterialTheme.colorScheme.secondary)
            Text(item.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Text("${item.commentCount} 条回复", Modifier.padding(top = 10.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun HelpCard(item: HelpRequestDto) {
    Card(shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                AssistChip(onClick = {}, label = { Text(item.status.uppercase()) })
                item.categoryLabel?.let { Text(it, Modifier.padding(start = 10.dp), color = MaterialTheme.colorScheme.secondary) }
            }
            Text(item.summary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            item.locationHint?.let { Text("地点：$it", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            if (item.neededLabels.isNotEmpty()) Text("需要：${item.neededLabels.joinToString()}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun CapabilityCard(item: CapabilityLabelDto) {
    Card(shape = RoundedCornerShape(8.dp)) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(item.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(item.label, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("${item.helperCount} 位同学", color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun ErrorState(message: String, retry: () -> Unit) {
    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.AutoMirrored.Outlined.HelpOutline, null, Modifier.size(44.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("无法连接 Nexus", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(message, maxLines = 3, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
            AssistChip(onClick = retry, label = { Text("重新加载") }, leadingIcon = { Icon(Icons.Outlined.Refresh, null) })
        }
    }
}
