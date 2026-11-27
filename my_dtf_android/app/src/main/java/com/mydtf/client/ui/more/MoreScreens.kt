package com.mydtf.client.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.DoneAll
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.Repo
import com.mydtf.client.data.friendlyError
import com.mydtf.client.ui.MainViewModel
import com.mydtf.client.ui.components.CommunePicker
import com.mydtf.client.ui.components.EmptyState
import com.mydtf.client.ui.components.GhostButton
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.WilayaPicker
import com.mydtf.client.ui.formatDate
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.Algeria
import com.mydtf.core.Commune
import com.mydtf.core.Wilaya
import kotlinx.coroutines.launch

@Composable
private fun TopBar(title: String, onBack: () -> Unit, actions: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().background(Lux.nightBrush).statusBarsPadding().padding(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "رجوع", tint = Lux.Ivory) }
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
        actions()
    }
}

@Composable
fun NotificationsScreen(main: MainViewModel, onBack: () -> Unit, onOrder: (String) -> Unit) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        TopBar("الإشعارات", onBack) {
            if (main.unread > 0) IconButton(onClick = main::markAllRead) { Icon(Icons.Rounded.DoneAll, "قراءة الكل", tint = Lux.Gold) }
        }
        if (main.notifications.isEmpty()) {
            EmptyState(Icons.Rounded.NotificationsNone, "لا توجد إشعارات", "ستصلك هنا كل مراحل طلبياتك.")
            return@Column
        }
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.navigationBarsPadding()) {
            items(main.notifications, key = { it.id }) { n ->
                LuxCard(
                    Modifier.fillMaxWidth(), highlight = !n.read, padding = PaddingValues(14.dp),
                    onClick = { main.markRead(n); n.orderId?.let(onOrder) },
                ) {
                    Row(verticalAlignment = Alignment.Top) {
                        Box(
                            Modifier.padding(top = 6.dp).size(10.dp).clip(CircleShape)
                                .background(if (n.read) Lux.Muted.copy(alpha = 0.3f) else Lux.Gold),
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(n.title, style = MaterialTheme.typography.titleSmall, fontWeight = if (n.read) FontWeight.Medium else FontWeight.ExtraBold)
                            n.body?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = Lux.GoldLight) }
                            Text(formatDate(n.createdAt), style = MaterialTheme.typography.bodySmall, color = Lux.Muted)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ProfileScreen(main: MainViewModel, onBack: () -> Unit, onSignedOut: () -> Unit) {
    val p = main.profile
    var name by remember(p) { mutableStateOf(p?.fullName.orEmpty()) }
    var phone by remember(p) { mutableStateOf(p?.phone.orEmpty()) }
    var wilaya by remember(p) { mutableStateOf<Wilaya?>(Algeria.wilayaByName(p?.wilaya)) }
    var commune by remember(p) {
        mutableStateOf<Commune?>(Algeria.communeByName(wilaya, p?.commune))
    }
    var address by remember(p) { mutableStateOf(p?.address.orEmpty()) }
    var busy by remember { mutableStateOf(false) }
    var msg by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        TopBar("حسابي", onBack)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LuxCard(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    LuxField(name, { name = it }, "الاسم الكامل", leading = Icons.Rounded.Person)
                    LuxField(phone, { phone = it.filter { c -> c.isDigit() || c == ' ' }.take(12) }, "رقم الهاتف", leading = Icons.Rounded.Phone, keyboard = KeyboardType.Phone)
                    WilayaPicker(wilaya, { wilaya = it; commune = null })
                    CommunePicker(wilaya, commune, { commune = it })
                    LuxField(address, { address = it }, "العنوان", leading = Icons.Rounded.Home)
                }
            }
            msg?.let { Text(it, color = Lux.GoldLight) }
            GoldButton("حفظ التعديلات", loading = busy, enabled = name.isNotBlank() && phone.isNotBlank(), modifier = Modifier.fillMaxWidth(), onClick = {
                busy = true
                scope.launch {
                    msg = try {
                        Repo.updateProfile(name.trim(), phone.replace(" ", ""), wilaya?.fr, commune?.fr, address.trim().ifEmpty { null })
                        main.reloadProfile()
                        "تم الحفظ ✓"
                    } catch (e: Exception) { friendlyError(e) }
                    busy = false
                }
            })
            Spacer(Modifier.height(8.dp))
            GhostButton("تسجيل الخروج", onClick = { main.signOut(onSignedOut) }, icon = Icons.AutoMirrored.Rounded.Logout, modifier = Modifier.fillMaxWidth())
            main.settings?.let { s ->
                Spacer(Modifier.height(12.dp))
                Text(s.workshopName, style = MaterialTheme.typography.titleSmall, color = Lux.Gold)
                s.workshopPhone?.let { Text("هاتف الورشة: $it", color = Lux.Muted) }
                s.workshopAddress?.let { Text("العنوان: $it", color = Lux.Muted) }
            }
        }
    }
}
