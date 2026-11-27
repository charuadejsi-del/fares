package com.mydtf.pro

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Mail
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.Intro
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.staggerIn
import com.mydtf.client.ui.theme.Lux
import com.mydtf.client.ui.theme.MyDtfTheme

class ProActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(SystemBarStyle.dark(Lux.Night.toArgb()), SystemBarStyle.dark(Lux.Night.toArgb()))
        setContent { MyDtfTheme { ProRoot() } }
    }
}

private var introShown = false

@Composable
private fun ProRoot() {
    val vm: ProViewModel = viewModel()
    var intro by remember { mutableStateOf(!introShown) }
    LaunchedEffect(Unit) { if (vm.stage == Stage.Loading) vm.boot() }
    if (intro) { Intro(subtitle = if (com.mydtf.client.BuildConfig.ADMIN) "لوحة المدير" else "فريق الورشة") { introShown = true; intro = false }; return }
    AnimatedContent(
        targetState = vm.stage,
        transitionSpec = { (fadeIn() + scaleIn(initialScale = 0.96f)) togetherWith fadeOut() },
        label = "stage",
    ) { st ->
        val first = vm.me?.fullName?.firstOrNull()?.toString() ?: "?"
        when (st) {
            Stage.Loading -> Box(Modifier.fillMaxSize().background(Lux.nightBrush))
            Stage.Login -> ProLogin(vm)
            Stage.PinSetup -> PinScreen("اختر رمزك السري", "4 إلى 6 أرقام — تستعمله لتسجيل الدخول والخروج كل يوم", first, vm.pinError, vm.pinShake, { vm.onPin(it) })
            Stage.PinConfirm -> PinScreen("أعد كتابة الرمز", "للتأكيد", first, vm.pinError, vm.pinShake, { vm.onPin(it) })
            Stage.ClockIn -> PinScreen("صباح الخير ${vm.me?.fullName?.substringBefore(' ') ?: ""}", "أدخل رمزك لتسجيل الحضور", first, vm.pinError, vm.pinShake, { vm.onPin(it) }) {
                TextButton(onClick = { vm.logout() }) { Text("تغيير الحساب", color = Lux.Muted) }
            }
            Stage.App -> ProShell(vm)
            Stage.Bye -> ByeScreen(vm)
        }
    }
}

@Composable
private fun ProLogin(vm: ProViewModel) {
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    Box(Modifier.fillMaxSize().background(Lux.nightBrush).imePadding(), contentAlignment = Alignment.Center) {
        LuxCard(Modifier.padding(20.dp).widthIn(max = 460.dp).fillMaxWidth().staggerIn(0), highlight = true) {
            Text(if (com.mydtf.client.BuildConfig.ADMIN) "My DTF Admin" else "My DTF Pro", style = MaterialTheme.typography.headlineMedium)
            Text(if (com.mydtf.client.BuildConfig.ADMIN) "تطبيق المدير — كل الورشة بين يديك" else "تطبيق فريق الورشة", color = Lux.Muted, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(18.dp))
            LuxField(email, { email = it }, "البريد الإلكتروني", leading = Icons.Rounded.Mail, keyboard = KeyboardType.Email)
            Spacer(Modifier.height(10.dp))
            LuxField(pass, { pass = it }, "كلمة السر", leading = Icons.Rounded.Lock, keyboard = KeyboardType.Password, visual = PasswordVisualTransformation())
            vm.error?.let { Text(it, color = Lux.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
            Spacer(Modifier.height(16.dp))
            GoldButton("دخول", onClick = { vm.login(email, pass) }, loading = vm.busy, enabled = email.isNotBlank() && pass.length >= 6, modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun ByeScreen(vm: ProViewModel) {
    Column(Modifier.fillMaxSize().background(Lux.nightBrush).padding(30.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        com.mydtf.client.ui.components.Confetti(Modifier.fillMaxWidth().height(200.dp), pieces = 60)
        Text("إلى اللقاء 👋", style = MaterialTheme.typography.headlineMedium)
        vm.byeMinutes?.let { Text("عملت اليوم ${dur(it.toLong())}", color = Lux.GoldLight, style = MaterialTheme.typography.titleMedium) }
        Spacer(Modifier.height(20.dp))
        GoldButton("تسجيل حضور جديد", onClick = { vm.boot() }, modifier = Modifier.fillMaxWidth())
        TextButton(onClick = { vm.logout() }) { Text("الخروج من الحساب", color = Lux.Muted) }
    }
}
