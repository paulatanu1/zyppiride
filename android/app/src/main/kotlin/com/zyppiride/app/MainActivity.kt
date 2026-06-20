package com.zyppiride.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            // Main channel — booking updates, general ride alerts
            val rideChannel = NotificationChannel(
                "zyppi_ride_channel",
                "Zyppi Ride Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Booking updates, driver requests, and ride alerts"
                enableVibration(true)
            }

            // High-priority channel — incoming booking requests for drivers
            val bookingChannel = NotificationChannel(
                "zyppi_booking_requests",
                "Booking Requests",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Incoming booking requests for drivers"
                enableVibration(true)
            }

            manager.createNotificationChannels(listOf(rideChannel, bookingChannel))
        }
    }
}
