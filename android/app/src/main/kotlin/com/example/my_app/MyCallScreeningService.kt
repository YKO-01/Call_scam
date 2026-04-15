package com.example.my_app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors

private const val TAG = "CALL_DEBUG"

class MyCallScreeningService : CallScreeningService() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onScreenCall(callDetails: Call.Details) {
        try {
            Log.d(TAG, "1) onScreenCall triggered")
            Log.d(TAG, "2) details is null: false (non-null API contract)")

            // We do not block calls; we only warn via overlay.
            respondToCall(
                callDetails,
                CallResponse.Builder()
                    .setDisallowCall(false)
                    .setRejectCall(false)
                    .setSkipCallLog(false)
                    .setSkipNotification(false)
                    .build(),
            )

            val incomingNumber = callDetails.handle?.schemeSpecificPart.orEmpty()
            Log.d(TAG, "3) Extracted phone number: $incomingNumber")
            if (incomingNumber.isBlank()) {
                Log.d(TAG, "4) Incoming number is blank -> stopping flow")
                return
            }

            executor.execute {
                try {
                    Log.d(TAG, "5) Starting async API check for number=$incomingNumber")
                    Log.d(TAG, "6) Before API call")
                    val apiResult = checkNumberRisk(incomingNumber)
                    Log.d(TAG, "7) After API call")

                    if (apiResult == null) {
                        Log.d(TAG, "8) API result is null (failed/invalid response) -> no overlay")
                        return@execute
                    }

                    Log.d(
                        TAG,
                        "9) API response parsed: risk=${apiResult.risk}, type=${apiResult.type}",
                    )

                    if (apiResult.risk > SPAM_RISK_THRESHOLD) {
                        Log.d(TAG, "10) Spam condition met (risk > $SPAM_RISK_THRESHOLD)")
                        Log.d(TAG, "11) Calling overlay function")
                        SpamOverlayController.show(
                            context = applicationContext,
                            phoneNumber = incomingNumber,
                            risk = apiResult.risk,
                        )
                    } else {
                        Log.d(TAG, "10) Spam condition NOT met (risk <= $SPAM_RISK_THRESHOLD)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error during async screening flow", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onScreenCall", e)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy called -> shutting down executor and dismissing overlay")
        executor.shutdownNow()
        SpamOverlayController.dismiss()
        super.onDestroy()
    }

    private fun checkNumberRisk(phone: String): RiskResponse? {
        var connection: HttpURLConnection? = null
        return try {
            val encoded = URLEncoder.encode(phone, Charsets.UTF_8.name())
            val url = URL("$API_BASE_URL$encoded")
            Log.d(TAG, "API request URL: $url")

            connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = API_TIMEOUT_MS
                readTimeout = API_TIMEOUT_MS
                doInput = true
            }

            val statusCode = connection.responseCode
            Log.d(TAG, "API HTTP status: $statusCode")
            if (statusCode != HttpURLConnection.HTTP_OK) {
                Log.d(TAG, "API returned non-200 -> no overlay")
                return null
            }

            val body = connection.inputStream.bufferedReader().use { it.readText() }
            Log.d(TAG, "API raw response body: $body")
            val json = JSONObject(body)
            val risk = json.optInt("risk", -1)
            if (risk < 0) {
                Log.d(TAG, "API response missing/invalid risk field")
                return null
            }

            RiskResponse(
                risk = risk,
                type = json.optString("type", "Unknown"),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Exception while calling API", e)
            null
        } finally {
            Log.d(TAG, "Disconnecting API connection")
            connection?.disconnect()
        }
    }

    data class RiskResponse(
        val risk: Int,
        val type: String,
    )

    companion object {
        private const val API_BASE_URL = "https://my-api.com/check?phone="
        private const val SPAM_RISK_THRESHOLD = 60
        private const val API_TIMEOUT_MS = 800
    }
}

private object SpamOverlayController {
    private const val OVERLAY_DURATION_MS = 6500L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var dismissRunnable: Runnable? = null

    private var telephonyManager: TelephonyManager? = null
    private var callStateListener: PhoneStateListener? = null

    fun show(context: Context, phoneNumber: String, risk: Int) {
        Log.d(TAG, "Overlay show requested for number=$phoneNumber, risk=$risk")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            Log.d(TAG, "Overlay permission missing -> cannot show overlay")
            return
        }

        mainHandler.post {
            try {
                Log.d(TAG, "Overlay creation started")
                dismissInternal()

                val appContext = context.applicationContext
                val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val view = LayoutInflater.from(appContext).inflate(R.layout.spam_warning_overlay, null)

                view.findViewById<TextView>(R.id.spamPhoneNumber).text = phoneNumber
                view.findViewById<TextView>(R.id.spamRiskValue).text = "Risk: $risk%"

                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                    PixelFormat.TRANSLUCENT,
                ).apply {
                    gravity = Gravity.TOP
                    y = 48
                }

                try {
                    wm.addView(view, params)
                } catch (e: Exception) {
                    Log.e(TAG, "WindowManager addView failed", e)
                    return@post
                }

                Log.d(TAG, "Overlay added to window successfully")
                windowManager = wm
                overlayView = view
                startCallStateMonitoring(appContext)

                dismissRunnable = Runnable { dismissInternal() }
                mainHandler.postDelayed(dismissRunnable!!, OVERLAY_DURATION_MS)
            } catch (e: Exception) {
                Log.e(TAG, "Overlay creation failed", e)
            }
        }
    }

    fun dismiss() {
        Log.d(TAG, "Overlay dismiss requested")
        mainHandler.post { dismissInternal() }
    }

    private fun startCallStateMonitoring(context: Context) {
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return

        val listener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                Log.d(TAG, "Call state changed -> state=$state, phone=$phoneNumber")
                if (state == TelephonyManager.CALL_STATE_IDLE || state == TelephonyManager.CALL_STATE_OFFHOOK) {
                    Log.d(TAG, "Call ended/answered -> dismissing overlay")
                    dismiss()
                }
            }
        }

        runCatching { tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE) }
            .onFailure {
                Log.e(TAG, "Failed to register call state listener", it)
                return
            }

        Log.d(TAG, "Call state listener registered")
        telephonyManager = tm
        callStateListener = listener
    }

    private fun dismissInternal() {
        Log.d(TAG, "dismissInternal invoked")
        dismissRunnable?.let { mainHandler.removeCallbacks(it) }
        dismissRunnable = null

        callStateListener?.let { listener ->
            telephonyManager?.listen(listener, PhoneStateListener.LISTEN_NONE)
        }
        callStateListener = null
        telephonyManager = null

        overlayView?.let { view ->
            runCatching { windowManager?.removeView(view) }
                .onFailure { Log.e(TAG, "Failed to remove overlay view", it) }
        }
        overlayView = null
        windowManager = null
        Log.d(TAG, "Overlay resources cleared")
    }
}
