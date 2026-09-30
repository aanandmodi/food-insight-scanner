package com.food_insight_scanner.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient

/** Offline copy of the published privacy policy; no account or network required. */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val policy = WebView(this)
        policy.settings.javaScriptEnabled = false
        policy.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                if (uri.toString().startsWith("file:///android_asset/legal/")) return false
                if (uri.scheme == "https" || uri.scheme == "mailto") {
                    try { startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (_: Exception) { }
                }
                return true
            }
        }
        setContentView(policy)
        policy.loadUrl("file:///android_asset/legal/privacy.html")
    }
}
