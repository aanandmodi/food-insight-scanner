package com.food_insight_scanner.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MacroWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Fetch data saved from Flutter
                val calGoal = widgetData.getInt("calories_goal", 2500)
                val calConsumed = widgetData.getInt("calories_consumed", 0)
                val carbsGoal = widgetData.getInt("carbs_goal", 300)
                val carbsConsumed = widgetData.getInt("carbs_consumed", 0)
                val proteinGoal = widgetData.getInt("protein_goal", 150)
                val proteinConsumed = widgetData.getInt("protein_consumed", 0)
                val fatGoal = widgetData.getInt("fat_goal", 80)
                val fatConsumed = widgetData.getInt("fat_consumed", 0)

                // Update text views
                setTextViewText(R.id.tv_goal, "Goal: %,d kcal".format(calGoal))
                setTextViewText(R.id.tv_cal_consumed, "%,d".format(calConsumed))
                setTextViewText(R.id.tv_carbs, "${carbsConsumed}/${carbsGoal} g")
                setTextViewText(R.id.tv_protein, "${proteinConsumed}/${proteinGoal} g")
                setTextViewText(R.id.tv_fat, "${fatConsumed}/${fatGoal} g")

                // Update progress bars
                val calProgress = if (calGoal > 0) ((calConsumed.toFloat() / calGoal) * 100).toInt() else 0
                val carbsProgress = if (carbsGoal > 0) ((carbsConsumed.toFloat() / carbsGoal) * 100).toInt() else 0
                val proteinProgress = if (proteinGoal > 0) ((proteinConsumed.toFloat() / proteinGoal) * 100).toInt() else 0
                val fatProgress = if (fatGoal > 0) ((fatConsumed.toFloat() / fatGoal) * 100).toInt() else 0

                setProgressBar(R.id.pb_calories, 100, calProgress, false)
                setProgressBar(R.id.pb_carbs_bar, 100, carbsProgress, false)
                setProgressBar(R.id.pb_protein_bar, 100, proteinProgress, false)
                setProgressBar(R.id.pb_fat_bar, 100, fatProgress, false)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
