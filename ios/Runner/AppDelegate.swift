import UIKit
import Flutter
import Security
import LocalAuthentication

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private let ROOT_DETECTION_CHANNEL = "com.example.secure_app/root_detection"
    private let SCREENSHOT_CHANNEL = "com.example.secure_app/screenshot_prevention"
    private let ANTI_TAMPERING_CHANNEL = "com.example.secure_app/anti_tampering"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // تفعيل حماية الأمان
        setupSecurityMeasures()

        // التحقق من الجذر
        if isJailbroken() {
            exit(0)
        }

        let controller = window?.rootViewController as! FlutterViewController

        // إعداد القنوات
        setupMethodChannels(controller: controller)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupSecurityMeasures() {
        // منع لقطات الشاشة
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preventScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        // حماية البيانات في الخلفية
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // التحقق من التصحيح
        if isBeingDebugged() {
            exit(0)
        }
    }

    private func setupMethodChannels(controller: FlutterViewController) {
        // قناة كشف الجيلبريك
        let rootChannel = FlutterMethodChannel(
            name: ROOT_DETECTION_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )

        rootChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "checkJailbreak":
                result(self.isJailbroken())
            case "checkWriteOutsideSandbox":
                result(self.canWriteOutsideSandbox())
            case "checkForkAbility":
                result(self.canFork())
            case "checkSuspiciousSchemes":
                result(self.hasSuspiciousSchemes())
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // قناة منع لقطات الشاشة
        let screenshotChannel = FlutterMethodChannel(
            name: SCREENSHOT_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )

        screenshotChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "enableScreenshotPrevention":
                self.enableScreenshotPrevention()
                result(true)
            case "disableScreenshotPrevention":
                self.disableScreenshotPrevention()
                result(true)
            case "setupScreenshotObserver":
                self.setupScreenshotObserver()
                result(true)
            case "removeScreenshotObserver":
                self.removeScreenshotObserver()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // قناة مكافحة التلاعب
        let antiTamperingChannel = FlutterMethodChannel(
            name: ANTI_TAMPERING_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )

        antiTamperingChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            switch call.method {
            case "calculateAppHash":
                result(self.calculateAppHash())
            case "getPackageName":
                result(Bundle.main.bundleIdentifier)
            case "getCertificateHash":
                result(self.getCertificateHash())
            case "detectDangerousLibraries":
                if let libraries = call.arguments as? [String] {
                    result(self.detectDangerousLibraries(libraries))
                } else {
                    result(false)
                }
            case "detectCodeModification":
                result(self.detectCodeModification())
            case "detectReverseEngineeringTools":
                result(self.detectReverseEngineeringTools())
            case "isDebugging":
                result(self.isBeingDebugged())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else

        // التحقق من الملفات المشبوهة
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh",
            "/usr/libexec/sftp-server",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // التحقق من الكتابة خارج sandbox
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // لا يمكن الكتابة - الجهاز غير مكسور
        }

        // التحقق من المخططات المشبوهة
        if UIApplication.shared.canOpenURL(URL(string: "cydia://")!) {
            return true
        }

        // التحقق من fork
        let pid = fork()
        if pid >= 0 {
            if pid == 0 {
                exit(0)
            }
            return true
        }

        return false
        #endif
    }

    private func isBeingDebugged() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    @objc private func preventScreenshot() {
        // معالجة التقاط الشاشة
        if let window = UIApplication.shared.keyWindow {
            let blurEffect = UIBlurEffect(style: .light)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = window.bounds
            blurView.tag = 999
            window.addSubview(blurView)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.viewWithTag(999)?.removeFromSuperview()
            }
        }
    }

    @objc private func applicationDidEnterBackground() {
        // إخفاء المحتوى الحساس
        if let window = UIApplication.shared.keyWindow {
            let blurEffect = UIBlurEffect(style: .light)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = window.bounds
            blurView.tag = 998
            window.addSubview(blurView)
        }
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        if let window = UIApplication.shared.keyWindow {
            window.viewWithTag(998)?.removeFromSuperview()
        }
    }

    private func enableScreenshotPrevention() {
        if let window = UIApplication.shared.keyWindow {
            window.makeSecure()
        }
    }

    private func disableScreenshotPrevention() {
        if let window = UIApplication.shared.keyWindow {
            window.removeSecure()
        }
    }

    private func setupScreenshotObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotTaken),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    private func removeScreenshotObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    @objc private func screenshotTaken() {
        // إخطار Flutter
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: SCREENSHOT_CHANNEL,
                binaryMessenger: controller.binaryMessenger
            )
            channel.invokeMethod("onScreenshotDetected", arguments: nil)
        }
    }

    private func calculateAppHash() -> String {
        guard let path = Bundle.main.path(forResource: "AppIcon", ofType: "png") else {
            return ""
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let hash = data.sha256()
            return hash.map { String(format: "%02x", $0) }.joined()
        } catch {
            return ""
        }
    }

    private func getCertificateHash() -> String {
        // Get embedded mobile provisioning
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return ""
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let hash = data.sha256()
            return hash.map { String(format: "%02x", $0) }.joined()
        } catch {
            return ""
        }
    }

    private func detectDangerousLibraries(_ libraries: [String]) -> Bool {
        for library in libraries {
            if let _ = dlopen(library, RTLD_NOLOAD) {
                return true
            }
        }
        return false
    }

    private func detectCodeModification() -> Bool {
        // التحقق من سلامة التطبيق
        guard let executablePath = Bundle.main.executablePath else {
            return true
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: executablePath))
            let hash = data.sha256()
            let hashString = hash.map { String(format: "%02x", $0) }.joined()

            // مقارنة مع التوقيع المعروف
            let knownHash = getKnownExecutableHash()
            return hashString != knownHash
        } catch {
            return true
        }
    }

    private func detectReverseEngineeringTools() -> Bool {
        let suspiciousApps = [
            "Flex",
            "Clutch",
            "iGameGuardian",
            "iMemEditor",
            "FLEXLoader",
            "GameGem",
            "cycript",
            "Frida",
            "SSLKillSwitch"
        ]

        for app in suspiciousApps {
            if Bundle(identifier: "com.\(app.lowercased())") != nil {
                return true
            }
        }

        // التحقق من وجود frida server
        if let _ = dlopen("/usr/sbin/frida-server", RTLD_NOLOAD) {
            return true
        }

        return false
    }

    private func canWriteOutsideSandbox() -> Bool {
        let paths = [
            "/private/",
            "/etc/",
            "/var/"
        ]

        for path in paths {
            do {
                let testPath = path + "test_\(UUID().uuidString).txt"
                try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(atPath: testPath)
                return true
            } catch {
                // Can't write - continue checking
            }
        }

        return false
    }

    private func canFork() -> Bool {
        let pid = fork()
        if pid >= 0 {
            if pid == 0 {
                exit(0)
            }
            return true
        }
        return false
    }

    private func hasSuspiciousSchemes() -> Bool {
        let schemes = [
            "cydia://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://"
        ]

        for scheme in schemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                return true
            }
        }

        return false
    }

    private func getKnownExecutableHash() -> String {
        // يجب تخزين hash التطبيق المعروف
        return "YOUR_KNOWN_EXECUTABLE_HASH"
    }
}

