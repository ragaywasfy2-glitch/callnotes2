package com.example.callnotes

import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "callnotes/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleReminder" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val millis = call.argument<Number>("millis")?.toLong() ?: 0L
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        Reminders.schedule(applicationContext, id, millis, title, body)
                        result.success(true)
                    }

                    "cancelReminder" -> {
                        Reminders.cancel(applicationContext, call.argument<Int>("id") ?: 0)
                        result.success(true)
                    }

                    "openWhatsApp" -> {
                        val phone = call.argument<String>("phone") ?: ""
                        val text = call.argument<String>("text") ?: ""
                        try {
                            val uri = Uri.parse("https://wa.me/" + phone + "?text=" + Uri.encode(text))
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "readContacts" -> {
                        Thread {
                            val list = ArrayList<HashMap<String, String>>()
                            try {
                                val cur = contentResolver.query(
                                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                    arrayOf(
                                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                        ContactsContract.CommonDataKinds.Phone.NUMBER
                                    ),
                                    null,
                                    null,
                                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE NOCASE ASC"
                                )
                                cur?.use {
                                    while (it.moveToNext()) {
                                        val m = HashMap<String, String>()
                                        m["name"] = it.getString(0) ?: ""
                                        m["phone"] = it.getString(1) ?: ""
                                        list.add(m)
                                    }
                                }
                            } catch (e: Exception) {
                            }
                            runOnUiThread { result.success(list) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
