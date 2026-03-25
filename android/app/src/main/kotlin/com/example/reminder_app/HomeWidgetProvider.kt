package com.example.reminder_app

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

        /** Форматирует "2026-03-15 14:30" → "14:30" / "Завтра 09:00" / "16 мар 14:30" / "Просрочено" */
        private fun formatTime(raw: String?, isOverdue: Boolean): String {
            if (raw.isNullOrEmpty()) return ""
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
                if (year == todayYear && month == todayMonth && day == todayDay) return timePart
                now.add(java.util.Calendar.DAY_OF_MONTH, 1)
                val tmrYear = now.get(java.util.Calendar.YEAR)
                val tmrMonth = now.get(java.util.Calendar.MONTH) + 1
                val tmrDay = now.get(java.util.Calendar.DAY_OF_MONTH)
                if (year == tmrYear && month == tmrMonth && day == tmrDay) return "Завтра $timePart"
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
            return try { Color.parseColor("#FF$hex") } catch (e: Exception) { fallback }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )

            val isDark = (context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

            val titles    = Array(5) { i -> prefs.getString("task_title_$i", null) }
            val times     = Array(5) { i -> prefs.getString("task_time_$i", null) }
            val colors    = Array(5) { i -> prefs.getString("task_color_$i", null) }
            val taskIds   = Array(5) { i -> prefs.getInt("task_id_$i", 0) }
            val taskCount = prefs.getInt("task_count", 0)
            val doneCount = prefs.getInt("done_count", 0)
            val totalCount = prefs.getInt("total_count", 0)

            // Тап по всему виджету → открыть приложение
            val openIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                component = ComponentName(context.packageName, "${context.packageName}.MainActivity")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(
                context, appWidgetId, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.widget_medium)
            views.setOnClickPendingIntent(R.id.widget_root, openPending)

            val defaultTextColor = if (isDark) Color.parseColor("#FFF5F5F7") else Color.parseColor("#FF1D1D1F")
            val greenColor       = if (isDark) Color.parseColor("#FF34D399") else Color.parseColor("#FF10B981")
            val secondaryColor   = Color.parseColor("#FF8E8E93")

            // Заголовок
            val headerText = if (taskCount > 0) "Задачи · $taskCount" else "Задачи"
            views.setTextViewText(R.id.widget_title, headerText)
            views.setTextColor(R.id.widget_title, greenColor)
            views.setTextColor(R.id.empty_text, secondaryColor)

            // Прогресс-бар
            val progress = if (totalCount > 0) (doneCount * 100 / totalCount) else 0
            views.setProgressBar(R.id.widget_progress, 100, progress, false)

            val rowIds   = intArrayOf(R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5)
            val titleIds = intArrayOf(R.id.title1, R.id.title2, R.id.title3, R.id.title4, R.id.title5)
            val timeIds  = intArrayOf(R.id.time1, R.id.time2, R.id.time3, R.id.time4, R.id.time5)
            val checkIds = intArrayOf(R.id.check1, R.id.check2, R.id.check3, R.id.check4, R.id.check5)
            val overdueHex = "FF6B35"

            var hasAny = false
            for (i in 0..4) {
                if (!titles[i].isNullOrEmpty()) {
                    val isOverdue = colors[i] == overdueHex
                    val taskColor = if (colors[i] != null && colors[i] != "1D1D1F")
                        parseColor(colors[i], defaultTextColor)
                    else defaultTextColor

                    views.setTextViewText(titleIds[i], titles[i])
                    views.setTextColor(titleIds[i], taskColor)
                    views.setTextViewText(timeIds[i], formatTime(times[i], isOverdue))
                    views.setTextColor(timeIds[i], if (isOverdue) Color.parseColor("#FFFF6B35") else greenColor)
                    views.setTextColor(checkIds[i], greenColor)
                    views.setViewVisibility(rowIds[i], View.VISIBLE)

                    // Кнопка "○ Готово" для каждой задачи
                    val tid = taskIds[i]
                    if (tid > 0) {
                        val doneIntent = Intent(context, WidgetDoneReceiver::class.java).apply {
                            action = "WIDGET_DONE_$tid"
                            putExtra("task_id", tid)
                        }
                        val donePending = PendingIntent.getBroadcast(
                            context,
                            appWidgetId * 10 + i,
                            doneIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(checkIds[i], donePending)
                    }

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
