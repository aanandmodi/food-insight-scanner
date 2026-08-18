package com.food_insight_scanner.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        try {
            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_layout_small).apply {
                    val calConsumed = getSafeInt(widgetData, "calories_consumed", 0)
                    val calGoal = getSafeInt(widgetData, "calories_goal", 2000)

                    setTextViewText(R.id.tv_cal_consumed_small, calConsumed.toString())

                    val calProgress = if (calGoal > 0) ((calConsumed.toFloat() / calGoal) * 100).toInt() else 0
                    setProgressBar(R.id.pb_calories_small, 100, calProgress, false)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Throwable) {
            Log.e("SmallWidgetProvider", "Widget update error: ${e.message}", e)
        }
    }

    private fun getSafeInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
        return try {
            prefs.getInt(key, defaultVal)
        } catch (_: Exception) {
            try {
                prefs.getLong(key, defaultVal.toLong()).toInt()
            } catch (_: Exception) {
                try {
                    prefs.getFloat(key, defaultVal.toFloat()).toInt()
                } catch (_: Exception) {
                    try {
                        prefs.getString(key, null)?.toIntOrNull() ?: defaultVal
                    } catch (_: Exception) {
                        defaultVal
                    }
                }
            }
        }
    }
}
