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
    private var isConfirming = false
    private var orderId = ""

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
        orderId = intent.getStringExtra("orderId") ?: ""

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
            if (isConfirming) return@setOnClickListener
            isConfirming = true
            tvStatus.text = "جاري التأكيد..."
            tvStatus.visibility = View.VISIBLE
            btnConfirm.isEnabled = false
            confirmDelivery(orderId)
        }

        playNotificationSound()
    }

    private fun confirmDelivery(orderId: String) {
        if (orderId.isEmpty()) {
            showResult("فشل التأكيد: لا يوجد معرّف الطلبية", success = false)
            return
        }
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            showResult("فشل التأكيد: غير متصل، أعد فتح التطبيق وحاول", success = false)
            return
        }
        // نحاول بالتوكن المحلي، وإن فشل نجربو التحديث (refresh)
        user.getIdToken(false)
            .addOnSuccessListener { result ->
                val token = result.token
                if (token != null) {
                    Thread { confirmDeliveryRequest(orderId, token) }.start()
                } else {
                    showResult("فشل التأكيد: توكن غير صالح", success = false)
                }
            }
            .addOnFailureListener {
                user.getIdToken(true)
                    .addOnSuccessListener { result ->
                        val token = result.token
                        if (token != null) {
                            Thread { confirmDeliveryRequest(orderId, token) }.start()
                        } else {
                            showResult("فشل التأكيد: توكن غير صالح", success = false)
                        }
                    }
                    .addOnFailureListener {
                        showResult("فشل التأكيد: تعذّر تحديث الجلسة", success = false)
                    }
            }
    }

    private fun confirmDeliveryRequest(orderId: String, token: String) {
        try {
            val url = URL("https://api.delivap.com/api/orders/$orderId")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "PUT"
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.doOutput = true

            val body = JSONObject().apply { put("customerConfirmed", true) }
            conn.outputStream.use { os -> os.write(body.toString().toByteArray()) }
            val code = conn.responseCode
            conn.disconnect()

            val success = code in 200..299
            showResult(if (success) "تم التأكيد ✅" else "فشل التأكيد (رمز $code)", success = success)
        } catch (e: Exception) {
            showResult("فشل التأكيد: ${e.message ?: "خطأ في الاتصال"}", success = false)
        }
    }

    private fun showResult(message: String, success: Boolean) {
        handler.post {
            val tvStatus = findViewById<TextView>(R.id.tvStatus)
            tvStatus.text = message
            tvStatus.visibility = View.VISIBLE
            if (success) {
                handler.postDelayed({ dismiss() }, 2000)
            } else {
                isConfirming = false
                val btnConfirm = findViewById<Button>(R.id.btnConfirm)
                btnConfirm.isEnabled = true
                btnConfirm.text = "إعادة المحاولة"
            }
        }
    }

    private fun playNotificationSound() {
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
