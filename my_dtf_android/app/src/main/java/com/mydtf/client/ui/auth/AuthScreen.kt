package com.mydtf.client.ui.auth

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AlternateEmail
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.material.icons.rounded.Print
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mydtf.client.data.NewProfileInput
import com.mydtf.client.data.Repo
import com.mydtf.client.data.friendlyError
import com.mydtf.client.ui.components.CommunePicker
import com.mydtf.client.ui.components.GoldButton
import com.mydtf.client.ui.components.LuxCard
import com.mydtf.client.ui.components.LuxField
import com.mydtf.client.ui.components.WilayaPicker
import com.mydtf.client.ui.theme.Lux
import com.mydtf.core.Commune
import com.mydtf.core.Wilaya
import kotlinx.coroutines.launch

private val phoneRegex = Regex("^0[5-7]\\d{8}$")

@Composable
fun AuthScreen(notice: String? = null) {
    var signup by rememberSaveable { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(notice) }
    var info by remember { mutableStateOf<String?>(null) }
    var tried by remember { mutableStateOf(false) }

    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var showPass by remember { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var wilaya by remember { mutableStateOf<Wilaya?>(null) }
    var commune by remember { mutableStateOf<Commune?>(null) }
    var address by rememberSaveable { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    val emailOk = email.contains('@') && email.contains('.')
    val passOk = password.length >= 6
    val phoneOk = phoneRegex.matches(phone.replace(" ", ""))
    val formOk = emailOk && passOk && (!signup || (name.isNotBlank() && phoneOk && wilaya != null && commune != null))

    fun submit() {
        tried = true
        if (!formOk) return
        busy = true; error = null; info = null
        scope.launch {
            try {
                if (signup) {
                    val logged = Repo.signUp(
                        email.trim(), password,
                        NewProfileInput(name.trim(), phone.replace(" ", ""), wilaya?.fr, commune?.fr, address.trim().ifEmpty { null }),
                    )
                    if (!logged) {
                        signup = false
                        info = "تم إنشاء حسابك ✓ أكّد بريدك الإلكتروني ثم سجّل الدخول."
                    }
                } else Repo.signIn(email.trim(), password)
            } catch (e: Exception) {
                error = friendlyError(e)
            } finally { busy = false }
        }
    }

    Box(Modifier.fillMaxSize().background(Lux.nightBrush)) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding()
                .verticalScroll(rememberScrollState()).padding(horizontal = 22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(36.dp))
            // Logo
            Box(
                Modifier.size(92.dp).clip(CircleShape).background(Lux.goldBrush),
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(84.dp).clip(CircleShape).background(Lux.Night), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Print, null, tint = Lux.Gold, modifier = Modifier.size(44.dp))
                }
            }
            Spacer(Modifier.height(14.dp))
            Text("My DTF", style = MaterialTheme.typography.displaySmall, color = Lux.Gold)
            Text("طباعة DTF احترافية — احسب سعرك في ثوانٍ", style = MaterialTheme.typography.bodyMedium, color = Lux.Muted, textAlign = TextAlign.Center)
            Spacer(Modifier.height(26.dp))

            // Sélecteur Connexion / Inscription
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .border(1.dp, Lux.Gold.copy(alpha = 0.18f), RoundedCornerShape(18.dp)).padding(5.dp),
            ) {
                listOf(false to "تسجيل الدخول", true to "حساب جديد").forEach { (isSignup, label) ->
                    val sel = signup == isSignup
                    Box(
                        Modifier.weight(1f).height(46.dp).clip(RoundedCornerShape(14.dp))
                            .background(if (sel) Lux.goldBrush else androidx.compose.ui.graphics.SolidColor(androidx.compose.ui.graphics.Color.Transparent))
                            .clickable { signup = isSignup; error = null; tried = false },
                        contentAlignment = Alignment.Center,
                    ) { Text(label, color = if (sel) Lux.Night else Lux.Muted, style = MaterialTheme.typography.labelLarge) }
                }
            }
            Spacer(Modifier.height(18.dp))

            LuxCard(Modifier.fillMaxWidth()) {
                AnimatedContent(signup, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "form") { isSignup ->
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (isSignup) {
                            LuxField(name, { name = it }, "الاسم الكامل", leading = Icons.Rounded.Person,
                                isError = tried && name.isBlank(), supporting = if (tried && name.isBlank()) "مطلوب" else null)
                            LuxField(phone, { phone = it.filter { c -> c.isDigit() || c == ' ' }.take(12) }, "رقم الهاتف",
                                leading = Icons.Rounded.Phone, keyboard = KeyboardType.Phone,
                                isError = tried && !phoneOk, supporting = if (tried && !phoneOk) "مثال: 0555 12 34 56" else null)
                            WilayaPicker(wilaya, { wilaya = it; commune = null })
                            CommunePicker(wilaya, commune, { commune = it })
                            LuxField(address, { address = it }, "العنوان (اختياري)", leading = Icons.Rounded.Home)
                        }
                        LuxField(email, { email = it.trim() }, "البريد الإلكتروني", leading = Icons.Rounded.AlternateEmail,
                            keyboard = KeyboardType.Email, isError = tried && !emailOk,
                            supporting = if (tried && !emailOk) "بريد غير صحيح" else null)
                        LuxField(password, { password = it }, "كلمة السر", leading = Icons.Rounded.Lock,
                            keyboard = KeyboardType.Password,
                            visual = if (showPass) VisualTransformation.None else PasswordVisualTransformation(),
                            isError = tried && !passOk, supporting = if (tried && !passOk) "6 أحرف على الأقل" else null,
                            trailing = {
                                IconButton(onClick = { showPass = !showPass }) {
                                    Icon(if (showPass) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility, null)
                                }
                            })
                    }
                }
                AnimatedVisibility(error != null) {
                    Text(error ?: "", color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 10.dp))
                }
                AnimatedVisibility(info != null) {
                    Text(info ?: "", color = Lux.Success, modifier = Modifier.padding(top = 10.dp))
                }
                Spacer(Modifier.height(16.dp))
                GoldButton(
                    if (signup) "إنشاء الحساب" else "دخول",
                    onClick = ::submit, loading = busy, modifier = Modifier.fillMaxWidth(),
                )
            }
            Spacer(Modifier.height(30.dp))
        }
    }
}
