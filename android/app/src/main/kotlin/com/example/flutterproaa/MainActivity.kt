package com.example.flutterproaa


import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.secure_app/security"
    private val ROOT_DETECTION_CHANNEL = "com.example.secure_app/root_detection"
    private val SCREENSHOT_CHANNEL = "com.example.secure_app/screenshot_prevention"
    private val ANTI_TAMPERING_CHANNEL = "com.example.secure_app/anti_tampering"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // تفعيل الحماية ضد لقطات الشاشة
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        // منع عرض التطبيق في قائمة التطبيقات الحديثة
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        // التحقق من سلامة التطبيق
        if (!isAppIntegrityValid()) {
            finish()
            return
        }

        // التحقق من التصحيح
        if (isDebuggable() || isDebuggerConnected()) {
            finish()
            return
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // قناة كشف الجذر
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROOT_DETECTION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkRoot" -> result.success(isDeviceRooted())
                "isAppInstalled" -> {
                    val packageName = call.arguments as String
                    result.success(isAppInstalled(packageName))
                }
                "checkSuspiciousProperties" -> result.success(checkSuspiciousProperties())
                "checkSuCommand" -> result.success(checkSuCommand())
                "checkSELinuxEnforcement" -> result.success(checkSELinuxEnforcement())
                else -> result.notImplemented()
            }
        }

        // قناة منع لقطات الشاشة
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableScreenshotPrevention" -> {
                    enableScreenshotPrevention()
                    result.success(true)
                }
                "disableScreenshotPrevention" -> {
                    disableScreenshotPrevention()
                    result.success(true)
                }
                "enableScreenRecordingPrevention" -> {
                    enableScreenRecordingPrevention()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // قناة مكافحة التلاعب
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ANTI_TAMPERING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "calculateAppHash" -> result.success(calculateAppHash())
                "getPackageName" -> result.success(packageName)
                "getCertificateHash" -> result.success(getCertificateHash())
                "detectDangerousLibraries" -> {
                    val libraries = call.arguments as List<String>
                    result.success(detectDangerousLibraries(libraries))
                }
                "detectCodeModification" -> result.success(detectCodeModification())
                "detectReverseEngineeringTools" -> result.success(detectReverseEngineeringTools())
                "detectVPN" -> result.success(detectVPN())
                "detectHackingTools" -> result.success(detectHackingTools())
                "checkDebugPorts" -> result.success(checkDebugPorts())
                "checkDebugSystemProperties" -> result.success(checkDebugSystemProperties())
                "detectMemoryModification" -> result.success(detectMemoryModification())
                "detectHooks" -> result.success(detectHooks())
                "detectLibraryTampering" -> result.success(detectLibraryTampering())
                "detectRuntimeCodeModification" -> result.success(detectRuntimeCodeModification())
                "isFrameworkActive" -> {
                    val framework = call.arguments as String
                    result.success(isFrameworkActive(framework))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isDeviceRooted(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )

        for (path in paths) {
            if (File(path).exists()) {
                return true
            }
        }

        try {
            Runtime.getRuntime().exec("su")
            return true
        } catch (e: Exception) {
            // su not found
        }

        return false
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun checkSuspiciousProperties(): Boolean {
        val props = System.getProperties()
        val suspiciousProps = listOf("ro.debuggable", "ro.secure", "service.adb.root")

        for (prop in suspiciousProps) {
            val value = props.getProperty(prop)
            if (value == "1" || value == "0") {
                return true
            }
        }
        return false
    }

    private fun checkSuCommand(): Boolean {
        val commands = arrayOf("which su", "su -v", "su --version")

        for (command in commands) {
            try {
                val process = Runtime.getRuntime().exec(command)
                val result = process.inputStream.bufferedReader().readText()
                if (result.isNotEmpty()) {
                    return true
                }
            } catch (e: Exception) {
                // Command failed
            }
        }
        return false
    }

    private fun checkSELinuxEnforcement(): Boolean {
        try {
            val process = Runtime.getRuntime().exec("getenforce")
            val result = process.inputStream.bufferedReader().readText().trim()
            return result != "Enforcing"
        } catch (e: Exception) {
            return false
        }
    }

    private fun enableScreenshotPrevention() {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    private fun disableScreenshotPrevention() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun enableScreenRecordingPrevention() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun calculateAppHash(): String {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            val signatures = packageInfo.signatures
            val messageDigest = MessageDigest.getInstance("SHA-256")

            for (signature in signatures) {
                messageDigest.update(signature.toByteArray())
            }

            val digest = messageDigest.digest()
            return digest.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            return ""
        }
    }

    private fun getCertificateHash(): String {
        try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }

            val messageDigest = MessageDigest.getInstance("SHA-256")
            val signature = signatures[0]
            messageDigest.update(signature.toByteArray())

            val digest = messageDigest.digest()
            return digest.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            return ""
        }
    }

    private fun detectDangerousLibraries(libraries: List<String>): Boolean {
        for (library in libraries) {
            try {
                Class.forName(library)
                return true
            } catch (e: ClassNotFoundException) {
                // Library not found
            }
        }

        // Check for native libraries
        val libDir = File(applicationInfo.nativeLibraryDir)
        if (libDir.exists()) {
            val files = libDir.listFiles()
            if (files != null) {
                for (file in files) {
                    for (library in libraries) {
                        if (file.name.contains(library)) {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    private fun detectCodeModification(): Boolean {
        try {
            // Check application checksum
            val apkFile = File(applicationInfo.sourceDir)
            val messageDigest = MessageDigest.getInstance("SHA-256")
            val fileBytes = apkFile.readBytes()
            messageDigest.update(fileBytes)

            val currentHash = messageDigest.digest().joinToString("") { "%02x".format(it) }
            val originalHash = getOriginalAppHash()

            return currentHash != originalHash
        } catch (e: Exception) {
            return true
        }
    }

    private fun detectReverseEngineeringTools(): Boolean {
        val dangerousApps = listOf(
            "com.topjohnwu.magisk",
            "com.saurik.substrate",
            "de.robv.android.xposed.installer",
            "com.android.vending.billing.InAppBillingService.LUCK",
            "com.android.vending.billing.InAppBillingService.LOCK",
            "com.chelpus.lackypatch",
            "com.dimonvideo.luckypatcher",
            "com.forpda.lp",
            "com.android.vending.billing.InAppBillingService.LUCK",
            "com.android.vendinc",
            "org.jf.dexlib",
            "com.scottyab.rootbeer.sample",
            "org.mewtwo.classfinder",
            "org.cf.dex2jar"
        )

        for (app in dangerousApps) {
            if (isAppInstalled(app)) {
                return true
            }
        }

        return false
    }

    private fun detectVPN(): Boolean {
        val networkInterfaces = java.net.NetworkInterface.getNetworkInterfaces()
        while (networkInterfaces.hasMoreElements()) {
            val networkInterface = networkInterfaces.nextElement()
            val interfaceName = networkInterface.name
            if (interfaceName.contains("tun") || interfaceName.contains("ppp") || interfaceName.contains("pptp")) {
                return true
            }
        }
        return false
    }

    private fun detectHackingTools(): Boolean {
        val hackingTools = listOf(
            "com.termux",
            "com.koushikdutta.rommanager",
            "com.dimonvideo.luckypatcher",
            "com.chelpus.lackypatch",
            "com.ramdroid.appquarantine",
            "com.noshufou.android.su",
            "com.noshufou.android.su.elite",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.thirdparty.superuser",
            "com.yellowes.su"
        )

        for (tool in hackingTools) {
            if (isAppInstalled(tool)) {
                return true
            }
        }

        return false
    }

    private fun checkDebugPorts(): Boolean {
        val debugPorts = listOf(5037, 5555, 8000, 8080, 8100)
        for (port in debugPorts) {
            try {
                val socket = java.net.Socket("localhost", port)
                socket.close()
                return true
            } catch (e: Exception) {
                // Port not open
            }
        }
        return false
    }

    private fun checkDebugSystemProperties(): Boolean {
        val debugProps = mapOf(
            "ro.debuggable" to "1",
            "service.adb.root" to "1",
            "ro.secure" to "0"
        )

        for ((prop, dangerousValue) in debugProps) {
            val value = System.getProperty(prop)
            if (value == dangerousValue) {
                return true
            }
        }

        return false
    }

    private fun detectMemoryModification(): Boolean {
        try {
            // Check for memory tampering tools
            val memoryTools = listOf(
                "com.saurik.substrate",
                "com.android.art.internal.MemoryMonitor",
                "de.robv.android.xposed.XposedBridge"
            )

            for (tool in memoryTools) {
                try {
                    Class.forName(tool)
                    return true
                } catch (e: ClassNotFoundException) {
                    // Not found
                }
            }

            // Check for memory manipulation
            val runtime = Runtime.getRuntime()
            val maxMemory = runtime.maxMemory()
            val allocatedMemory = runtime.totalMemory()
            val freeMemory = runtime.freeMemory()

            // Suspicious if allocated memory is too high
            if (allocatedMemory > maxMemory * 0.9) {
                return true
            }

            return false
        } catch (e: Exception) {
            return true
        }
    }

    private fun detectHooks(): Boolean {
        try {
            // Check for common hooking frameworks
            val hookingFrameworks = listOf(
                "de.robv.android.xposed.XposedBridge",
                "de.robv.android.xposed.XposedHelpers",
                "com.saurik.substrate.MS",
                "com.android.internal.os.ZygoteInit"
            )

            for (framework in hookingFrameworks) {
                try {
                    Class.forName(framework)
                    return true
                } catch (e: ClassNotFoundException) {
                    // Not found
                }
            }

            // Check for PLT hooks
            val process = Runtime.getRuntime().exec("cat /proc/self/maps")
            val reader = process.inputStream.bufferedReader()
            reader.useLines { lines ->
                lines.forEach { line ->
                    if (line.contains("frida") || line.contains("xposed") || line.contains("substrate")) {
                        return true
                    }
                }
            }

            return false
        } catch (e: Exception) {
            return false
        }
    }

    private fun detectLibraryTampering(): Boolean {
        try {
            // Check native libraries checksums
            val libDir = File(applicationInfo.nativeLibraryDir)
            if (libDir.exists()) {
                val files = libDir.listFiles()
                if (files != null) {
                    for (file in files) {
                        val currentHash = calculateFileHash(file)
                        val originalHash = getOriginalLibraryHash(file.name)
                        if (currentHash != originalHash) {
                            return true
                        }
                    }
                }
            }

            return false
        } catch (e: Exception) {
            return true
        }
    }

    private fun detectRuntimeCodeModification(): Boolean {
        try {
            // Check for runtime code injection
            val stackTrace = Thread.currentThread().stackTrace
            for (element in stackTrace) {
                val className = element.className
                if (className.contains("java.lang.reflect.Proxy") ||
                    className.contains("java.lang.reflect.Method") ||
                    className.contains("android.os.Debug")) {
                    return true
                }
            }

            return false
        } catch (e: Exception) {
            return true
        }
    }

    private fun isFrameworkActive(framework: String): Boolean {
        when (framework.toLowerCase()) {
            "xposed" -> {
                try {
                    Class.forName("de.robv.android.xposed.XposedBridge")
                    return true
                } catch (e: ClassNotFoundException) {
                    return false
                }
            }
            "frida" -> {
                val frida = File("/data/local/tmp/frida-server")
                return frida.exists()
            }
            "cydia substrate" -> {
                try {
                    Class.forName("com.saurik.substrate.MS")
                    return true
                } catch (e: ClassNotFoundException) {
                    return false
                }
            }
            else -> return false
        }
    }

    private fun isDebuggable(): Boolean {
        return (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    private fun isDebuggerConnected(): Boolean {
        return android.os.Debug.isDebuggerConnected()
    }

    private fun isAppIntegrityValid(): Boolean {
        // التحقق من توقيع التطبيق
        val currentHash = calculateAppHash()
        val expectedHash = getExpectedAppHash()

        return currentHash == expectedHash
    }

    private fun getExpectedAppHash(): String {
        // يجب تخزين التوقيع المتوقع بشكل آمن
        return "YOUR_EXPECTED_APP_HASH_HERE"
    }

    private fun getOriginalAppHash(): String {
        // يجب تخزين hash التطبيق الأصلي
        return "YOUR_ORIGINAL_APP_HASH_HERE"
    }

    private fun calculateFileHash(file: File): String {
        try {
            val messageDigest = MessageDigest.getInstance("SHA-256")
            val fileBytes = file.readBytes()
            messageDigest.update(fileBytes)

            val digest = messageDigest.digest()
            return digest.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            return ""
        }
    }

    private fun getOriginalLibraryHash(libraryName: String): String {
        // يجب تخزين hashes المكتبات الأصلية
        return when (libraryName) {
            "libflutter.so" -> "YOUR_FLUTTER_LIB_HASH"
            "libapp.so" -> "YOUR_APP_LIB_HASH"
            else -> ""
        }
    }
}