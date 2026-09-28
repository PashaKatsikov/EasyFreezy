package com.easyfreezy.app

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pipeName = "n6w/sheet"
    private val chooseCode = 0x4E17
    private var waiting: MethodChannel.Result? = null
    private var pipe: MethodChannel? = null
    private var lastKb = -1.0

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        WindowInsetsControllerCompat(window, window.decorView).systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        hideBars()
        watchKeyboard()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideBars()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        window.decorView.post {
            hideBars()
            pipe?.invokeMethod("insetTick", sample())
        }
    }

    private fun hideBars() {
        val root = window.decorView
        val now = ViewCompat.getRootWindowInsets(root)
        val imeUp = now != null && now.isVisible(WindowInsetsCompat.Type.ime())
        val wanted = if (imeUp) {
            WindowInsetsCompat.Type.statusBars()
        } else {
            WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.navigationBars()
        }
        val alreadyHidden = now != null &&
            !now.isVisible(WindowInsetsCompat.Type.statusBars()) &&
            (imeUp || !now.isVisible(WindowInsetsCompat.Type.navigationBars()))
        if (alreadyHidden) return
        WindowInsetsControllerCompat(window, root).hide(wanted)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipe = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipeName)
        pipe?.setMethodCallHandler { call, result ->
            when (call.method) {
                "choose" -> {
                    val many = call.argument<Boolean>("multiple") ?: false
                    val types = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    openChooser(many, types, result)
                }
                "measure" -> result.success(sample())
                else -> result.notImplemented()
            }
        }
    }

    private fun toDip(px: Int): Double {
        val scale = resources.displayMetrics.density.toDouble()
        return if (scale <= 0.0) 0.0 else px / scale
    }

    private fun sample(): HashMap<String, Double> {
        val now = ViewCompat.getRootWindowInsets(window.decorView)
        val keyboard = now?.getInsets(WindowInsetsCompat.Type.ime())?.bottom ?: 0
        val notch = now?.getInsets(WindowInsetsCompat.Type.displayCutout())
        return hashMapOf(
            "kb" to toDip(keyboard),
            "nLeft" to toDip(notch?.left ?: 0),
            "nTop" to toDip(notch?.top ?: 0),
            "nRight" to toDip(notch?.right ?: 0),
        )
    }

    private fun watchKeyboard() {
        val host = findViewById<View>(android.R.id.content) ?: return
        ViewCompat.setWindowInsetsAnimationCallback(
            host,
            object : WindowInsetsAnimationCompat.Callback(
                WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE,
            ) {
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: MutableList<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat = insets

                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    val pane = sample()
                    val kb = pane["kb"] ?: 0.0
                    if (kotlin.math.abs(kb - lastKb) < 1.0) return
                    lastKb = kb
                    runOnUiThread { pipe?.invokeMethod("insetTick", pane) }
                }
            },
        )
    }

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        waiting?.success(emptyList<String>())
        waiting = result
        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }
        try {
            startActivityForResult(Intent.createChooser(intent, null), chooseCode)
        } catch (_: Exception) {
            waiting = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooseCode) return
        val result = waiting
        waiting = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }
        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
