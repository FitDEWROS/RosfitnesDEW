package com.fitdew.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "app.links"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialLink" -> result.success(intent?.dataString)
          else -> result.notImplemented()
        }
      }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val link = intent.dataString
    if (link != null) {
      flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
        MethodChannel(messenger, channelName).invokeMethod("onLink", link)
      }
    }
  }
}
