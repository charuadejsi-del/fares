package com.mydtf.client.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mydtf.client.data.AppNotification
import com.mydtf.client.data.Order
import com.mydtf.client.data.Profile
import com.mydtf.client.data.Repo
import com.mydtf.client.data.Settings
import com.mydtf.client.data.friendlyError
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.FlowPreview

/** État partagé de la session client : profil, commandes, notifications, paramètres. */
class MainViewModel : ViewModel() {
    var profile by mutableStateOf<Profile?>(null); private set
    var settings by mutableStateOf<Settings?>(null); private set
    var orders by mutableStateOf<List<Order>>(emptyList()); private set
    var notifications by mutableStateOf<List<AppNotification>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    /** Incrémenté à chaque changement en direct : les écrans de détail s'y abonnent. */
    var liveTick by mutableStateOf(0); private set

    val unread: Int get() = notifications.count { !it.read }

    private var liveJob: Job? = null
    private var pollJob: Job? = null

    fun start() {
        if (liveJob != null) return
        viewModelScope.launch {
            loading = true
            load()
            loading = false
        }
        liveJob = viewModelScope.launch { listenLive() }
        // filet de sécurité si le temps réel est coupé (réseau mobile)
        pollJob = viewModelScope.launch {
            while (isActive) {
                delay(45_000)
                load(silent = true)
            }
        }
    }

    fun stop() {
        liveJob?.cancel(); liveJob = null
        pollJob?.cancel(); pollJob = null
        viewModelScope.launch { Repo.stopLive() }
        profile = null; orders = emptyList(); notifications = emptyList()
    }

    @OptIn(FlowPreview::class)
    private suspend fun listenLive() {
        runCatching {
            Repo.liveChanges().debounce(400).collect {
                load(silent = true)
                liveTick++
            }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            refreshing = true
            load()
            refreshing = false
        }
    }

    private suspend fun load(silent: Boolean = false) {
        try {
            if (profile == null) profile = Repo.ensureProfile()
            if (settings == null) settings = Repo.settings()
            orders = Repo.myOrders()
            notifications = Repo.notifications()
            error = null
        } catch (e: Exception) {
            if (!silent) error = friendlyError(e)
        }
    }

    fun reloadProfile() = viewModelScope.launch { runCatching { profile = Repo.myProfile() } }
    fun reloadSettings() = viewModelScope.launch { runCatching { settings = Repo.settings() } }

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
