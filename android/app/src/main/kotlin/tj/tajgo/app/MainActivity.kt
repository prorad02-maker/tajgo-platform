package tj.tajgo.app

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("tajgo_orders", "Заказы и доставка", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Предложения курьеров и изменения ваших заказов"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
