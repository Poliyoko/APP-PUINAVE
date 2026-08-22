package org.sgoda.sgoda_puinave_demo

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "org.sgoda/audio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "play" -> {
                    val url = call.argument<String>("url")

                    if (url.isNullOrBlank()) {
                        result.error(
                            "INVALID_URL",
                            "Audio URL is empty.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        stopPlayer()

                        val player = MediaPlayer()

                        player.setAudioAttributes(
                            AudioAttributes.Builder()
                                .setContentType(
                                    AudioAttributes.CONTENT_TYPE_SPEECH
                                )
                                .setUsage(
                                    AudioAttributes.USAGE_MEDIA
                                )
                                .build()
                        )

                        player.setDataSource(url)

                        player.setOnPreparedListener {
                            it.start()
                        }

                        player.setOnCompletionListener {
                            stopPlayer()
                        }

                        player.setOnErrorListener { _, what, extra ->
                            stopPlayer()
                            true
                        }

                        mediaPlayer = player
                        player.prepareAsync()

                        result.success(null)
                    }
                    catch (ex: Exception) {
                        stopPlayer()

                        result.error(
                            "AUDIO_ERROR",
                            ex.message,
                            null
                        )
                    }
                }

                "stop" -> {
                    stopPlayer()
                    result.success(null)
                }

                "dispose" -> {
                    stopPlayer()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun stopPlayer() {
        val player = mediaPlayer

        if (player != null) {
            try {
                if (player.isPlaying) {
                    player.stop()
                }
            }
            catch (_: Exception) {
            }

            try {
                player.reset()
            }
            catch (_: Exception) {
            }

            try {
                player.release()
            }
            catch (_: Exception) {
            }
        }

        mediaPlayer = null
    }

    override fun onDestroy() {
        stopPlayer()
        super.onDestroy()
    }
}