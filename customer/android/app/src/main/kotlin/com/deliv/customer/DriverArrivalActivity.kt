package com.deliv.customer

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.bumptech.glide.Glide
import java.util.Locale

class DriverArrivalActivity : Activity() {

    private var ringtone: Ringtone? = null
    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var secondsLeft = 60

    private val countdownRunnable = object : Runnable {
        override fun run() {
            secondsLeft--
            val tv = findViewById<TextView>(R.id.tvCountdown)
            if (tv != null) tv.text = String.format(Locale.US, "%ds", secondsLeft)
            if (secondsLeft > 0) {
                handler.postDelayed(this, 1000)
            } else {
                dismiss()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("DriverArrivalActivity", "onCreate called, intent extras: ${intent.extras}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_driver_arrival)

        val driverName = intent.getStringExtra("driverName") ?: "السائق"
        val driverPhoto = intent.getStringExtra("driverPhoto") ?: ""

        findViewById<TextView>(R.id.tvDriverName).text = driverName

        if (driverPhoto.isNotEmpty()) {
            Glide.with(this)
                .load(driverPhoto)
                .circleCrop()
                .into(findViewById(R.id.ivDriver))
        }

        findViewById<Button>(R.id.btnClose).setOnClickListener {
            dismiss()
        }

        startRingtone()
        handler.postDelayed(countdownRunnable, 1000)
    }

    private fun startRingtone() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
            if (ringtone == null) {
                playAssetAlarm()
                return
            }
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone?.play()
        } catch (_: Exception) {
            playAssetAlarm()
        }
    }

    private fun playAssetAlarm() {
        try {
            val afd = assets.openFd("Alarm.mp3")
            mediaPlayer = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {}
    }

    private fun dismiss() {
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        try { mediaPlayer?.stop(); mediaPlayer?.release() } catch (_: Exception) {}
        ringtone = null
        mediaPlayer = null
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        try { mediaPlayer?.stop(); mediaPlayer?.release() } catch (_: Exception) {}
        ringtone = null
        mediaPlayer = null
    }
}
