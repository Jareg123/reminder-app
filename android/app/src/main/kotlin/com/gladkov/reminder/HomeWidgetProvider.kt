package com.gladkov.reminder

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.widget.RemoteViews
import android.view.View

class HomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private fun formatTime(raw: String?, isOverdue: Boolean): String {
            if (raw.isNullOrEmpty()) return ""
            // Проверяем просрочку прямо здесь, не только по флагу из Flutter
            try {
                val parts = raw.split(" ")
                if (parts.size >= 2) {
                    val dParts = parts[0].split("-")
                    val tParts = parts[1].split(":")
                    if (dParts.size >= 3 && tParts.size >= 2) {
                        val taskCal = java.util.Calendar.getInstance()
                        taskCal.set(dParts[0].toInt(), dParts[1].toInt() - 1, dParts[2].toInt(),
                            tParts[0].toInt(), tParts[1].toInt(), 0)
                        if (taskCal.before(java.util.Calendar.getInstance())) {
                            return "Просрочено"
                        }
                    }
                }
            } catch (_: Exception) {}
            if (isOverdue) return "Просрочено"
            try {
                val parts = raw.split(" ")
                if (parts.size < 2) return raw
                val datePart = parts[0]
                val timePart = parts[1]

                val dParts = datePart.split("-")
                if (dParts.size < 3) return timePart

                val year = dParts[0].toInt()
                val month = dParts[1].toInt()
                val day = dParts[2].toInt()

                val now = java.util.Calendar.getInstance()
                val todayYear = now.get(java.util.Calendar.YEAR)
                val todayMonth = now.get(java.util.Calendar.MONTH) + 1
                val todayDay = now.get(java.util.Calendar.DAY_OF_MONTH)

                if (year == todayYear && month == todayMonth && day == todayDay) {
                    return timePart
                }

                now.add(java.util.Calendar.DAY_OF_MONTH, 1)
                val tmrYear = now.get(java.util.Calendar.YEAR)
                val tmrMonth = now.get(java.util.Calendar.MONTH) + 1
                val tmrDay = now.get(java.util.Calendar.DAY_OF_MONTH)
                if (year == tmrYear && month == tmrMonth && day == tmrDay) {
                    return "Завтра $timePart"
                }

                val months = arrayOf("", "янв", "фев", "мар", "апр", "май", "июн",
                    "июл", "авг", "сен", "окт", "ноя", "дек")
                val mName = if (month in 1..12) months[month] else "$month"
                return "$day $mName $timePart"
            } catch (e: Exception) {
                return raw
            }
        }

        private fun parseColor(hex: String?, fallback: Int): Int {
            if (hex.isNullOrEmpty()) return fallback
            return try {
                Color.parseColor("#FF$hex")
            } catch (e: Exception) {
                fallback
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )

            // Тёмная тема?
            val isDark = (context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

            val titles = Array(5) { i -> prefs.getString("task_title_$i", null) }
            val times  = Array(5) { i -> prefs.getString("task_time_$i", null) }
            val colors = Array(5) { i -> prefs.getString("task_color_$i", null) }
            val taskCount = prefs.getInt("task_count", 0)

            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                component = ComponentName(context.packageName, "com.gladkov.reminder.MainActivity")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.widget_medium)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Цвета в зависимости от темы
            val defaultTextColor = if (isDark) Color.parseColor("#FFF5F5F7") else Color.parseColor("#FF000000")
            val greenColor = if (isDark) Color.parseColor("#FF34D399") else Color.parseColor("#FF10B981")
            val secondaryColor = if (isDark) Color.parseColor("#FF8E8E93") else Color.parseColor("#FF8E8E93")
            val dividerColor = if (isDark) Color.parseColor("#FF3A3A3C") else Color.parseColor("#FFE8E8E8")

            // Заголовок со счётчиком
            val headerText = if (taskCount > 0) "Задачи · $taskCount" else "Задачи"
            views.setTextViewText(R.id.widget_title, headerText)
            views.setTextColor(R.id.widget_title, greenColor)
            views.setTextColor(R.id.widget_divider, dividerColor)
            views.setTextColor(R.id.empty_text, secondaryColor)

            val rowIds   = intArrayOf(R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5)
            val titleIds = intArrayOf(R.id.title1, R.id.title2, R.id.title3, R.id.title4, R.id.title5)
            val timeIds  = intArrayOf(R.id.time1, R.id.time2, R.id.time3, R.id.time4, R.id.time5)
            val dotIds   = intArrayOf(R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5)

            val overdueHex = "FF6B35"

            var hasAny = false
            for (i in 0..4) {
                if (!titles[i].isNullOrEmpty()) {
                    val isOverdue = colors[i] == overdueHex

                    views.setTextViewText(titleIds[i], titles[i])
                    views.setTextViewText(timeIds[i], formatTime(times[i], isOverdue))
                    views.setViewVisibility(rowIds[i], View.VISIBLE)

                    // Цвет задачи
                    val taskColor = if (colors[i] != null && colors[i] != "1D1D1F") {
                        parseColor(colors[i], defaultTextColor)
                    } else {
                        defaultTextColor
                    }

                    views.setTextColor(titleIds[i], taskColor)
                    views.setTextColor(dotIds[i], taskColor)
                    views.setTextColor(timeIds[i], if (isOverdue) taskColor else greenColor)

                    hasAny = true
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }

            views.setViewVisibility(R.id.empty_text, if (hasAny) View.GONE else View.VISIBLE)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onEnabled(context: Context) { super.onEnabled(context) }
    override fun onDisabled(context: Context) { super.onDisabled(context) }
}
