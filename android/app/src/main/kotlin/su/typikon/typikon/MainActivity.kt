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
import android.view.WindowManager
import androidx.annotation.NonNull

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class MainActivity: FlutterActivity() {
    private val CHANNEL = "su.typikon.typikon/utils"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "diagnoseHttps") {
                // Public endpoint only, using normal certificate/hostname checks.
                Thread {
                    var connection: HttpsURLConnection? = null
                    val report = try {
                        connection = URL("https://www.typikon.info/api/health")
                            .openConnection() as HttpsURLConnection
                        connection.connectTimeout = 8000
                        connection.readTimeout = 8000
                        connection.useCaches = false
                        connection.setRequestProperty("Cache-Control", "no-cache")
                        val status = connection.responseCode
                        mapOf<String, Any>(
                            "status" to status,
                            "cipher" to connection.cipherSuite,
                        )
                    } catch (error: Exception) {
                        mapOf<String, Any>("error" to
                            generateSequence<Throwable>(error) { it.cause }
                                .take(4).joinToString(" <- ") {
                                    "${it.javaClass.simpleName}: ${it.message}"
                                })
                    } finally {
                        connection?.disconnect()
                    }
                    runOnUiThread { result.success(report) }
                }.start()
            } else if (call.method == "setKeepScreenOn") {
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            } else if (call.method == "openFile") {
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