// Extension لإضافة الحماية للنافذة
extension UIWindow {
    func makeSecure() {
        let field = UITextField()
        field.isSecureTextEntry = true
        self.addSubview(field)
        field.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        field.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.first?.addSublayer(self.layer)
    }

    func removeSecure() {
        for subview in self.subviews {
            if subview is UITextField {
                subview.removeFromSuperview()
            }
        }
    }
}

// Extension لحساب SHA256
extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

// كود لكشف التصحيح
let P_TRACED: Int32 = 0x00000800
let CTL_KERN = 1
let KERN_PROC = 14
let KERN_PROC_PID = 1

// تراكيب البيانات المطلوبة
struct kinfo_proc {
    var kp_proc: extern_proc
    var kp_eproc: eproc
}

struct extern_proc {
    var p_un: proc_undata
    var p_vmspace: UInt64
    var p_sigacts: UInt64
    var p_flag: Int32
    var p_stat: UInt8
    var p_pid: Int32
    var p_oppid: Int32
    var p_dupfd: Int32
    var user_stack: UInt64
    var exit_thread: UInt64
    var p_debugger: Int32
    var sigwait: Int32
    var p_estcpu: UInt32
    var p_cpticks: Int32
    var p_pctcpu: UInt32
    var p_wchan: UInt64
    var p_wmesg: UInt64
    var p_swtime: UInt32
    var p_slptime: UInt32
    var p_realtimer: itimerval
    var p_rtime: timeval
    var p_uticks: UInt64
    var p_sticks: UInt64
    var p_iticks: UInt64
    var p_traceflag: Int32
    var p_tracep: UInt64
    var p_siglist: Int32
    var p_textvp: UInt64
    var p_holdcnt: Int32
    var p_sigmask: UInt32
    var p_sigignore: UInt32
    var p_sigcatch: UInt32
    var p_priority: UInt8
    var p_usrpri: UInt8
    var p_nice: Int8
    var p_comm: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var p_pgrp: UInt64
    var p_addr: UInt64
    var p_xstat: UInt16
    var p_acflag: UInt16
    var p_ru: UInt64
}

struct proc_undata {
    var p_starttime: timeval
}

struct timeval {
    var tv_sec: Int64
    var tv_usec: Int32
}

struct itimerval {
    var it_interval: timeval
    var it_value: timeval
}

struct eproc {
    var e_paddr: UInt64
    var e_sess: UInt64
    var e_pcred: pcred
    var e_ucred: ucred
    var e_vm: vmspace
    var e_ppid: Int32
    var e_pgid: Int32
    var e_jobc: Int16
    var e_tdev: Int32
    var e_tpgid: Int32
    var e_tsess: UInt64
    var e_wmesg: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var e_xsize: Int32
    var e_xrssize: Int16
    var e_xccount: Int16
    var e_xswrss: Int16
    var e_flag: Int32
    var e_login: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var e_spare: (Int32, Int32, Int32, Int32)
}

struct pcred {
    var pc_lock: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var pc_ucred: UInt64
    var p_ruid: uid_t
    var p_svuid: uid_t
    var p_rgid: gid_t
    var p_svgid: gid_t
    var p_refcnt: Int32
}

struct ucred {
    var cr_ref: Int32
    var cr_uid: uid_t
    var cr_ngroups: Int16
    var cr_groups: (gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t, gid_t)
}

struct vmspace {
    var dummy: Int32
    var dummy2: UInt64
    var dummy3: (Int32, Int32)
    var dummy4: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64)
}