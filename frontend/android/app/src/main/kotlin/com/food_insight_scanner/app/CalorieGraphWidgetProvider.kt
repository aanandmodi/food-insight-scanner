package com.food_insight_scanner.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalorieGraphWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_graph).apply {
                val activeCals = widgetData.getInt("active_calories", 0)
                val activeCalsGoal = widgetData.getInt("active_calories_goal", 400)
                val steps = widgetData.getInt("steps", 0)
                val distanceKm = widgetData.getFloat("distance_km", 0.0f)
                val hourlyBurnDataStr = widgetData.getString("hourly_burn_data", "") ?: ""

                setTextViewText(R.id.tv_graph_goal, "Goal: $activeCalsGoal kcal")
                setTextViewText(R.id.tv_active_cals, "$activeCals kcal")
                setTextViewText(R.id.tv_steps, String.format("%,d", steps))
                setTextViewText(R.id.tv_distance, String.format("%.1f km", distanceKm))

                // Render dynamic 24-hour calorie burn chart bitmap
                val chartBitmap = createChartBitmap(hourlyBurnDataStr, activeCalsGoal)
                setImageViewBitmap(R.id.iv_chart, chartBitmap)

                // Launch App Intent on Tap
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("foodinsight://home")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.chart_container, pendingIntent)
                setOnClickPendingIntent(R.id.header_layout, pendingIntent)
                setOnClickPendingIntent(R.id.metrics_layout, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun createChartBitmap(hourlyDataStr: String, goalKcal: Int): Bitmap {
        val width = 600
        val height = 220
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val values = FloatArray(24)
        if (hourlyDataStr.isNotEmpty()) {
            val parts = hourlyDataStr.split(",")
            for (i in 0 until Math.min(parts.size, 24)) {
                values[i] = parts[i].toFloatOrNull() ?: 0f
            }
        } else {
            // Default sample distribution if no data available
            val mock = floatArrayOf(
                5f, 2f, 0f, 0f, 0f, 10f, 35f, 55f, 40f, 30f, 45f, 60f,
                75f, 50f, 40f, 35f, 50f, 65f, 45f, 30f, 20f, 15f, 10f, 5f
            )
            System.arraycopy(mock, 0, values, 0, 24)
        }

        val maxVal = Math.max(values.maxOrNull() ?: 100f, 80f)

        // Background subtle grid line
        val gridPaint = Paint().apply {
            color = Color.parseColor("#20FFFFFF")
            strokeWidth = 2f
            style = Paint.Style.STROKE
            pathEffect = DashPathEffect(floatArrayOf(10f, 10f), 0f)
        }
        canvas.drawLine(20f, height / 2f, width - 20f, height / 2f, gridPaint)

        val barWidth = (width - 60f) / 24f
        val currentHour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)

        for (i in 0 until 24) {
            val left = 20f + (i * barWidth) + 3f
            val right = left + barWidth - 6f
            val valPct = (values[i] / maxVal).coerceIn(0.05f, 1.0f)
            val barHeight = (height - 40f) * valPct
            val top = height - 20f - barHeight
            val bottom = height - 20f

            val isCurrent = (i == currentHour)

            val barPaint = Paint().apply {
                isAntiAlias = true
                shader = if (isCurrent) {
                    LinearGradient(
                        left, top, left, bottom,
                        Color.parseColor("#FF5252"),
                        Color.parseColor("#FF1744"),
                        Shader.TileMode.CLAMP
                    )
                } else {
                    LinearGradient(
                        left, top, left, bottom,
                        Color.parseColor("#10B981"),
                        Color.parseColor("#059669"),
                        Shader.TileMode.CLAMP
                    )
                }
            }

            val rect = RectF(left, top, right, bottom)
            canvas.drawRoundRect(rect, 6f, 6f, barPaint)
        }

        return bitmap
    }
}
