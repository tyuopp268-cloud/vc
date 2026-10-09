package com.example.voice_changer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.Process
import kotlin.math.PI
import kotlin.math.sin

class AudioService : Service() {

    companion object {
        const val ACTION_SET_EFFECTS = "voice_changer.SET_EFFECTS"

        private const val CHANNEL_ID = "voice_lab_audio"
        private const val NOTIFICATION_ID = 1001

        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_MASK = AudioFormat.CHANNEL_IN_MONO
        private const val OUTPUT_CHANNEL_MASK = AudioFormat.CHANNEL_OUT_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    @Volatile
    private var running = false

    @Volatile
    private var pitch = 0.0

    @Volatile
    private var robot = 0.0

    @Volatile
    private var echo = 0.0

    @Volatile
    private var gain = 1.0

    private var audioThread: Thread? = null
    private var recorder: AudioRecord? = null
    private var player: AudioTrack? = null

    private var echoBuffer = FloatArray(SAMPLE_RATE / 4)
    private var echoPosition = 0
    private var phase = 0.0
    private var filterState = 0.0

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        if (intent?.action == ACTION_SET_EFFECTS) {
            pitch = intent.getDoubleExtra("pitch", 0.0)
            robot = intent.getDoubleExtra("robot", 0.0)
            echo = intent.getDoubleExtra("echo", 0.0)
            gain = intent.getDoubleExtra("gain", 1.0)
            return START_NOT_STICKY
        }

        if (!running) {
            startAudio()
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Voice Lab Audio",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ไมโครโฟนและระบบประมวลผลเสียง"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Voice Lab")
            .setContentText("กำลังประมวลผลเสียงจากไมโครโฟน")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .build()
    }

    private fun promoteToForeground() {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startAudio() {
        try {
            promoteToForeground()

            val inputBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_MASK,
                AUDIO_FORMAT
            )

            val outputBufferSize = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                OUTPUT_CHANNEL_MASK,
                AUDIO_FORMAT
            )

            if (inputBufferSize <= 0 || outputBufferSize <= 0) {
                stopSelf()
                return
            }

            val bufferSize = maxOf(
                inputBufferSize,
                outputBufferSize,
                4096
            )

            val input = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_MASK,
                AUDIO_FORMAT,
                bufferSize
            )

            val output = AudioTrack(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setEncoding(AUDIO_FORMAT)
                    .setChannelMask(OUTPUT_CHANNEL_MASK)
                    .build(),
                bufferSize,
                AudioTrack.MODE_STREAM,
                AudioTrack.AUDIO_SESSION_ID_GENERATE
            )

            if (input.state != AudioRecord.STATE_INITIALIZED ||
                output.state != AudioTrack.STATE_INITIALIZED
            ) {
                input.release()
                output.release()
                stopSelf()
                return
            }

            recorder = input
            player = output
            running = true

            audioThread = Thread {
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

                val inputData = ShortArray(bufferSize / 2)
                val outputData = ShortArray(bufferSize / 2)

                try {
                    input.startRecording()
                    output.play()

                    while (running) {
                        val count = input.read(
                            inputData,
                            0,
                            inputData.size,
                            AudioRecord.READ_BLOCKING
                        )

                        if (count <= 0) continue

                        for (i in 0 until count) {
                            var sample = inputData[i] / 32768.0

                            val tone = pitch.coerceIn(-10.0, 10.0)
                            val alpha = (
                                0.08 + (tone + 10.0) / 20.0 * 0.88
                            ).coerceIn(0.08, 0.96)

                            filterState += alpha * (sample - filterState)
                            sample = filterState

                            val robotAmount =
                                (robot / 100.0).coerceIn(0.0, 1.0)

                            val oscillator = sin(phase)
                            phase += 2.0 * PI * 35.0 / SAMPLE_RATE

                            if (phase >= 2.0 * PI) {
                                phase -= 2.0 * PI
                            }

                            val roboticSample = sample * oscillator
                            sample = sample * (1.0 - robotAmount) +
                                roboticSample * robotAmount

                            val delayed = echoBuffer[echoPosition]
                            val echoAmount =
                                (echo / 100.0).coerceIn(0.0, 1.0)

                            echoBuffer[echoPosition] =
                                (sample + delayed * 0.45f).toFloat()

                            echoPosition++
                            if (echoPosition >= echoBuffer.size) {
                                echoPosition = 0
                            }

                            sample += delayed * echoAmount
                            sample *= gain.coerceIn(0.0, 2.0)

                            val clipped = sample.coerceIn(-1.0, 1.0)
                            outputData[i] = (clipped * 32767.0).toInt()
                                .toShort()
                        }

                        output.write(
                            outputData,
                            0,
                            count,
                            AudioTrack.WRITE_BLOCKING
                        )
                    }
                } catch (_: Exception) {
                } finally {
                    try {
                        if (input.recordingState ==
                            AudioRecord.RECORDSTATE_RECORDING
                        ) {
                            input.stop()
                        }
                    } catch (_: Exception) {
                    }

                    try {
                        output.pause()
                        output.flush()
                        output.stop()
                    } catch (_: Exception) {
                    }

                    input.release()
                    output.release()
                }
            }.apply {
                name = "VoiceLabAudioThread"
                start()
            }
        } catch (_: SecurityException) {
            running = false
            stopSelf()
        } catch (_: Exception) {
            running = false
            stopSelf()
        }
    }

    private fun stopAudio() {
        running = false

        try {
            recorder?.stop()
        } catch (_: Exception) {
        }

        try {
            player?.pause()
        } catch (_: Exception) {
        }

        try {
            audioThread?.join(500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }

        recorder = null
        player = null
        audioThread = null
    }

    override fun onDestroy() {
        stopAudio()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
