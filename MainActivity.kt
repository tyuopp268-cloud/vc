package com.example.voice_changer

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "voice_changer/audio"
    private val requestMicCode = 701
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "startAudio" -> {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            requestMicCode
                        )
                    } else {
                        startAudioService(result)
                    }
                }

                "stopAudio" -> {
                    stopService(Intent(this, AudioService::class.java))
                    result.success(true)
                }

                "setEffects" -> {
                    val intent = Intent(this, AudioService::class.java).apply {
                        action = AudioService.ACTION_SET_EFFECTS
                        putExtra("pitch", call.argument<Double>("pitch") ?: 0.0)
                        putExtra("robot", call.argument<Double>("robot") ?: 0.0)
                        putExtra("echo", call.argument<Double>("echo") ?: 0.0)
                        putExtra("gain", call.argument<Double>("gain") ?: 1.0)
                    }

                    startService(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, AudioService::class.java)
            ContextCompat.startForegroundService(this, intent)
            result.success(true)
        } catch (e: Exception) {
            result.error(
                "AUDIO_START_FAILED",
                e.message ?: "ไม่สามารถเริ่มระบบเสียงได้",
                null
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == requestMicCode) {
            val result = pendingResult
            pendingResult = null

            if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            ) {
                if (result != null) {
                    startAudioService(result)
                }
            } else {
                result?.error(
                    "MIC_PERMISSION_DENIED",
                    "กรุณาอนุญาตให้แอปใช้ไมโครโฟน",
                    null
                )
            }
        }
    }
}
