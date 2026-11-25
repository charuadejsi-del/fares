package com.khazna.agora

import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/** صوت Agora داخل Godot: انضمام لقناة، كتم، ومغادرة. الإشارات تصل إلى GDScript. */
class GodotAgora(godot: Godot) : GodotPlugin(godot) {
    private var engine: RtcEngine? = null
    private var users = 0

    override fun getPluginName() = "GodotAgora"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("joined"),
        SignalInfo("users", Integer::class.javaObjectType),
        SignalInfo("speaking", String::class.java),
        SignalInfo("voice_error", String::class.java),
    )

    private val handler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            emitSignal("joined")
        }
        override fun onUserJoined(uid: Int, elapsed: Int) {
            users++
            emitSignal("users", users)
        }
        override fun onUserOffline(uid: Int, reason: Int) {
            users = maxOf(0, users - 1)
            emitSignal("users", users)
        }
        override fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {
            var me = false
            var other = false
            speakers?.forEach { if (it.volume > 25) { if (it.uid == 0) me = true else other = true } }
            emitSignal("speaking", (if (me) "1" else "0") + (if (other) "1" else "0"))
        }
        override fun onError(err: Int) {
            emitSignal("voice_error", "Agora error $err")
        }
    }

    @UsedByGodot
    fun join(appId: String, token: String, channel: String) {
        val act = activity ?: return
        act.runOnUiThread {
            try {
                if (engine == null) {
                    val cfg = RtcEngineConfig()
                    cfg.mContext = act.applicationContext
                    cfg.mAppId = appId
                    cfg.mEventHandler = handler
                    engine = RtcEngine.create(cfg)
                    engine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                    engine?.enableAudio()
                    engine?.setDefaultAudioRoutetoSpeakerphone(true)
                    engine?.enableAudioVolumeIndication(300, 3, false)
                }
                val opts = ChannelMediaOptions()
                opts.autoSubscribeAudio = true
                opts.publishMicrophoneTrack = true
                opts.clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
                engine?.joinChannel(if (token.isEmpty()) null else token, channel, 0, opts)
            } catch (e: Exception) {
                emitSignal("voice_error", e.message ?: "voice failed")
            }
        }
    }

    /** رابط الفتح (مثل khazna3d://join?code=1234) القادم من تطبيق الخزنة الأصلي. */
    @UsedByGodot
    fun intent_data(): String {
        return activity?.intent?.dataString ?: ""
    }

    @UsedByGodot
    fun mute(m: Boolean) {
        engine?.muteLocalAudioStream(m)
    }

    @UsedByGodot
    fun leave() {
        engine?.leaveChannel()
        RtcEngine.destroy()
        engine = null
        users = 0
    }
}
