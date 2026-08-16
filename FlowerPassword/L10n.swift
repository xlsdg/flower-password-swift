import FlowerPasswordCore

/// Localized UI strings for the three supported languages. Kept as plain
/// Swift data (instead of .lproj bundles) so the in-app language setting
/// can switch the whole UI instantly at runtime, without relaunching.
struct L10n: Sendable {
    // App & form
    let appTitle: String
    let close: String
    let passwordPlaceholder: String
    let keyPlaceholder: String
    let prefixPlaceholder: String
    let suffixPlaceholder: String
    let generateButton: String
    let lengthUnit: String
    let hintPassword: String
    let hintKey: String
    let hintWebsite: String

    // Tray
    let trayTooltip: String
    let trayShow: String
    let trayQuit: String

    // Tray menu
    let menuTheme: String
    let menuLanguage: String
    let menuAutoLaunch: String
    let menuCheckUpdate: String
    let menuGlobalShortcut: String
    let menuAutoType: String
    let themeLight: String
    let themeDark: String
    let themeAuto: String
    let languageZhCN: String
    let languageZhTW: String
    let languageEnUS: String
    let languageAuto: String

    // Dialogs
    let quitMessage: String
    let quitConfirm: String
    let quitCancel: String
    let shortcutRegisterFailedMessage: @Sendable (_ shortcut: String) -> String
    let autoLaunchFailedMessage: String
    let autoTypePermissionMessage: String
    let autoTypePermissionDetail: String
    let updateVersionMessage: @Sendable (_ version: String) -> String
    let updateAvailableMessage: @Sendable (_ current: String, _ latest: String) -> String
    let updateAvailableDetail: String
    let updateInstallDetail: String
    let updateInstallButton: String
    let updateLaterButton: String
    let updateInstallFailedMessage: String
    let updateOpenPageButton: String
    let updateNoUpdateMessage: String
    let updateErrorMessage: String
    let ok: String
    let cancel: String

    // Update failure details — one per SelfUpdater.UpdateError case,
    // rendered by UpdateChecker.
    let updateFailureTranslocated: String
    let updateFailureNotWritable: @Sendable (_ directory: String) -> String
    let updateFailureUnsafeVolume: @Sendable (_ directory: String) -> String
    /// Also reported for the release-manifest request, so the wording must
    /// not assume the archive download.
    let updateFailureHTTPStatus: @Sendable (_ status: Int) -> String
    let updateFailureTooLarge: @Sendable (_ bytes: Int, _ limit: Int) -> String
    let updateFailureInvalidSignature: String
    let updateFailureExtraction: @Sendable (_ status: Int32) -> String
    let updateFailureAppMissing: String
    let updateFailureWrongBundle: @Sendable (_ reason: String) -> String

    static func strings(for language: ResolvedLanguage) -> L10n {
        switch language {
        case .zhCN: .zhCN
        case .zhTW: .zhTW
        case .enUS: .enUS
        }
    }

    func themeName(_ mode: ThemeMode) -> String {
        switch mode {
        case .light: themeLight
        case .dark: themeDark
        case .auto: themeAuto
        }
    }

    func languageName(_ mode: LanguageMode) -> String {
        switch mode {
        case .zhCN: languageZhCN
        case .zhTW: languageZhTW
        case .enUS: languageEnUS
        case .auto: languageAuto
        }
    }

