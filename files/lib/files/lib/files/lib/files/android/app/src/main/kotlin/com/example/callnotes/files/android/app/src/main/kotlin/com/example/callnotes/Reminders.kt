package com.example.callnotes

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import java.util.Calendar

object Reminders {
    private const val CHANNEL = "followups"

    private fun flags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun pending(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
        i.putExtra("id", id)
        i.putExtra("title", title)
        i.putExtra("body", body)
        return PendingIntent.getBroadcast(ctx, id, i, flags())
    }

    fun schedule(ctx: Context, id: Int, millis: Long, title: String, body: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(ctx, id, title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pi)
        } else {
            am.set(AlarmManager.RTC_WAKEUP, millis, pi)
        }
    }

    fun cancel(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(ctx, id, "", ""))
    }

    /** يحوّل yyyy-MM-dd لوقت الساعة 10 الصبح */
    fun millisFor(iso: String): Long? {
        val p = iso.split("-")
        if (p.size != 3) return null
        return try {
            val c = Calendar.getInstance()
            c.set(p[0].toInt(), p[1].toInt() - 1, p[2].toInt(), 10, 0, 0)
            c.set(Calendar.MILLISECOND, 0)
            c.timeInMillis
        } catch (e: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    fun notify(ctx: Context, id: Int, title: String, body: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val b: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Follow-ups", NotificationManager.IMPORTANCE_HIGH)
            )
            b = Notification.Builder(ctx, CHANNEL)
        } else {
            b = Notification.Builder(ctx).setPriority(Notification.PRIORITY_HIGH)
        }

        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch != null) {
            b.setContentIntent(PendingIntent.getActivity(ctx, 0, launch, flags()))
        }

        val n = b
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .build()
        nm.notify(2000 + id, n)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "متابعة"
        val body = intent.getStringExtra("body") ?: ""
        Reminders.notify(context.applicationContext, id, title, body)
    }
}

/** بعد إعادة تشغيل الموبايل بيرجّع التذكيرات اللي لسه جاية */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val ctx = context.applicationContext
        val file = ctx.getDatabasePath("bookings.db")
        if (!file.exists()) return
        try {
            val db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery(
                "SELECT id, name, phone, follow_up FROM bookings " +
                        "WHERE follow_up IS NOT NULL AND follow_up != '' " +
                        "AND (follow_done IS NULL OR follow_done = 0)",
                null
            ).use { c ->
                val now = System.currentTimeMillis()
                while (c.moveToNext()) {
                    val t = Reminders.millisFor(c.getString(3) ?: "")
                    if (t != null && t > now) {
                        Reminders.schedule(
                            ctx,
                            c.getInt(0),
                            t,
                            "متابعة: " + (c.getString(1) ?: ""),
                            "كلّم العميل " + (c.getString(2) ?: "")
                        )
                    }
                }
            }
            db.close()
        } catch (e: Exception) {
        }
    }
}
