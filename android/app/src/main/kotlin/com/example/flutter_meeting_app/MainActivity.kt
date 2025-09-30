package com.example.flutter_meeting_app

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.flutter_meeting_app/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSpeakerphoneOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    result.success(handleSpeakerphone(enable))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSpeakerphone(enable: Boolean): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false

        return try {
            // Reset possible conflicting routes before enforcing speakerphone
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false

            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

            if (enable) {
                audioManager.isSpeakerphoneOn = false
                audioManager.isSpeakerphoneOn = true
                audioManager.adjustVolume(AudioManager.ADJUST_SAME, AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE)
            } else {
                audioManager.isSpeakerphoneOn = false
            }
            true
        } catch (error: Exception) {
            false
        }
    }
}
