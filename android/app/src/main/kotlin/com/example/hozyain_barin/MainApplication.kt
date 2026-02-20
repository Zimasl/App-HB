package com.example.hozyain_barin

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("d8fdb4b0-7698-4e1d-bdb5-978a25275ba9")
    }
}
