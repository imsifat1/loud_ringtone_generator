package com.example.loud_ringtone_generator

import android.content.ContentValues
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.content.Intent
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.set_ringtone"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->

            if (call.method == "openWriteSettings") {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
                return@setMethodCallHandler
            }

            if (call.method == "canWriteSettings") {
                val canWrite = Settings.System.canWrite(applicationContext)
                result.success(canWrite)
                return@setMethodCallHandler
            }

            if (call.method == "setRingtone") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val success = setAsRingtone(applicationContext, filePath)
                    result.success(success)
                } else {
                    result.error("INVALID_PATH", "File path is null", null)
                }
                return@setMethodCallHandler
            }

        }
    }

    private fun setAsRingtone(context: Context, filePath: String): Boolean {
        try {
            val inputFile = File(filePath)
            if (!inputFile.exists()) return false

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, inputFile.name)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mp3")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_RINGTONES)
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
            }

            val uri: Uri? = context.contentResolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values
            )

            if (uri != null) {
                val outputStream: OutputStream? = context.contentResolver.openOutputStream(uri)
                val inputStream = FileInputStream(inputFile)
                inputStream.copyTo(outputStream!!)
                inputStream.close()
                outputStream.close()

                RingtoneManager.setActualDefaultRingtoneUri(
                    context,
                    RingtoneManager.TYPE_RINGTONE,
                    uri
                )
                return true
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }
}
