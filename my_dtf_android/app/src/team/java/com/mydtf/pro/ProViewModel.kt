package com.mydtf.pro

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.mydtf.client.data.friendlyError
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

const val ADMIN_ONLY = "هذا التطبيق خاص بالمدير — الفريق يستعمل تطبيق My DTF Pro"

enum class Stage { Loading, Login, PinSetup, PinConfirm, ClockIn, App, Bye }

/** État de la session « équipe » : connexion, pointage, données de travail en direct. */
class ProViewModel(app: Application) : AndroidViewModel(app) {
    var stage by mutableStateOf(Stage.Loading); private set
    var me by mutableStateOf<StaffMe?>(null); private set
    var staff by mutableStateOf<List<StaffLite>>(emptyList()); private set
    var since by mutableStateOf<String?>(null); private set
    var error by mutableStateOf<String?>(null)
    var pinError by mutableStateOf<String?>(null)
    var pinShake by mutableStateOf(0); private set
    var busy by mutableStateOf(false); private set
    var byeMinutes by mutableStateOf<Int?>(null); private set

    var work by mutableStateOf<List<WorkOrder>>(emptyList()); private set
    var board by mutableStateOf<List<Machine>>(emptyList()); private set
    var orders by mutableStateOf<List<MgrOrder>>(emptyList()); private set
    var convs by mutableStateOf<List<Conversation>>(emptyList()); private set
    var shop by mutableStateOf(ShopState()); private set
    var supplies by mutableStateOf<List<Supply>>(emptyList()); private set
    var tick by mutableStateOf(0); private set

    private var firstPin = ""
    private var liveJob: Job? = null

    val role get() = me?.role ?: ""
    val isMgr get() = role == "admin" || role == "manager"
    fun name(id: String?) = staff.firstOrNull { it.id == id }?.fullName?.substringBefore(' ') ?: "—"

    fun boot() = viewModelScope.launch {
        if (Pro.uid == null) { stage = Stage.Login; return@launch }
        try {
            val p = Pro.me()
            if (p == null || p.role == "client" || !p.active) { Pro.signOut(); error = Pro.NOT_STAFF; stage = Stage.Login; return@launch }
            if (com.mydtf.client.BuildConfig.ADMIN && p.role != "admin") { Pro.signOut(); error = ADMIN_ONLY; stage = Stage.Login; return@launch }
            me = p
            staff = runCatching { Pro.staff() }.getOrDefault(emptyList())
            if (p.role == "admin") { enter(); return@launch }
            val st = Pro.pinStatus()
            if (st.clockedIn) { since = st.since; enter(); return@launch }
            stage = if (st.hasPin) Stage.ClockIn else Stage.PinSetup
        } catch (e: Exception) { error = friendlyError(e); stage = Stage.Login }
    }

    fun login(email: String, password: String) = viewModelScope.launch {
        busy = true; error = null
        try {
            val p = Pro.signIn(email.trim(), password)
            if (com.mydtf.client.BuildConfig.ADMIN && p.role != "admin") { Pro.signOut(); error = ADMIN_ONLY } else { stage = Stage.Loading; boot() }
        } catch (e: Exception) { error = if (e.message == Pro.NOT_STAFF) Pro.NOT_STAFF else friendlyError(e) }
        busy = false
    }

    private fun pinFail(msg: String) { pinError = msg; pinShake++ }

    fun onPin(pin: String) = viewModelScope.launch {
        pinError = null
        when (stage) {
            Stage.PinSetup -> { firstPin = pin; stage = Stage.PinConfirm }
            Stage.PinConfirm -> if (pin != firstPin) { stage = Stage.PinSetup; pinFail("الرمزان غير متطابقين، أعد المحاولة") } else {
                try { Pro.pinSet(pin); stage = Stage.ClockIn } catch (e: Exception) { pinFail(friendlyError(e)) }
            }
            Stage.ClockIn -> try { val a = Pro.clockIn(pin); since = a.clockIn; enter() } catch (e: Exception) { pinFail(friendlyError(e)) }
            else -> {}
        }
    }

    fun clockOut(pin: String, done: () -> Unit) = viewModelScope.launch {
        try { val a = Pro.clockOut(pin); byeMinutes = a.minutes; Pro.stopLive(); liveJob?.cancel(); liveJob = null; stage = Stage.Bye; done() }
        catch (e: Exception) { pinFail(friendlyError(e)) }
    }

    fun logout() = viewModelScope.launch { Pro.stopLive(); liveJob?.cancel(); liveJob = null; Pro.signOut(); me = null; stage = Stage.Login }

    @OptIn(FlowPreview::class)
    private fun enter() {
        stage = Stage.App
        refresh()
        if (liveJob == null) liveJob = viewModelScope.launch {
            launch { runCatching { Pro.live().debounce(500).collect { refresh() } } }
            while (isActive) { delay(45_000); refresh() }
        }
    }

    fun refresh() = viewModelScope.launch {
        runCatching { work = Pro.workOrders() }
        runCatching { board = Pro.board() }
        runCatching { shop = Pro.shop() }
        runCatching { supplies = Pro.supplies() }
        if (isMgr) { runCatching { orders = Pro.mgrOrders() }; runCatching { convs = Pro.conversations() } }
        tick++
    }

    /** Exécute une action et rafraîchit ; renvoie l'erreur éventuelle au callback. */
    fun act(ok: String? = null, onDone: (String?) -> Unit = {}, block: suspend () -> Unit) = viewModelScope.launch {
        busy = true
        val err = try { block(); null } catch (e: Exception) { friendlyError(e) }
        busy = false
        if (err == null) refresh()
        onDone(err)
    }
}
