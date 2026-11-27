package com.mydtf.client

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.navArgument
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mydtf.client.data.Supa
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.auth.AuthScreen
import com.mydtf.client.ui.home.HomeScreen
import com.mydtf.client.ui.more.ArchiveScreen
import com.mydtf.client.ui.more.ChatScreen
import com.mydtf.client.ui.more.CompleteProfileScreen
import com.mydtf.client.ui.more.NotificationsScreen
import com.mydtf.client.ui.more.ProfileScreen
import com.mydtf.client.ui.order.NewOrderScreen
import com.mydtf.client.ui.order.OrderDetailScreen
import com.mydtf.client.ui.theme.Lux
import com.mydtf.client.ui.theme.MyDtfTheme
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        androidx.core.splashscreen.SplashScreen.installSplashScreen(this)
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Lux.Night.toArgb()),
            navigationBarStyle = SystemBarStyle.dark(Lux.Night.toArgb()),
        )
        setContent { MyDtfTheme { Root() } }
    }
}

private var introShown = false

@Composable
private fun Root() {
    var intro by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(!introShown) }
    if (intro) { com.mydtf.client.ui.components.Intro { introShown = true; intro = false }; return }
    val status by Supa.client.auth.sessionStatus.collectAsState()
    when (status) {
        is SessionStatus.Authenticated -> ClientNav()
        is SessionStatus.NotAuthenticated -> AuthScreen(if (com.mydtf.client.ui.StaffFlag.blocked) com.mydtf.client.data.Repo.STAFF_ONLY else null)
        else -> Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = Lux.Gold)
        }
    }
}

@Composable
private fun ClientNav() {
    val main: MainViewModel = viewModel()
    LaunchedEffect(Unit) { main.start() }
    if (main.needsProfile) { CompleteProfileScreen(main); return }
    val nav = rememberNavController()
    NavHost(
        nav, startDestination = "home",
        modifier = Modifier.background(MaterialTheme.colorScheme.background),
        enterTransition = { slideInHorizontally { -it / 4 } + fadeIn() },
        exitTransition = { fadeOut() },
        popEnterTransition = { fadeIn() },
        popExitTransition = { slideOutHorizontally { -it / 4 } + fadeOut() },
    ) {
        composable("home") {
            HomeScreen(
                main,
                onNewOrder = { nav.navigate("new") },
                onOrder = { nav.navigate("order/$it") },
                onNotifications = { nav.navigate("notifs") },
                onProfile = { nav.navigate("profile") },
                onChat = { nav.navigate("chat") },
                onArchive = { nav.navigate("archive") },
            )
        }
        composable("new?from={from}", arguments = listOf(navArgument("from") { type = NavType.StringType; nullable = true; defaultValue = null })) { entry ->
            NewOrderScreen(main, onClose = { nav.popBackStack() }, onCreated = { id ->
                main.refresh()
                nav.navigate("order/$id") { popUpTo("home") }
            }, fromOrder = entry.arguments?.getString("from"))
        }
        composable("order/{id}") { entry ->
            OrderDetailScreen(entry.arguments?.getString("id")!!, main, onBack = { nav.popBackStack() },
                onReorder = { nav.navigate("new?from=$it") }, onChat = { nav.navigate("chat?order=$it") })
        }
        composable("chat?order={order}", arguments = listOf(navArgument("order") { type = NavType.StringType; nullable = true; defaultValue = null })) { entry ->
            ChatScreen(main, onBack = { nav.popBackStack() }, presetOrder = entry.arguments?.getString("order"))
        }
        composable("archive") {
            ArchiveScreen(main, onBack = { nav.popBackStack() }, onOrder = { nav.navigate("order/$it") })
        }
        composable("notifs") {
            NotificationsScreen(main, onBack = { nav.popBackStack() }, onOrder = { nav.navigate("order/$it") })
        }
        composable("profile") {
            ProfileScreen(main, onBack = { nav.popBackStack() }, onSignedOut = {})
        }
    }
}