    static let zhCN = L10n(
        appTitle: "Flower Password",
        close: "关闭",
        passwordPlaceholder: "记忆密码",
        keyPlaceholder: "区分代号",
        prefixPlaceholder: "区分代号前缀",
        suffixPlaceholder: "区分代号后缀",
        generateButton: "生成密码(点击复制)",
        lengthUnit: "位",
        hintPassword: "记忆密码:可选择一个简单易记的密码,用于生成其他高强度密码。",
        hintKey: "区分代号:用于区别不同用途密码的简短代号,如淘宝账号可用\u{201C}taobao\u{201D}或\u{201C}tb\u{201D}等。",
        hintWebsite: "官网地址:",
        trayTooltip: "花密",
        trayShow: "显示",
        trayQuit: "退出",
        menuTheme: "主题",
        menuLanguage: "语言",
        menuAutoLaunch: "开机自启",
        menuCheckUpdate: "检查更新",
        menuGlobalShortcut: "全局快捷键",
        menuAutoType: "自动键入",
        themeLight: "浅色",
        themeDark: "深色",
        themeAuto: "自动",
        languageZhCN: "简体中文",
        languageZhTW: "繁體中文",
        languageEnUS: "English",
        languageAuto: "自动",
        quitMessage: "确定退出?",
        quitConfirm: "确定",
        quitCancel: "取消",
        shortcutRegisterFailedMessage: { "无法注册全局快捷键(\($0))。该快捷键可能已被其他应用占用。" },
        autoLaunchFailedMessage: "无法配置开机自启功能,请检查系统权限设置。",
        autoTypePermissionMessage: "需要辅助功能权限",
        autoTypePermissionDetail: "请在「系统设置 → 隐私与安全性 → 辅助功能」中允许 FlowerPassword,然后重新开启自动键入。",
        updateVersionMessage: { "当前版本:\($0)" },
        updateAvailableMessage: { "发现新版本!\n\n当前版本:\($0)\n最新版本:\($1)" },
        updateAvailableDetail: "点击确定将打开浏览器,跳转到下载页面。",
        updateInstallDetail: "将自动下载并安装更新,完成后应用会自动重启。",
        updateInstallButton: "安装并重启",
        updateLaterButton: "稍后",
        updateInstallFailedMessage: "自动更新失败。",
        updateOpenPageButton: "打开下载页面",
        updateNoUpdateMessage: "您正在使用最新版本。",
        updateErrorMessage: "检查更新失败。",
        ok: "确定",
        cancel: "取消",
        updateFailureTranslocated: "应用正在从隔离路径运行。请将 FlowerPassword.app 移动到「应用程序」文件夹后重试。",
        updateFailureNotWritable: { "没有权限替换 \($0) 中的应用。" },
        updateFailureUnsafeVolume: { "\($0) 所在的宗卷忽略文件归属权,在此处原地更新并不安全。" },
        updateFailureHTTPStatus: { "请求失败,HTTP 状态码 \($0)。" },
        updateFailureTooLarge: { "下载内容为 \($0) 字节,超出 \($1) 字节的上限。" },
        updateFailureInvalidSignature: "更新包未通过签名校验,文件可能已损坏或被篡改。",
        updateFailureExtraction: { "无法解压更新包(ditto 退出码 \($0))。" },
        updateFailureAppMissing: "更新包中没有找到应用程序。",
        updateFailureWrongBundle: { "下载的应用未通过校验:\($0)。" }
    )

    static let zhTW = L10n(
        appTitle: "Flower Password",
        close: "關閉",
        passwordPlaceholder: "記憶密碼",
        keyPlaceholder: "區分代號",
        prefixPlaceholder: "區分代號前綴",
        suffixPlaceholder: "區分代號後綴",
        generateButton: "生成密碼(點擊複製)",
        lengthUnit: "位",
        hintPassword: "記憶密碼:可選擇一個簡單易記的密碼,用於生成其他高強度密碼。",
        hintKey: "區分代號:用於區別不同用途密碼的簡短代號,如淘寶帳號可用「taobao」或「tb」等。",
        hintWebsite: "官網地址:",
        trayTooltip: "花密",
        trayShow: "顯示",
        trayQuit: "退出",
        menuTheme: "主題",
        menuLanguage: "語言",
        menuAutoLaunch: "開機自啟",
        menuCheckUpdate: "檢查更新",
        menuGlobalShortcut: "全域快速鍵",
        menuAutoType: "自動鍵入",
        themeLight: "淺色",
        themeDark: "深色",
        themeAuto: "自動",
        languageZhCN: "簡體中文",
        languageZhTW: "繁體中文",
        languageEnUS: "English",
        languageAuto: "自動",
        quitMessage: "確定退出?",
        quitConfirm: "確定",
        quitCancel: "取消",
        shortcutRegisterFailedMessage: { "無法註冊全域快速鍵(\($0))。該快速鍵可能已被其他應用程式佔用。" },
        autoLaunchFailedMessage: "無法配置開機自啟功能,請檢查系統權限設定。",
        autoTypePermissionMessage: "需要輔助功能權限",
        autoTypePermissionDetail: "請在「系統設定 → 隱私權與安全性 → 輔助使用」中允許 FlowerPassword,然後重新開啟自動鍵入。",
        updateVersionMessage: { "目前版本:\($0)" },
        updateAvailableMessage: { "發現新版本!\n\n目前版本:\($0)\n最新版本:\($1)" },
        updateAvailableDetail: "點擊確定將開啟瀏覽器,跳轉至下載頁面。",
        updateInstallDetail: "將自動下載並安裝更新,完成後應用程式會自動重啟。",
        updateInstallButton: "安裝並重啟",
        updateLaterButton: "稍後",
        updateInstallFailedMessage: "自動更新失敗。",
        updateOpenPageButton: "開啟下載頁面",
        updateNoUpdateMessage: "您正在使用最新版本。",
        updateErrorMessage: "檢查更新失敗。",
        ok: "確定",
        cancel: "取消",
        updateFailureTranslocated: "應用程式正在從隔離路徑執行。請將 FlowerPassword.app 移動到「應用程式」資料夾後重試。",
        updateFailureNotWritable: { "沒有權限替換 \($0) 中的應用程式。" },
        updateFailureUnsafeVolume: { "\($0) 所在的儲存空間忽略檔案擁有權,在此處原地更新並不安全。" },
        updateFailureHTTPStatus: { "請求失敗,HTTP 狀態碼 \($0)。" },
        updateFailureTooLarge: { "下載內容為 \($0) 位元組,超出 \($1) 位元組的上限。" },
        updateFailureInvalidSignature: "更新包未通過簽章驗證,檔案可能已損毀或遭竄改。",
        updateFailureExtraction: { "無法解壓縮更新包(ditto 退出碼 \($0))。" },
        updateFailureAppMissing: "更新包中找不到應用程式。",
        updateFailureWrongBundle: { "下載的應用程式未通過驗證:\($0)。" }
    )

