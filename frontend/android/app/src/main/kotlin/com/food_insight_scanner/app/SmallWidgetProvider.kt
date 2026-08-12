package com.food_insight_scanner.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_small).apply {
                val calConsumed = widgetData.getInt("calories_consumed", 0)
                val calGoal = widgetData.getInt("calories_goal", 2000)

                setTextViewText(R.id.tv_cal_consumed_small, calConsumed.toString())

                val calProgress = if (calGoal > 0) ((calConsumed.toFloat() / calGoal) * 100).toInt() else 0
                setProgressBar(R.id.pb_calories_small, 100, calProgress, false)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
