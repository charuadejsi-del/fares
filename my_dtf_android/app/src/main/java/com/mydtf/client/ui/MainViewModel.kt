package com.mydtf.client.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.mydtf.client.data.AppNotification
import com.mydtf.client.data.ChatMessage
import com.mydtf.client.data.NewProfileInput
import com.mydtf.client.data.Order
import com.mydtf.client.data.Profile
import com.mydtf.client.data.Repo
import com.mydtf.client.data.Settings
import com.mydtf.client.data.friendlyError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/** État partagé de la session client : profil, commandes (avec cache hors ligne), chat, notifications. */
class MainViewModel(app: Application) : AndroidViewModel(app) {
    var profile by mutableStateOf<Profile?>(null); private set
    var needsProfile by mutableStateOf(false); private set
    var staffBlocked by mutableStateOf(false)
    var settings by mutableStateOf<Settings?>(null); private set
    var orders by mutableStateOf<List<Order>>(emptyList()); private set
    var notifications by mutableStateOf<List<AppNotification>>(emptyList()); private set
    var messages by mutableStateOf<List<ChatMessage>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var offline by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var liveTick by mutableStateOf(0); private set

    val unread: Int get() = notifications.count { !it.read }
    val unreadChat: Int get() = messages.count { it.fromStaff && !it.readByClient }

    private val json = Json { ignoreUnknownKeys = true }
    private fun cacheFile() = File(getApplication<Application>().filesDir, "orders_${Repo.uid ?: "x"}.json")

    private var liveJob: Job? = null
    private var pollJob: Job? = null

    fun start() {
        if (liveJob != null) return
        viewModelScope.launch {
            loading = true
            loadCache()
            load()
            loading = false
        }
        liveJob = viewModelScope.launch { listenLive() }
        pollJob = viewModelScope.launch {
            while (isActive) { delay(45_000); load(silent = true) }
        }
    }

    fun stop() {
        liveJob?.cancel(); liveJob = null
        pollJob?.cancel(); pollJob = null
        viewModelScope.launch { Repo.stopLive() }
        profile = null; needsProfile = false; orders = emptyList(); notifications = emptyList(); messages = emptyList()
    }

    @OptIn(FlowPreview::class)
    private suspend fun listenLive() {
        runCatching { Repo.liveChanges().debounce(400).collect { load(silent = true); liveTick++ } }
    }

    fun refresh() {
        viewModelScope.launch { refreshing = true; load(); refreshing = false }
    }

    private suspend fun load(silent: Boolean = false) {
        try {
            if (profile == null) {
                val p = Repo.ensureProfile()
                if (p != null && p.role != "client") {
                    // session restaurée d'un compte équipe : interdit dans l'app client
                    staffBlocked = true
                    StaffFlag.blocked = true
                    runCatching { Repo.signOut() }
                    return
                }
                profile = p
                needsProfile = profile == null
            }
            settings = Repo.settings()
            orders = Repo.myOrders()
            notifications = Repo.notifications()
            messages = Repo.messages()
            offline = false
            error = null
            saveCache()
        } catch (e: Exception) {
            offline = true
            if (!silent && orders.isEmpty()) error = friendlyError(e)
        }
    }

    // ---------- cache hors ligne des commandes ----------
    private suspend fun loadCache() = withContext(Dispatchers.IO) {
        runCatching {
            val f = cacheFile()
            if (f.exists() && orders.isEmpty()) orders = json.decodeFromString(ListSerializer(Order.serializer()), f.readText())
        }
    }

    private suspend fun saveCache() = withContext(Dispatchers.IO) {
        runCatching { cacheFile().writeText(json.encodeToString(ListSerializer(Order.serializer()), orders)) }
    }

    // ---------- profil ----------
    suspend fun completeProfile(p: NewProfileInput) {
        Repo.createProfile(p)
        profile = Repo.myProfile()
        needsProfile = profile == null
        load(silent = true)
    }

    fun reloadProfile() = viewModelScope.launch { runCatching { profile = Repo.myProfile() } }
    fun reloadSettings() = viewModelScope.launch { runCatching { settings = Repo.settings() } }

    // ---------- chat ----------
    suspend fun send(body: String, orderId: String?) {
        Repo.sendMessage(body, orderId)
        messages = Repo.messages()
    }

    fun markChatRead() {
        if (unreadChat == 0) return
        messages = messages.map { it.copy(readByClient = true) }
        viewModelScope.launch { runCatching { Repo.markChatRead() } }
    }

    // ---------- notifications ----------
    fun markRead(n: AppNotification) {
        if (n.read) return
        notifications = notifications.map { if (it.id == n.id) it.copy(read = true) else it }
        viewModelScope.launch { runCatching { Repo.markRead(n.id) } }
    }

    fun markAllRead() {
        notifications = notifications.map { it.copy(read = true) }
        viewModelScope.launch { runCatching { Repo.markAllRead() } }
    }

    fun signOut(done: () -> Unit) {
        viewModelScope.launch {
            stop()
            runCatching { Repo.signOut() }
            done()
        }
    }
}

/** Mémorise qu'un compte équipe a été refusé, pour l'afficher sur l'écran de connexion. */
object StaffFlag { var blocked = false }