    static let enUS = L10n(
        appTitle: "Flower Password",
        close: "Close",
        passwordPlaceholder: "Memory Password",
        keyPlaceholder: "Distinction Code",
        prefixPlaceholder: "Prefix",
        suffixPlaceholder: "Suffix",
        generateButton: "Generate Password (Click to Copy)",
        lengthUnit: " chars",
        hintPassword: "Memory Password: A simple password to generate strong passwords.",
        hintKey: "Distinction Code: A short code for different accounts, e.g., \"taobao\" or \"tb\".",
        hintWebsite: "Official Website: ",
        trayTooltip: "FlowerPassword",
        trayShow: "Show",
        trayQuit: "Quit",
        menuTheme: "Theme",
        menuLanguage: "Language",
        menuAutoLaunch: "Launch at Login",
        menuCheckUpdate: "Check for Updates",
        menuGlobalShortcut: "Global Shortcut",
        menuAutoType: "Auto-Type",
        themeLight: "Light",
        themeDark: "Dark",
        themeAuto: "Auto",
        languageZhCN: "简体中文",
        languageZhTW: "繁體中文",
        languageEnUS: "English",
        languageAuto: "Auto",
        quitMessage: "Are you sure you want to quit?",
        quitConfirm: "Quit",
        quitCancel: "Cancel",
        shortcutRegisterFailedMessage: {
            "Failed to register global shortcut (\($0)). The shortcut may be already in use by another application."
        },
        autoLaunchFailedMessage: "Failed to configure launch at login. Please check system permissions.",
        autoTypePermissionMessage: "Accessibility Permission Required",
        autoTypePermissionDetail:
            "Allow FlowerPassword in System Settings → Privacy & Security → Accessibility, then enable Auto-Type again.",
        updateVersionMessage: { "Current version: \($0)" },
        updateAvailableMessage: { "A new version is available!\n\nCurrent: \($0)\nLatest: \($1)" },
        updateAvailableDetail: "Click OK to open the download page in your browser.",
        updateInstallDetail:
            "The update will be downloaded, verified, and installed automatically; the app then relaunches.",
        updateInstallButton: "Install and Relaunch",
        updateLaterButton: "Later",
        updateInstallFailedMessage: "Automatic update failed.",
        updateOpenPageButton: "Open Download Page",
        updateNoUpdateMessage: "You are using the latest version.",
        updateErrorMessage: "Failed to check for updates.",
        ok: "OK",
        cancel: "Cancel",
        updateFailureTranslocated:
            "The app is running from a translocated path. Move FlowerPassword.app to /Applications and try again.",
        updateFailureNotWritable: { "No permission to replace the app in \($0)." },
        updateFailureUnsafeVolume: {
            "The volume holding \($0) ignores file ownership, so in-place updates are unsafe there."
        },
        updateFailureHTTPStatus: { "Request failed with HTTP \($0)." },
        updateFailureTooLarge: { "The download is \($0) bytes, above the \($1)-byte limit." },
        updateFailureInvalidSignature:
            "The update failed signature verification; the download may be corrupted or tampered with.",
        updateFailureExtraction: { "Could not extract the update archive (ditto exited with \($0))." },
        updateFailureAppMissing: "The update archive does not contain an app bundle.",
        updateFailureWrongBundle: { "The downloaded app failed validation: \($0)." }
    )
}
