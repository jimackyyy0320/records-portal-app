package com.recordsportal.student_portal_app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.recordsportal.app/device_bridge"
        private const val REQ_CAMERA_PERMISSION = 4102

        private val URI_PREFIX_MAP = arrayOf(
            "",
            "http://www.",
            "https://www.",
            "http://",
            "https://",
            "tel:",
            "mailto:",
            "ftp://anonymous:anonymous@",
            "ftp://ftp.",
            "ftps://",
            "sftp://",
            "smb://",
            "nfs://",
            "ftp://",
            "dav://",
            "news:",
            "telnet://",
            "imap:",
            "rtsp://",
            "urn:",
            "pop:",
            "sip:",
            "sips:",
            "tftp:",
            "btspp://",
            "btl2cap://",
            "btgoep://",
            "tcpobex://",
            "irdaobex://",
            "file://",
            "urn:epc:id:",
            "urn:epc:tag:",
            "urn:epc:pat:",
            "urn:epc:raw:",
            "urn:epc:",
            "urn:nfc:"
        )
    }

    private var methodChannel: MethodChannel? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var nfcReaderWanted: Boolean = false
    private var nfcReaderAttached: Boolean = false

    private val nfcReaderCallback = NfcAdapter.ReaderCallback { tag ->
        if (tag != null && nfcReaderWanted) {
            handleDiscoveredTag(tag)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getHardwareStatus" -> {
                    result.success(getHardwareStatusMap())
                }
                "requestCameraPermission" -> {
                    if (isCameraGranted()) {
                        result.success(true)
                    } else {
                        pendingCameraResult?.success(false)
                        pendingCameraResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.CAMERA),
                            REQ_CAMERA_PERMISSION
                        )
                    }
                }
                "setNfcReaderActive" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    nfcReaderWanted = active
                    if (active) {
                        enableNfcReaderIfPossible()
                    } else {
                        disableNfcReader()
                    }
                    result.success(getHardwareStatusMap())
                }
                "openNfcSettings" -> {
                    result.success(launchNfcSettings())
                }
                "openAppSettings" -> {
                    result.success(launchAppDetailsSettings())
                }
                "saveTextToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "Reviewer_Outline.txt"
                    val content = call.argument<String>("content") ?: ""
                    try {
                        val savedInfo = savePlainTextToDownloads(fileName, content)
                        result.success(savedInfo)
                    } catch (e: Throwable) {
                        result.error("SAVE_FAILED", e.message ?: "Unable to save text file", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (nfcReaderWanted) {
            enableNfcReaderIfPossible()
        }
        methodChannel?.invokeMethod("onHardwareStatusChanged", getHardwareStatusMap())
    }

    override fun onPause() {
        if (nfcReaderAttached) {
            disableNfcReader()
        }
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (!nfcReaderWanted) return
        val tag: Tag? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }
        if (tag != null) {
            handleDiscoveredTag(tag)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA_PERMISSION) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            val callback = pendingCameraResult
            pendingCameraResult = null
            callback?.success(granted)
            methodChannel?.invokeMethod("onHardwareStatusChanged", getHardwareStatusMap())
        }
    }

    private fun isCameraGranted(): Boolean {
        return checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    private fun getHardwareStatusMap(): Map<String, Any> {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        return mapOf(
            "cameraGranted" to isCameraGranted(),
            "nfcSupported" to (adapter != null),
            "nfcEnabled" to (adapter?.isEnabled == true),
            "nfcReaderAttached" to nfcReaderAttached
        )
    }

    private fun enableNfcReaderIfPossible() {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        if (adapter == null || !adapter.isEnabled) {
            nfcReaderAttached = false
            return
        }
        try {
            val flags = NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_NFC_F or
                NfcAdapter.FLAG_READER_NFC_V or
                NfcAdapter.FLAG_READER_NFC_BARCODE or
                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

            val extras = Bundle().apply {
                putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
            }
            adapter.enableReaderMode(this, nfcReaderCallback, flags, extras)
            nfcReaderAttached = true
        } catch (_: Throwable) {
            nfcReaderAttached = false
        }
    }

    private fun disableNfcReader() {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        try {
            adapter?.disableReaderMode(this)
        } catch (_: Throwable) {
        } finally {
            nfcReaderAttached = false
        }
    }

    private fun handleDiscoveredTag(tag: Tag) {
        val uidHex = tag.id?.joinToString(":") { b -> String.format("%02X", b) } ?: ""
        var ndefExtracted: String? = null

        try {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                var message: NdefMessage? = ndef.cachedNdefMessage
                if (message == null) {
                    try {
                        ndef.connect()
                        message = ndef.ndefMessage
                    } catch (_: Throwable) {
                    } finally {
                        try {
                            ndef.close()
                        } catch (_: Throwable) {
                        }
                    }
                }
                if (message != null) {
                    for (record in message.records) {
                        val decoded = decodeNdefRecord(record)
                        if (!decoded.isNullOrBlank()) {
                            ndefExtracted = decoded.trim()
                            break
                        }
                    }
                }
            }
        } catch (_: Throwable) {
        }

        val finalId = if (!ndefExtracted.isNullOrBlank()) ndefExtracted else uidHex
        if (finalId.isBlank()) return

        val payload = mapOf(
            "id" to finalId,
            "uid" to uidHex,
            "source" to if (!ndefExtracted.isNullOrBlank()) "NDEF" else "UID"
        )

        runOnUiThread {
            methodChannel?.invokeMethod("onNfcTagDiscovered", payload)
        }
    }

    private fun decodeNdefRecord(record: NdefRecord): String? {
        val payload = record.payload ?: return null
        if (payload.isEmpty()) return null

        // NFC Forum Well-Known Text ('T')
        if (record.tnf == NdefRecord.TNF_WELL_KNOWN &&
            record.type.contentEquals(NdefRecord.RTD_TEXT)
        ) {
            val status = payload[0].toInt() and 0xFF
            val langLen = status and 0x3F
            val start = 1 + langLen
            if (payload.size <= start) return null
            val charset: Charset = if ((status and 0x80) != 0) {
                Charsets.UTF_16
            } else {
                Charsets.UTF_8
            }
            return String(payload, start, payload.size - start, charset).trim()
        }

        // NFC Forum Well-Known URI ('U')
        if (record.tnf == NdefRecord.TNF_WELL_KNOWN &&
            record.type.contentEquals(NdefRecord.RTD_URI) &&
            payload.size > 1
        ) {
            val prefixCode = payload[0].toInt() and 0xFF
            val prefix = if (prefixCode in URI_PREFIX_MAP.indices) {
                URI_PREFIX_MAP[prefixCode]
            } else {
                ""
            }
            val rest = String(payload, 1, payload.size - 1, Charsets.UTF_8)
            return (prefix + rest).trim()
        }

        // MIME or External UTF-8 text payload
        if (record.tnf == NdefRecord.TNF_MIME_MEDIA ||
            record.tnf == NdefRecord.TNF_EXTERNAL_TYPE ||
            record.tnf == NdefRecord.TNF_ABSOLUTE_URI
        ) {
            return String(payload, Charsets.UTF_8).trim()
        }

        return null
    }

    private fun launchNfcSettings(): Boolean {
        val candidates = listOf(
            Intent(Settings.ACTION_NFC_SETTINGS),
            Intent(Settings.ACTION_WIRELESS_SETTINGS),
            Intent(Settings.ACTION_SETTINGS)
        )
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Throwable) {
            }
        }
        return false
    }

    private fun launchAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun savePlainTextToDownloads(rawFileName: String, content: String): Map<String, Any> {
        val cleaned = rawFileName
            .replace(Regex("[^A-Za-z0-9._ -]"), "_")
            .trim()
            .let { if (it.isBlank()) "Reviewer_Outline.txt" else it }
            .let { if (it.lowercase().endsWith(".txt")) it else "$it.txt" }

        val bytes = content.toByteArray(Charsets.UTF_8)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, cleaned)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain; charset=utf-8")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create file in Downloads")

            resolver.openOutputStream(uri)?.use { out ->
                out.write(bytes)
                out.flush()
            } ?: throw IllegalStateException("Could not open Downloads output stream")

            val readyValues = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(uri, readyValues, null, null)

            return mapOf(
                "success" to true,
                "fileName" to cleaned,
                "displayPath" to "Downloads/$cleaned",
                "uri" to uri.toString()
            )
        } else {
            @Suppress("DEPRECATION")
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val targetDir = if (downloadsDir != null && (downloadsDir.exists() || downloadsDir.mkdirs()) && downloadsDir.canWrite()) {
                downloadsDir
            } else {
                getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
            }
            val targetFile = File(targetDir, cleaned)
            targetFile.writeBytes(bytes)
            return mapOf(
                "success" to true,
                "fileName" to cleaned,
                "displayPath" to targetFile.absolutePath,
                "uri" to Uri.fromFile(targetFile).toString()
            )
        }
    }
}
