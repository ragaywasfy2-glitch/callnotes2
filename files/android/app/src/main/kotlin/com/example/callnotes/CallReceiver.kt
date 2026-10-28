package com.example.callnotes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView

class CallReceiver : BroadcastReceiver() {

    private data class Row(val name: String, val date: String, val notes: String)

    companion object {
        private var overlay: View? = null
        private const val CHANNEL_ID = "client_calls"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val app = context.applicationContext

        when (intent.getStringExtra(TelephonyManager.EXTRA_STATE)) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // أندرويد 9+ بيبعت البرودكاست مرتين، مرة من غير الرقم
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                if (number.isNullOrBlank()) return

                val rows = lookup(app, number)
                if (rows.isEmpty()) return

                val last = rows.first()
                val title = "📞 ${last.name}"
                val body = buildString {
                    append(if (rows.size == 1) "حجز معاك مرة واحدة" else "حجز معاك ${rows.size} مرات")
                    append(" - آخر حجز: ${fmt(last.date)}")
                    if (last.notes.isNotBlank()) append("\n${last.notes}")
                }

                showNotification(app, title, body)
                showOverlay(app, "$title\n$body")
            }
            // الاتصال اتردّ عليه أو اتقفل
            else -> removeOverlay(app)
        }
    }

    // ------------------------------------------------------------ DB
    private fun lookup(ctx: Context, number: String): List<Row> {
        val digits = number.filter { it.isDigit() }
        if (digits.length < 7) return emptyList()
        val key = digits.takeLast(9)

        val file = ctx.getDatabasePath("bookings.db")
        if (!file.exists()) return emptyList()

        val result = mutableListOf<Row>()
        try {
            val db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery(
                "SELECT name, date, notes FROM bookings WHERE phone_key = ? ORDER BY date DESC, id DESC",
                arrayOf(key)
            ).use { c ->
                while (c.moveToNext()) {
                    result.add(Row(c.getString(0) ?: "", c.getString(1) ?: "", c.getString(2) ?: ""))
                }
            }
            db.close()
        } catch (e: Exception) {
        }
        return result
    }

    private fun fmt(iso: String): String {
        val p = iso.split("-")
        return if (p.size == 3) "${p[2]}/${p[1]}/${p[0]}" else iso
    }

    // ------------------------------------------------------------ Notification
    @Suppress("DEPRECATION")
    private fun showNotification(ctx: Context, title: String, body: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Client calls", NotificationManager.IMPORTANCE_HIGH)
            )
            builder = Notification.Builder(ctx, CHANNEL_ID)
        } else {
            builder = Notification.Builder(ctx).setPriority(Notification.PRIORITY_HIGH)
        }
        val n = builder
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body.lines().first())
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .build()
        nm.notify(1001, n)
    }

    // ------------------------------------------------------------ Overlay
    @Suppress("DEPRECATION")
    private fun showOverlay(ctx: Context, text: String) {
        if (!Settings.canDrawOverlays(ctx)) return
        removeOverlay(ctx)

        val tv = TextView(ctx).apply {
            this.text = text
            setTextColor(Color.WHITE)
            textSize = 17f
            gravity = Gravity.CENTER
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(48, 36, 48, 36)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E60F766E"))
                cornerRadius = 36f
            }
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            WindowManager.LayoutParams.TYPE_PHONE

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
            y = 150
            horizontalMargin = 0.03f
        }

        try {
            (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(tv, lp)
            overlay = tv
            Handler(Looper.getMainLooper()).postDelayed({ removeOverlay(ctx) }, 30_000)
        } catch (e: Exception) {
        }
    }

    private fun removeOverlay(ctx: Context) {
        overlay?.let {
            try {
                (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(it)
            } catch (e: Exception) {
            }
        }
        overlay = null
    }
}
