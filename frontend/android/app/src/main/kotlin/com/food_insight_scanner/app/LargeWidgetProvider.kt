package com.food_insight_scanner.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class LargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_large).apply {
                val calConsumed = widgetData.getInt("calories_consumed", 0)
                val calGoal = widgetData.getInt("calories_goal", 2000)
                val carbs = widgetData.getInt("carbs_consumed", 0)
                val carbsGoal = widgetData.getInt("carbs_goal", 300)
                val protein = widgetData.getInt("protein_consumed", 0)
                val proteinGoal = widgetData.getInt("protein_goal", 150)
                val fat = widgetData.getInt("fat_consumed", 0)
                val fatGoal = widgetData.getInt("fat_goal", 70)

                setTextViewText(R.id.tv_goal, "Goal: $calGoal kcal")
                setTextViewText(R.id.tv_cal_consumed, calConsumed.toString())
                setTextViewText(R.id.tv_carbs, "$carbs/${carbsGoal} g")
                setTextViewText(R.id.tv_protein, "$protein/${proteinGoal} g")
                setTextViewText(R.id.tv_fat, "$fat/${fatGoal} g")

                val calProgress = if (calGoal > 0) ((calConsumed.toFloat() / calGoal) * 100).toInt() else 0
                val carbsProgress = if (carbsGoal > 0) ((carbs.toFloat() / carbsGoal) * 100).toInt() else 0
                val proteinProgress = if (proteinGoal > 0) ((protein.toFloat() / proteinGoal) * 100).toInt() else 0
                val fatProgress = if (fatGoal > 0) ((fat.toFloat() / fatGoal) * 100).toInt() else 0

                setProgressBar(R.id.pb_calories, 100, calProgress, false)
                setProgressBar(R.id.pb_carbs_bar, 100, carbsProgress, false)
                setProgressBar(R.id.pb_protein_bar, 100, proteinProgress, false)
                setProgressBar(R.id.pb_fat_bar, 100, fatProgress, false)

                // Quick Action Intents
                val backgroundIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("foodinsight://scan")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    backgroundIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_scan, pendingIntent)
                setOnClickPendingIntent(R.id.btn_log_meal, pendingIntent) // Just launching the app for now
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
