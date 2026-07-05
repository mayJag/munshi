package com.jagga.munshi

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launchUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchUri = intent?.dataString

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.jagga.munshi/widget"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val prefs = getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("label", call.argument<String>("label"))
                        .putString("amount", call.argument<String>("amount"))
                        .putString("sub", call.argument<String>("sub"))
                        .apply()
                    pushUpdate()
                    result.success(true)
                }
                "consumeLaunchUri" -> {
                    result.success(launchUri)
                    launchUri = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { launchUri = it }
    }

    /** Ask both widget providers to re-render from the shared prefs. */
    private fun pushUpdate() {
        val mgr = AppWidgetManager.getInstance(this)
        val ids = mgr.getAppWidgetIds(
            ComponentName(this, MunshiWidgetProvider::class.java)
        )
        if (ids.isNotEmpty()) {
            val i = Intent(this, MunshiWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(i)
        }
    }

    companion object {
        const val WIDGET_PREFS = "munshi_widget_prefs"
    }
}
