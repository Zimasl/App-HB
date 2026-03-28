package com.example.hozyain_barin

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val apiKey = BuildConfig.YANDEX_MAPKIT_API_KEY
        if (apiKey.isNotBlank()) {
            MapKitFactory.setApiKey(apiKey)
        }
    }
}
