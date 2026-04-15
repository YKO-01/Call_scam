package com.example.my_app

import android.app.role.RoleManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		requestRequiredAndroidPermissions()
	}

	override fun onPostResume() {
		super.onPostResume()
		requestRequiredAndroidPermissions()
	}

	private fun requestRequiredAndroidPermissions() {
		ensureOverlayPermission()
		ensureCallScreeningRole()
	}

	private fun ensureOverlayPermission() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return
		}

		if (Settings.canDrawOverlays(this)) {
			return
		}

		val intent = Intent(
			Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
			Uri.parse("package:$packageName"),
		)
		runCatching { startActivity(intent) }
	}

	private fun ensureCallScreeningRole() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val roleManager = getSystemService(RoleManager::class.java) ?: return

			if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) ||
				roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
			) {
				return
			}

			val requestRoleIntent = roleManager.createRequestRoleIntent(
				RoleManager.ROLE_CALL_SCREENING,
			)
			runCatching { startActivity(requestRoleIntent) }
			return
		}

		runCatching {
			startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
		}
	}
}
