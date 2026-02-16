package su.typikon.typikon

import android.content.ActivityNotFoundException;
import android.content.ContentValues;
import android.content.Context;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.widget.Toast;
import android.content.Intent;
import android.net.Uri;
import androidx.annotation.NonNull

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "su.typikon.typikon/utils"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "openFile") {
                val list = call.arguments as List<String>?
                if (list != null && !list.isEmpty()) {
                    val batteryLevel = openFile(list.get(0) as String?, list.get(1) as String?)
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Cannot call this.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    fun openFile(contentUriString: String?, mimeType: String?) {
        val contentUri: Uri = Uri.parse(contentUriString)

        val intent: Intent = Intent(Intent.ACTION_VIEW)
        intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.addCategory("android.intent.category.DEFAULT")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.setDataAndType(contentUri, mimeType)
        try {
            this.context.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Toast.makeText(this.context, "Нечем открыть файл.", Toast.LENGTH_LONG).show()
        }
    }
}
