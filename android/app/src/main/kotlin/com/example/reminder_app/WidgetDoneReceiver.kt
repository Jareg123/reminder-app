package com.example.reminder_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WidgetDoneReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getIntExtra("task_id", -1)
        if (taskId <= 0) return

        // 1. Обновить SQLite
        try {
            val dbFile = context.getDatabasePath("events.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE
            )
            db.execSQL("UPDATE events SET is_done = 1 WHERE id = ?", arrayOf(taskId))
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            db.execSQL(
                "INSERT OR IGNORE INTO daily_stats (date, completed_tasks) VALUES (?, 0)",
                arrayOf(today)
            )
            db.execSQL(
                "UPDATE daily_stats SET completed_tasks = completed_tasks + 1 WHERE date = ?",
                arrayOf(today)
            )
            db.close()
        } catch (e: Exception) {
            Log.e("WidgetDone", "DB error: ${e.message}")
            return
        }

        // 2. Сразу обновить SharedPreferences — убрать выполненную задачу и сдвинуть список
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        val taskCount = prefs.getInt("task_count", 0)
        var foundAt = -1

        for (i in 0 until 5) {
            if (prefs.getInt("task_id_$i", 0) == taskId) {
                foundAt = i
                break
            }
        }

        if (foundAt >= 0) {
            // Сдвинуть оставшиеся задачи на одну позицию вверх
            for (j in foundAt until 4) {
                editor.putInt("task_id_$j",       prefs.getInt("task_id_${j + 1}", 0))
                editor.putString("task_title_$j", prefs.getString("task_title_${j + 1}", ""))
                editor.putString("task_time_$j",  prefs.getString("task_time_${j + 1}", ""))
                editor.putString("task_color_$j", prefs.getString("task_color_${j + 1}", ""))
            }
            // Очистить последний слот
            editor.putInt("task_id_4", 0)
            editor.putString("task_title_4", "")
            editor.putString("task_time_4", "")
            editor.putString("task_color_4", "")

            val newCount = if (taskCount > 0) taskCount - 1 else 0
            editor.putInt("task_count", newCount)
        }

        // Обновить счётчики прогресса
        val doneCount = prefs.getInt("done_count", 0)
        editor.putInt("done_count", doneCount + 1)
        editor.apply()

        // 3. Перерисовать виджет с новыми данными
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, HomeWidgetProvider::class.java)
        )
        if (ids.isNotEmpty()) {
            HomeWidgetProvider().onUpdate(context, manager, ids)
        }
    }
}
