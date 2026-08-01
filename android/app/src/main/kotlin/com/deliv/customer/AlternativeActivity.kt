package com.deliv.customer

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.bumptech.glide.Glide
import com.google.firebase.auth.FirebaseAuth
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import org.json.JSONObject
import org.json.JSONArray

class AlternativeActivity : Activity() {

    private var ringtone: android.media.Ringtone? = null
    private val handler = Handler(Looper.getMainLooper())
    private var secondsLeft = 120
    private var isResponded = false

    private val countdownRunnable = object : Runnable {
        override fun run() {
            secondsLeft--
            val tv = findViewById<TextView>(R.id.tvCountdown)
            if (tv != null) {
                val min = secondsLeft / 60
                val sec = secondsLeft % 60
                tv.text = String.format(Locale.US, "%02d:%02d", min, sec)
            }
            if (secondsLeft > 0) {
                handler.postDelayed(this, 1000)
            } else {
                dismiss()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

        setContentView(R.layout.activity_product_alternative)

        val driverName = intent.getStringExtra("driverName") ?: "السائق"
        val driverPhoto = intent.getStringExtra("driverPhoto") ?: ""
        val productName = intent.getStringExtra("productName") ?: ""
        val alternativeName = intent.getStringExtra("alternativeName") ?: ""
        val alternativePrice = intent.getStringExtra("alternativePrice") ?: ""
        val orderId = intent.getStringExtra("orderId") ?: ""

        findViewById<TextView>(R.id.tvDriverName).text = driverName
        findViewById<TextView>(R.id.tvOriginalProduct).text = "المنتج الأصلي: $productName"
        findViewById<TextView>(R.id.tvAlternativeName).text = alternativeName
        findViewById<TextView>(R.id.tvAlternativePrice).text = "$alternativePrice DZD"

        if (driverPhoto.isNotEmpty()) {
            Glide.with(this)
                .load(driverPhoto)
                .circleCrop()
                .into(findViewById(R.id.ivDriver))
        }

        val btnAccept = findViewById<Button>(R.id.btnAccept)
        val btnReject = findViewById<Button>(R.id.btnReject)
        val tvStatus = findViewById<TextView>(R.id.tvStatus)

        btnAccept.setOnClickListener {
            if (isResponded) return@setOnClickListener
            isResponded = true
            tvStatus.text = "جاري القبول..."
            tvStatus.visibility = View.VISIBLE
            btnAccept.isEnabled = false
            btnReject.isEnabled = false
            respondToAlternative(orderId, "accepted")
        }

        btnReject.setOnClickListener {
            if (isResponded) return@setOnClickListener
            isResponded = true
            tvStatus.text = "جاري الرفض..."
            tvStatus.visibility = View.VISIBLE
            btnAccept.isEnabled = false
            btnReject.isEnabled = false
            respondToAlternative(orderId, "rejected")
        }

        startRingtone()
        handler.postDelayed(countdownRunnable, 1000)
    }

    private fun respondToAlternative(orderId: String, status: String) {
        Thread {
            try {
                val user = FirebaseAuth.getInstance().currentUser
                val token = user?.getIdToken(false)?.result?.token

                val url = URL("https://api.delivap.com/api/orders/$orderId")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "PUT"
                conn.setRequestProperty("Content-Type", "application/json")
                if (token != null) {
                    conn.setRequestProperty("Authorization", "Bearer $token")
                }
                conn.doOutput = true

                val body = JSONObject().apply {
                    put("items", JSONArray().apply {
                        put(JSONObject().apply {
                            put("alternativeStatus", status)
                        })
                    })
                }

                conn.outputStream.use { os ->
                    os.write(body.toString().toByteArray())
                }

                val responseCode = conn.responseCode
                handler.post {
                    if (responseCode == 200 || responseCode == 201) {
                        val tvStatus = findViewById<TextView>(R.id.tvStatus)
                        tvStatus.text = if (status == "accepted") "تم القبول ✅" else "تم الرفض ❌"
                        tvStatus.visibility = View.VISIBLE
                        handler.postDelayed({ dismiss() }, 2000)
                    } else {
                        val tvStatus = findViewById<TextView>(R.id.tvStatus)
                        tvStatus.text = "حدث خطأ، حاول مرة أخرى"
                        tvStatus.visibility = View.VISIBLE
                        isResponded = false
                        findViewById<Button>(R.id.btnAccept).isEnabled = true
                        findViewById<Button>(R.id.btnReject).isEnabled = true
                    }
                }
                conn.disconnect()
            } catch (e: Exception) {
                handler.post {
                    val tvStatus = findViewById<TextView>(R.id.tvStatus)
                    tvStatus.text = "حدث خطأ: ${e.message}"
                    tvStatus.visibility = View.VISIBLE
                    isResponded = false
                    findViewById<Button>(R.id.btnAccept).isEnabled = true
                    findViewById<Button>(R.id.btnReject).isEnabled = true
                }
            }
        }.start()
    }

    private fun startRingtone() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone?.play()
        } catch (_: Exception) {}
    }

    private fun dismiss() {
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
    }
}
