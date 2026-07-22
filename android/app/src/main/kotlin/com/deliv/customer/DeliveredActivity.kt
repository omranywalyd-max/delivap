package com.deliv.customer

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
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
import org.json.JSONObject

class DeliveredActivity : Activity() {

    private var ringtone: android.media.Ringtone? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isConfirmed = false

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

        setContentView(R.layout.activity_delivered)

        val driverName = intent.getStringExtra("driverName") ?: "السائق"
        val driverPhoto = intent.getStringExtra("driverPhoto") ?: ""
        val orderId = intent.getStringExtra("orderId") ?: ""

        findViewById<TextView>(R.id.tvDriverName).text = driverName

        if (driverPhoto.isNotEmpty()) {
            Glide.with(this)
                .load(driverPhoto)
                .circleCrop()
                .into(findViewById(R.id.ivDriver))
        }

        val btnConfirm = findViewById<Button>(R.id.btnConfirm)
        val tvStatus = findViewById<TextView>(R.id.tvStatus)

        btnConfirm.setOnClickListener {
            if (isConfirmed) return@setOnClickListener
            isConfirmed = true
            tvStatus.text = "جاري التأكيد..."
            tvStatus.visibility = View.VISIBLE
            btnConfirm.isEnabled = false
            confirmDelivery(orderId)
        }

        playNotificationSound()
    }

    private fun confirmDelivery(orderId: String) {
        Thread {
            try {
                val user = FirebaseAuth.getInstance().currentUser
                val token = user?.getIdToken(false)?.result?.token
                val userId = user?.uid ?: ""

                // 1. Update order: customerConfirmed = true
                val orderUrl = URL("https://api.delivap.com/api/orders/$orderId")
                val orderConn = orderUrl.openConnection() as HttpURLConnection
                orderConn.requestMethod = "PUT"
                orderConn.setRequestProperty("Content-Type", "application/json")
                if (token != null) {
                    orderConn.setRequestProperty("Authorization", "Bearer $token")
                }
                orderConn.doOutput = true

                val orderBody = JSONObject().apply {
                    put("customerConfirmed", true)
                    put("hiddenFor", org.json.JSONArray().apply { put(userId) })
                }
                orderConn.outputStream.use { os ->
                    os.write(orderBody.toString().toByteArray())
                }
                orderConn.responseCode
                orderConn.disconnect()

                // 2. Update loyalty: add loyalty point
                if (orderId.isNotEmpty() && userId.isNotEmpty()) {
                    try {
                        val loyaltyUrl = URL("https://api.delivap.com/api/users/$userId/loyalty")
                        val loyaltyConn = loyaltyUrl.openConnection() as HttpURLConnection
                        loyaltyConn.requestMethod = "PUT"
                        loyaltyConn.setRequestProperty("Content-Type", "application/json")
                        if (token != null) {
                            loyaltyConn.setRequestProperty("Authorization", "Bearer $token")
                        }
                        loyaltyConn.doOutput = true

                        val loyaltyBody = JSONObject().apply {
                            put("driverId", intent.getStringExtra("driverId") ?: "")
                        }
                        loyaltyConn.outputStream.use { os ->
                            os.write(loyaltyBody.toString().toByteArray())
                        }
                        loyaltyConn.responseCode
                        loyaltyConn.disconnect()
                    } catch (_: Exception) {}
                }

                handler.post {
                    val tvStatus = findViewById<TextView>(R.id.tvStatus)
                    tvStatus.text = "تم التأكيد ✅"
                    tvStatus.visibility = View.VISIBLE
                    handler.postDelayed({ dismiss() }, 2000)
                }
            } catch (_: Exception) {
                handler.post {
                    val tvStatus = findViewById<TextView>(R.id.tvStatus)
                    tvStatus.text = "تم التأكيد ✅"
                    tvStatus.visibility = View.VISIBLE
                    handler.postDelayed({ dismiss() }, 2000)
                }
            }
        }.start()
    }

    private fun playNotificationSound() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone?.play()
        } catch (_: Exception) {}
    }

    private fun dismiss() {
        handler.removeCallbacksAndMessages(null)
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
    }
}
