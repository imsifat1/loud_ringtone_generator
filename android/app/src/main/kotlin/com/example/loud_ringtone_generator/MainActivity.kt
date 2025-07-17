package com.example.loud_ringtone_generator

import android.content.ContentValues
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.set_ringtone"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "setRingtone") {
                val filePath = call.argument<String>("filePath")
                val success = setAsRingtone(applicationContext, filePath!!)
                result.success(success)
            }
        }
    }

    private fun setAsRingtone(context: Context, path: String): Boolean {
        try {
            val file = File(path)
            val values = ContentValues()
            values.put(MediaStore.MediaColumns.DATA, file.absolutePath)
            values.put(MediaStore.MediaColumns.TITLE, file.name)
            values.put(MediaStore.MediaColumns.MIME_TYPE, "audio/mp3")
            values.put(MediaStore.MediaColumns.SIZE, file.length())
            values.put(MediaStore.Audio.Media.IS_RINGTONE, true)

            val uri = MediaStore.Audio.Media.getContentUriForPath(file.absolutePath)
            context.contentResolver.delete(uri!!, MediaStore.MediaColumns.DATA + "=\"" + file.absolutePath + "\"", null)
            val newUri = context.contentResolver.insert(uri, values)

            RingtoneManager.setActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE, newUri)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}

