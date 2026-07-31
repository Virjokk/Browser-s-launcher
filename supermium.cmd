<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Supermium и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию браузера (W10+, W7+) и разрядность (x64/x86), указав нужное значение в $Edition и $Bitness.
:: Портабельность обеспечивается ключами запуска --disable-machine-id, --disable-encryption.
:: Если указать свой профиль в ключе --user-data-dir, то подхватится он, иначе создается новый с преднастройками
:: от Insorg (https://forum.ru-board.com/topic.cgi?forum=5&topic=51193&start=760#4).
:: Рядом со скриптом создаётся папка App (имя настраиваемо), в которой будет расположена сборка.
:: Удаляемые папки, файлы, ключи запуска добавляются отдельной строкой в двойных кавычках, ненужное - комментируется/удаляется.
:: В переменной $SetupExclude можно указать файлы и папки, исключаемые из состава браузера при установке/обновлении.

@echo off
cd /d "%~dp0"
powershell.exe -NoP -NoL -NonI -EP Bypass -c "&{[ScriptBlock]::Create((gc -lit '%~f0' -enc UTF8) -join [Char]10).Invoke()}"
exit /b
#>

# ============================================================================
# ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ
# ============================================================================

$CheckInterval = 3 # интервал проверки обновлений в днях, если 0, будет проверять при каждом запуске
$CleanInterval = 7 # интервал очистки профиля и реестра в днях, если 0, будет чистить при каждом завершении
$RunMode = 0 # 0 - обычный режим, 1 - только запуск, 2 - только проверка/установка обновлений
$CreateShortcut = $false # создать ярлык на рабочем столе
$AskUpdate = $true # перед обновлением спрашивать
$Backup = $false # при обновлении создавать в папке батника zip-бэкап профиля
$MakeStub = $false # создавать взамен удаляемых в профиле папок ($DelDirs) файлы-заглушки нулевого размера
$Edition = 0 # 0 - для современных Windows 10-11, 1 - для Windows 7-8
$Bitness = "x64" # для 32bit-версии указать "x86", для W10+ 32bit-версии нет
$AppDir = "App" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$BrowserMode = 0 # 0 - Portable, 1 - Ungoogled Portable, 2 - Classic Portable, 3 - Classic Ungoogled Portable
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # ключи запуска браузера
   "--user-data-dir=`"..\Profile`""
   "--disable-machine-id"
   "--disable-encryption"
   "--disable-encryption-win"
   "--no-default-browser-check"
#   "--disk-cache-dir=nul"
#   "--disable-gpu-shader-disk-cache"
#   "--gpu-disk-cache-size-kb=1"
#   "--disk-cache-size=1"
   "--disable-search-engine-collection"
   "--disable-sharing-hub"
#   "--disable-direct-write"
   "--popups-to-tabs"
   "--show-avatar-button=never"
#   "--disable-features=PrintCompositorLPAC"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера (корнем считается папка профиля)
   "ActorSafetyLists"
   "AmountExtractionHeuristicRegexes"
   "Autofill*"
   "Avatars"
   "BrowserMetrics"
   "Cache"
   "CaptchaProviders"
   "CertificateRevocation"
   "ClientSidePhishing"
   "component_crx_cache"
   "CookieReadinessList"
   "Crashpad"
   "Crowd Deny"
   "DawnCache"
   "DawnGraphiteCache"
   "DawnWebGPUCache"
   "DesktopSharingHub"
   "extensions_crx_cache"
   "FileTypePolicies"
   "FirstPartySetsPreloaded"
   "Floc"
   "GPUCache"
   "GPUPersistentCache"
   "GraphiteDawnCache"
   "GrShaderCache"
   "hyphen-data"
   "InterventionPolicyDatabase"
   "MediaFoundationWidevineCdm"
   "MEIPreload"
   "OnDeviceHeadSuggestModel"
   "OpenCookieDatabase"
   "Optimization*"
   "OriginTrials"
   "PKIMetadata"
   "pnacl"
   "PrivacySandboxAttestationsPreloaded"
   "ProbabilisticRevealTokenRegistry"
   "RecoveryImproved"
   "SafetyTips"
   "Safe Browsing"
   "screen_ai"
   "segmentation_platform"
   "ShaderCache"
   "SSLErrorAssistant"
   "Subresource Filter"
   "ThirdPartyModuleList64"
   "TLSDeprecationConfig"
   "TpcdMetadata"
   "TrustTokenKeyCommitments"
   "WasmTtsEngine"
   "Webstore Downloads"
   "WidevineCdm"
   "ZxcvbnData"
   "Default\adblock_subscriptions"
   "Default\Autofill*"
   "Default\blob_storage"
   "Default\BudgetDatabase"
   "Default\Cache"
   "Default\chrome_cart_db"
   "Default\ClientCertificates"
   "Default\commerce_subscription_db"
   "Default\coupon_db"
   "Default\data_reduction_proxy_leveldb"
   "Default\databases"
   "Default\DawnGraphiteCache"
   "Default\DawnWebGPUCache"
   "Default\discount*"
   "Default\Download Service"
   "Default\Feature Engagement Tracker"
   "Default\feedv2"
   "Default\GCM Store"
   "Default\GPUCache"
   "Default\GraphiteDawnCache"
   "Default\GrShaderCache"
   "Default\JumpListIcons*"
   "Default\optimization_guide*"
   "Default\parcel_tracking_db"
   "Default\PersistentOriginTrials"
   "Default\Platform Notifications"
   "Default\Safe Browsing Network"
   "Default\Search Logos"
   "Default\Segmentation Platform"
   "Default\Service Worker\Cache*"
   "Default\ShaderCache"
   "Default\Shared Dictionary"
   "Default\shared_proto_db"
   "Default\Site Characteristics Database"
   "Default\Sync App Settings"
   "Default\VideoDecodeStats"
#  Удаление этих папок может повлиять на работу браузера, раскомментируйте, если знаете, что делаете
#   "Code Cache"
#   "Default\Code Cache"
#   "Default\IndexedDB\*.blob"
#   "Default\Storage"
#   "Default\Sync Data"
#   "Default\Sync Extension Settings"
#   "Default\System Cache"
#   "Default\Web Applications"
#   "Default\WebStorage"
)

$DelFiles = @( # файлы профиля, удаляемые после закрытия браузера
   "*.log"
   "*.tmp"
   "BrowserMetrics*"
   "Certificate*"
   "chrome_shutdown_ms*"
   "Crashpad*"
   "first_party_sets.*"
   "Safe Browsing*"
   "switch_core*"
   "Variations"
   "Default\*.bak"
   "Default\*.tmp"
   "Default\BookmarkMergedSurfaceOrdering"
   "Default\BrowsingTopics*"
   "Default\Conversions"
   "Default\DIPS*"
   "Default\DownloadMetadata"
   "Default\heavy_ad_intervention_opt_out*"
   "Default\History Provider Cache*"
   "Default\InterestGroups"
   "Default\MediaDeviceSalts"
   "Default\Network\Reporting and NEL*"
   "Default\Network\SCT Auditing Pending Reports"
   "Default\passkey_enclave_state"
   "Default\PreferredApps"
   "Default\PrivateAggregation"
   "Default\QuotaManager*"
   "Default\README"
   "Default\SCT Auditing Pending Reports"
   "Default\Shared Dictionary"
   "Default\SharedStorage"
#  Работа браузера во многом ломается, раскомментируйте, если приватность важнее потери данных
#   "*-journal"
#   "First Run"
#   "Last *"
#   "Default\*.db"
#   "Default\*.ldb"
#   "Default\*-journal"
#   "Default\Affiliation Database"
#   "Default\Device Bound Sessions"
#   "Default\Extension State\*.log"
#   "Default\Extension State\*.ldb"
#   "Default\Favicons"
#   "Default\File System\Origins\*.log"
#   "Default\History*"
#   "Default\Last Session*"
#   "Default\Last Tabs*"
#   "Default\Login Data For Account"
#   "Default\Local Extension Settings\cjpalhdlnbpafiamejdnhcphjbkeiagm\*.ldb"
#   "Default\Local Extension Settings\cjpalhdlnbpafiamejdnhcphjbkeiagm\*.log"
#   "Default\Local Extension Settings\cjpalhdlnbpafiamejdnhcphjbkeiagm\*.old"
#   "Default\Local Storage\leveldb\*.ldb" 
#   "Default\Local Storage\leveldb\*.ldb"
#   "Default\LOCK*"
#   "Default\log"
#   "Default\log.old"
#   "Default\MANIFEST-*"
#   "Default\Network Action Predictor*"
#   "Default\Network Persistent State"
#   "Default\Network\*-journal"
#   "Default\Network\Network*"
#   "Default\Network\Trust Tokens"
#   "Default\Network\TransportSecurity"
#   "Default\ServerCertificate"
#   "Default\Session Storage\*.ldb"
#   "Default\Session Storage\*.log"
#   "Default\Session Storage\*.old"
#   "Default\Shortcuts"
#   "Default\TransportSecurity"
#   "Default\trust*"
#   "Default\Top Sites*"
#   "Default\Visited Links*"
#   "Default\Vpn Tokens*"
#   "Default\WebStorage\*-journal"
#   "Default\WebStorage\QuotaManager*"
)

$DelReg = @( # данные реестра, удаляемые после закрытия браузера
   "HKEY_CURRENT_USER\SOFTWARE\Supermium"
)

$NoStub = @( # папки, для которых файлы-заглушки не создаются
   "Extension State"
   "Extensions"
   "File System"
   "IndexedDB"
   "Local Storage"
   "Local Extension Settings"
   "Managed Extension Settings"
   "Service Worker"
   "Sync Data"
   "Web Data"
)

$SetupExclude = @( # папки и файлы, исключаемые из состава браузера при установке/обновлении
   "NotoEmoji.ttf"
   "setup.exe"
   "Supermium\api-ms-win-crt-heap-l1-1-0.dll"
   "Supermium\api-ms-win-crt-math-l1-1-0.dll"
   "Supermium\api-ms-win-crt-runtime-l1-1-0.dll"
   "Supermium\api-ms-win-crt-stdio-l1-1-0.dll"
   "Supermium\api-ms-win-crt-string-l1-1-0.dll"
   "Supermium\chrome_proxy.exe"
   "Supermium\dbghelp.dll"
   "Supermium\p_advp32.dll"
   "Supermium\p_cry32.dll"
   "Supermium\p_cryptp.dll"
   "Supermium\p_dnsa.dll"
   "Supermium\p_dwma.dll"
   "Supermium\p_evapi.dll"
   "Supermium\p_iphlpa.dll"
   "Supermium\p_ntd.dll"
   "Supermium\p_ole.dll"
   "Supermium\p_powrpf.dll"
   "Supermium\p_s232.dll"
   "Supermium\p_setapi.dll"
   "Supermium\p_user.dll"
   "Supermium\p_usren.dll"
   "Supermium\p_vcrt.dll"
   "Supermium\p_whttp.dll"
   "Supermium\pdxg.dll"
   "Supermium\pwp_shd.dll"
   "Supermium\pwp_shl.dll"
   "Supermium\pwrp_k32.dll"
   "Supermium\Supermium*.cmd"
   "Supermium\ucrtbase.dll"
   "Supermium\uninstall.exe"
   "Supermium\numver\IwaKeyDistribution"
   "Supermium\numver\MEIPreload"
   "Supermium\numver\PrivacySandboxAttestationsPreloaded"
   "Supermium\numver\VisualElements"
   "Supermium\numver\WidevineCdm"
   "Supermium\numver\chrome_pwa_launcher.exe"
   "Supermium\numver\chrome_wer.dll"
   "Supermium\numver\dxcompiler.dll"
   "Supermium\numver\dxil.dll"
   "Supermium\numver\eventlog_provider.dll"
   "Supermium\numver\notification_helper.exe"
   "Supermium\numver\Locales\*FEMININE.pak"
   "Supermium\numver\Locales\*MASCULINE.pak"
   "Supermium\numver\Locales\*NEUTER.pak"
   "Supermium\numver\Locales\af.pak"
   "Supermium\numver\Locales\am.pak"
   "Supermium\numver\Locales\ar.pak"
   "Supermium\numver\Locales\as.pak"
   "Supermium\numver\Locales\az.pak"
   "Supermium\numver\Locales\be.pak"
   "Supermium\numver\Locales\bg.pak"
   "Supermium\numver\Locales\bn.pak"
   "Supermium\numver\Locales\bs.pak"
   "Supermium\numver\Locales\ca.pak"
   "Supermium\numver\Locales\cs.pak"
   "Supermium\numver\Locales\cy.pak"
   "Supermium\numver\Locales\da.pak"
   "Supermium\numver\Locales\de.pak"
   "Supermium\numver\Locales\el.pak"
   "Supermium\numver\Locales\en-GB.pak"
   "Supermium\numver\Locales\es-419.pak"
   "Supermium\numver\Locales\es.pak"
   "Supermium\numver\Locales\et.pak"
   "Supermium\numver\Locales\eu.pak"
   "Supermium\numver\Locales\fa.pak"
   "Supermium\numver\Locales\fi.pak"
   "Supermium\numver\Locales\fil.pak"
   "Supermium\numver\Locales\fr-CA.pak"
   "Supermium\numver\Locales\fr.pak"
   "Supermium\numver\Locales\gl.pak"
   "Supermium\numver\Locales\gu.pak"
   "Supermium\numver\Locales\he.pak"
   "Supermium\numver\Locales\hi.pak"
   "Supermium\numver\Locales\hr.pak"
   "Supermium\numver\Locales\hu.pak"
   "Supermium\numver\Locales\hy.pak"
   "Supermium\numver\Locales\id.pak"
   "Supermium\numver\Locales\is.pak"
   "Supermium\numver\Locales\it.pak"
   "Supermium\numver\Locales\ja.pak"
   "Supermium\numver\Locales\ka.pak"
   "Supermium\numver\Locales\kk.pak"
   "Supermium\numver\Locales\km.pak"
   "Supermium\numver\Locales\kn.pak"
   "Supermium\numver\Locales\ko.pak"
   "Supermium\numver\Locales\ky.pak"
   "Supermium\numver\Locales\lo.pak"
   "Supermium\numver\Locales\lt.pak"
   "Supermium\numver\Locales\lv.pak"
   "Supermium\numver\Locales\mk.pak"
   "Supermium\numver\Locales\ml.pak"
   "Supermium\numver\Locales\mn.pak"
   "Supermium\numver\Locales\mr.pak"
   "Supermium\numver\Locales\ms.pak"
   "Supermium\numver\Locales\my.pak"
   "Supermium\numver\Locales\nb.pak"
   "Supermium\numver\Locales\ne.pak"
   "Supermium\numver\Locales\nl.pak"
   "Supermium\numver\Locales\or.pak"
   "Supermium\numver\Locales\pa.pak"
   "Supermium\numver\Locales\pl.pak"
   "Supermium\numver\Locales\pt-BR.pak"
   "Supermium\numver\Locales\pt-PT.pak"
   "Supermium\numver\Locales\ro.pak"
   "Supermium\numver\Locales\si.pak"
   "Supermium\numver\Locales\sk.pak"
   "Supermium\numver\Locales\sl.pak"
   "Supermium\numver\Locales\sq.pak"
   "Supermium\numver\Locales\sr-Latn.pak"
   "Supermium\numver\Locales\sr.pak"
   "Supermium\numver\Locales\sv.pak"
   "Supermium\numver\Locales\sw.pak"
   "Supermium\numver\Locales\ta.pak"
   "Supermium\numver\Locales\te.pak"
   "Supermium\numver\Locales\th.pak"
   "Supermium\numver\Locales\tr.pak"
   "Supermium\numver\Locales\uk.pak"
   "Supermium\numver\Locales\ur.pak"
   "Supermium\numver\Locales\uz.pak"
   "Supermium\numver\Locales\vi.pak"
   "Supermium\numver\Locales\zh-CN.pak"
   "Supermium\numver\Locales\zh-HK.pak"
   "Supermium\numver\Locales\zh-TW.pak"
   "Supermium\numver\Locales\zu.pak"
)

$Trash = @( # папки и файлы вне профиля, подлежащие удалению после закрытия браузера
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================

$lastcheck = "18032026"
$lastclean = "18032026"
$current = "0"

$scriptName = $MyInvocation.Line -replace "[^']+'([A-Za-z]:\\.+)'[^']+",'$1'
$scriptPath = Split-Path -Path $scriptName -Parent

if (-not $AppDir) {$AppDir = 'App'}
$AppPath = Join-Path $scriptPath $AppDir

if ($Edition -ne 1) {$Edition = 0}
if ($Edition -eq 0 -or $Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = 'Supermium' + @(if ($Edition -ne 0) {' W7+'}) +" $Bitness" -join ''

$ExeName = 'chrome.exe'

if ($Switches | Where-Object {$_ -match '--user-data-dir[^\x22]+\x22([^\x22]+)\x22'}) {
   $profilePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $matches[1]))
} else {
   $profilePath = "$scriptPath\Profile"
}

# TLS 1.2/1.3 для Windows 11
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$darkcyan = @{ForegroundColor = 'DarkCyan'}
$yellow   = @{ForegroundColor = 'Yellow'}
$green    = @{ForegroundColor = 'Green'}
$red      = @{ForegroundColor = 'Red'}

# ============================================================================
# ЗАЩИТА ОТ ДУБЛИКАТОВ (MUTEX)
# ============================================================================

$Script:AppMutex = $null
$Script:MutexName = "Global\SupermiumPortable$($scriptName -replace '[\\:]','_')"

Function Enter-SingleInstance {
    try {
        $createdNew = $false
        $Script:AppMutex = New-Object System.Threading.Mutex($true, $MutexName, [ref]$createdNew)

        if (-not $createdNew) {
            $acquired = $AppMutex.WaitOne(500)
            if (-not $acquired) {
                Write-Host "Browser is running" @red
                return $false
            }
        }
        return $true
    } catch {
        Write-Host "$_.Exception.Message" @red
        return $true
    }
}

Function Exit-SingleInstance {
    Write-Host "Exit-SingleInstance"
    if ($AppMutex) {
        try {
            $AppMutex.ReleaseMutex()
            $AppMutex.Dispose()
        } catch {Write-Host "$_.Exception.Message" @red}
        $Script:AppMutex = $null
    }
}

# ============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================================

# Управление видимостью консольного окна
Function Set-ConsoleWindow ([string]$State) {
   if (-not ([System.Management.Automation.PSTypeName]'Native.Win').Type) {
      try {
         Add-Type -Name Win -Namespace Native -MemberDefinition @'
            [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
            [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
'@ -ea 0
      } catch {Write-Host "$_.Exception.Message" @red}
   }
   if (-not $winHandle) {
      $Script:winHandle = [Native.Win]::GetConsoleWindow()
   }
   try {
      switch ($State) {
         'hide' {[Native.Win]::ShowWindow($winHandle, 0) | Out-Null}
         'restore' {[Native.Win]::ShowWindowAsync($winHandle, 1) | Out-Null}
         Default {[Native.Win]::ShowWindow($winHandle, 1) | Out-Null}
      }
   } catch {Write-Host "$_.Exception.Message" @red}
}

# Иконки для уведомлений
Function Get-IconHandle {
   $iconBase64 = @(
      'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASZmZkK'
      'KSkpJRwiHCUUJwANAEAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAA0dHRy9yeniEk52dwKCoqteMm5TYUnFDxSpRH4sdOiI1MwAzBQAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAABmZqanGjrqzxvs3M/cXV1f3E1dX9ydnc'
      '/cDOzf1yjGr9Qns4+TVbM34gAEAIAAAAAAAAAAAAAAAAAAAAAGZqaniywL79'
      'xNXU/cLV1fzE19j7xNna+8Xa2vvP5Ob70dfp+1NzRP0tgyT9Ml4whQAAAAAA'
      'AAAAAAAAADA1MDCotLP9wNHR/cTY2PvH3d38zOPj+9Pq6vvU6+v7wtTY+6as'
      'tvtSc0n7BnQA/CiAI/0rRSc7AAAAAAAAAAB5gYGYvc3M/cPV1vzH3N370ujn'
      '/N7w8fzV4+b8wM7T/JGenPw6bTL8EHkI+xB6CvsQfQn9H2gYpwAAAAAAAAAR'
      'nqur0sHT0/3H29z8zePj/NHf4vx6fYX8SUlO/EA7Q/xqemP8a7pk/CiOJfwk'
      'iR78EoAM/Q5wCNwACwAYCwsLMKa1tOPS5ub9zuXl/Nfp6fxybXD8JgsA/EIT'
      'APxUHwD8RywQ/IyfgPxjs1/8NZcv/CKMHP0PdwjpAB8AOTE6Oh9sc3Xgk6Gs'
      '/crk7PzY6fD8RDAh/IVEB/zGeDP8z34y/IE7A/xPSy78h8iF/D+hO/wvliv9'
      'Fn4Q5gAhACf///8Cb2hWwWpbPv1tbWX8goqQ/FxLLfzOgSz87sGL/Oy9hvzM'
      'fiv8aF03/ILFg/xFpUH8Mpku/R2BF8oAAAAFAAAAAIqAXmKcfkP9elwr/Hpo'
      'Rfx3bVr7l2Ur/O+5fPzprnf8lWQt/JONh/tntGj7QqQ+/DWZMP0eexpuAAAA'
      'AAAAAABtbUkHmXxHzZV4P/2AZTT8mY1x+31zY/yCa1L8hW1T/HtxX/ygkYL7'
      'h6qF+3u9ef1Mn0fYGmYaCgAAAAAAAAAAAAAAAINsPiGSd0LUhW06/XtlNf2I'
      'elX8ioBh/Id8Xvx4aUX8fWc+/YiPgf1aoFTdPo84KQAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAlHlDE4x0P4qFbTjjgGo0+nxnMvt4ZC/7dV8s+3ljMeZUYTSOKWYp'
      'GQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAgEAEj3Y+KYVvOY6CbTbu'
      'f2sz8n5oMZZ9aC8xQEAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
   ) -join ''
   $iconBytes = [Convert]::FromBase64String($iconBase64)
   $memStream = $null
   $bitmap = $null
   try {
      $memStream = New-Object System.IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
      $bitmap = [System.Drawing.Bitmap]::new($memStream)
      return [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
   } catch {
      Write-Host "$_.Exception.Message" @red
      return [System.Drawing.SystemIcons]::Application
   } finally {
      if ($bitmap) {$bitmap.Dispose()}
      if ($memStream) {$memStream.Dispose()}
   }
}

# Уведомления Windows
Function Show-Balloon ([string]$Message,[string]$Title=$BrowserName,[string]$MessageType="Info") {
   try {
      if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.NotifyIcon').Type) {
         Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
         Add-Type -AssemblyName System.Drawing -ErrorAction Stop
      }
      $balloon = New-Object System.Windows.Forms.NotifyIcon
      $balloon.Icon = Get-IconHandle
      $balloon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]$MessageType
      $balloon.BalloonTipText  = $Message
      $balloon.BalloonTipTitle = $Title
      $balloon.Visible = $true
      $balloon.ShowBalloonTip(10000)
      Start-Sleep -Milliseconds 10000
   } catch {
      Write-Host "$_.Exception.Message" @red
   } finally {
      if ($balloon) {
         $balloon.Visible = $false
         $balloon.Dispose()
      }
   }
}

# Хранение значений переменных внутри данного файла
Function Set-FileVar ([string]$Name,[string]$Value) {
   try {
      $content = Get-Content -LiteralPath $scriptName -Encoding UTF8
      $newContent = $content -replace "(?<=^\s*\x24$Name\s*=\s*\x22)[^\x22]*",$Value
      [System.IO.File]::WriteAllLines("$($scriptName).tmp", $newContent, (New-Object System.Text.UTF8Encoding $false))
      Move-Item -LiteralPath "$($scriptName).tmp" -Destination $scriptName -Force
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Проверка сети
Function Test-DNS {
   for ($i = 0; $i -lt 2; $i++) {
      try {[Net.Dns]::GetHostEntry('ya.ru') | Out-Null
         Write-Host "Test connection: OK" @green
         return $true
      } catch {
         Write-Host "No connection" @red
         Start-Sleep -Milliseconds 500
      }
   }
   Show-Balloon -Message "No connection" -MessageType "Error"
}

# Сетевой запрос
Function Make-NetRequest ([string]$Url,[int]$Timeout=10) {

   try {

      if (-not ([AppDomain]::CurrentDomain.GetAssemblies() |
          Where-Object { $_.GetName().Name -eq "System.Net.Http" })) {
          Add-Type -AssemblyName "System.Net.Http" -ErrorAction Stop
      }

      $uri = New-Object "System.Uri" $Url
      $httpClient = New-Object System.Net.Http.HttpClient
      $httpClient.Timeout = [TimeSpan]::FromSeconds($Timeout)
      $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

      for ($i = 1; $i -lt 4; $i++) {
         try {
            $task = $httpClient.GetAsync($uri,'ResponseHeadersRead')
            $response = $task.GetAwaiter().GetResult()
            if ($response.IsSuccessStatusCode) {
               return $response
            } else {
               throw 'Bad StatusCode'
            }
         } catch {
            Write-Host "$_.Exception.Message" @red
            Show-Balloon -Message "Failed response $($uri.Host), try again..." -MessageType "Warning"
            Start-Sleep -Seconds $(3*$i)
         } finally {
            if ($task) {$task.Dispose(); $task = $null}
         }
      }

   } catch {
       Write-Host "$_.Exception.Message" @red
   } finally {
       $httpClient.Dispose()
   }
}

# Простейший HTML-парсер для извлечения ссылок
Function Get-HtmlLinks ([string]$Html) {
   $pattern = '<a\s+[^>]*href=["''](.*?)["'']'
   $matches = [regex]::Matches($html, $pattern, "IgnoreCase")

   foreach ($m in $matches) {
       $href = $m.Groups[1].Value;
       if ($href -match '^(#|javascript:)') { continue };
       $href
   }
}

# Получение номера версии и ссылки на установщик
Function Get-LatestVersion {
   if (-not (Test-DNS)) {$Script:checkError = $true; return $false}
   Write-Host "Get-LatestVersion..."

   $Script:url = "https://github.com/win32ss/supermium/releases"
   Write-Host "Request:     $url"

   try {
      $html = (Make-NetRequest -Url "$url/latest").Content.ReadAsStringAsync().Result
      if (-not $html) {throw 'html is NULL'}
      $Script:latest = (Get-HtmlLinks -Html $html) -like "*/tag/*" -replace ".+/tag/v*" | Select-Object -First 1
      if (-not $latest) {throw 'latest is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   Write-Host "Latest:      v$latest"
   return $true
}

Function Check-NewVersion {
   if (-not (Get-LatestVersion)) {return $false}

   Set-FileVar -Name "lastcheck" -Value $(Get-Date -Format 'ddMMyyyy')

   if (-not [IO.File]::Exists("$AppPath\$ExeName") -and $current -ne 0) {$current = 0}

   if ($latest -eq $current) {
      Write-Host "Installed:   v$current - no update required"
      return $false
   } elseif ($current -ne 0) {
      Write-Host "Installed:   v$current - update is available"
   } else {
      Write-Host "New install"
   }

   $find = if ($Bitness -eq 'x64') {'*64_setup'} else {'*32_setup'}
   if ($Edition -eq 0) {$find += '*win10*'}

   try {
      $assets = (Make-NetRequest -Url "$url/expanded_assets/v$latest").Content.ReadAsStringAsync().Result
      $Script:distrLink = 'https://github.com'+$((Get-HtmlLinks -Html $assets) -like "$($find).exe")
      if (-not $distrLink) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error parsing version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   Write-Host "Link:        $distrLink"

   if ([IO.File]::Exists("$AppPath\$ExeName")) {
      $script:instmode = 'update'
      if ($AskUpdate) {
         if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.MessageBox').Type) {
            try {Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop}
            catch {$Script:checkError = $true; Write-Host "$_.Exception.Message" @red; return $false}
         }
         $query = "$BrowserName v$latest is new version, update?"; $title = "Current v$current"
         if ([System.Windows.Forms.MessageBox]::Show($query,$title,4,32) -like 'Yes') {
            return $true
         } else {
            $Script:checkError = $true
            return $false
         }
      } else {
         Show-Balloon -Message "v$latest is new version, start update..."
         return $true
      }
   } else {
      $script:instmode = 'install'
      Show-Balloon -Message "v$latest start install..."
      return $true
   }
}

# Форма для прогресс-бара
Function Get-ProgressForm ([string]$Title) {
   try {
      if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type) {
         Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
         Add-Type -AssemblyName System.Drawing -ErrorAction Stop
      }

      $progressForm = New-Object System.Windows.Forms.Form
      $progressForm.Size = New-Object System.Drawing.Size(317,150)
      $progressForm.StartPosition = 'CenterScreen'
      $progressForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
      $progressForm.BackColor = '#0B5162'
      $progressForm.TopMost = $True
      $progressForm.Text = "$Title"
      $progressForm.Icon = Get-IconHandle

      $progressBar = New-Object System.Windows.Forms.ProgressBar
      $progressBar.Location = New-Object System.Drawing.Point(10, 50)
      $progressBar.Size = New-Object System.Drawing.Size(280, 20)
      $progressForm.Controls.Add($progressBar)

      $progressLabel = New-Object System.Windows.Forms.Label
      $progressLabel.Location = New-Object System.Drawing.Point(10, 20)
      $progressLabel.Size = New-Object System.Drawing.Size(280, 20)
      $progressLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
      $progressLabel.Font = New-Object System.Drawing.Font('Arial',9,[System.Drawing.FontStyle]::Bold)
      $progressLabel.ForeColor = '#D7E7F7'
      $progressForm.Controls.Add($progressLabel)

      return $progressForm,$progressBar,$progressLabel
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Загрузка файлов
Function Download-File ([string]$Source,[string]$Dest,[string]$Text,[boolean]$Pbar) {
   try {
      $response = Make-NetRequest -Url $Source

      if ($Pbar) {

         $totalLength = $response.Content.Headers.ContentLength / 1MB
         $responseStream = $response.Content.ReadAsStreamAsync().Result
      
         $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList "$Dest", Create
         $buffer = New-Object byte[] 8192
         $count = $responseStream.Read($buffer,0,$buffer.length)
         $downloadedBytes = $count
      
         $progressForm,$progressBar,$progressLabel = Get-ProgressForm -Title $BrowserName
         $progressForm.Show()
         Write-Host "Show ProgressBar"
      
         while ($count -gt 0 -and $progressForm.Visible) {
            $targetStream.Write($buffer, 0, $count)
            $count = $responseStream.Read($buffer,0,$buffer.length)
            $downloadedBytes = $downloadedBytes + $count
            $progressBar.Value = [Math]::Min(100, (($downloadedBytes / 1MB) / $totalLength) * 100)
            $progressLabel.Text = "$($Text):   $('{0:N2} MB' -f ($downloadedBytes / 1MB))   of   $('{0:N2} MB' -f ($totalLength))"
            [System.Windows.Forms.Application]::DoEvents()
         }
      
         if ($count -gt 0) {
            Show-Balloon -Message "Download canceled" -MessageType "Warning"
            throw 'usercanceled'
         }

      } else {
         $data = $response.Content.ReadAsByteArrayAsync().Result
         [System.IO.File]::WriteAllBytes($Dest,$data)
      }
      return $true
   } catch {
      Write-Host "$_.Exception.Message" @red
   } finally {
      if ($targetStream) {
         $targetStream.Flush()
         $targetStream.Close()
         $targetStream.Dispose()
         $targetStream = $null
      }
      if ($responseStream) {
         $responseStream.Dispose()
         $responseStream = $null
      }
      if ($response) {$response.Dispose()}
      if ($progressForm) {
         $progressForm.Close()
         $progressForm = $null
      }
   }
}

# Загрузка, распаковка, копирование
Function Update-Browser {
   if ($instmode -eq 'update') {Write-Host "Update-Browser..."}
   try {
      $Script:tmpdir = Join-Path $scriptPath "temp_$([IO.Path]::GetRandomFileName())"
      [IO.Directory]::CreateDirectory($tmpdir) | Out-Null
      Write-Host "Create temporary $($tmpdir): OK" @green

      # Installer
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\supermium.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
      &($7zpath) x -t7z -aoa "$tmpdir\supermium.exe" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      # Список файлов для сохранения
      $nodel = @(
         "$($profilePath.split('\')[-1])"
         "$((($profilePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      $nodel += @(
         'debug.log'
      )

      if ([IO.Directory]::Exists($AppPath)) {
         Get-Item -Path "$AppPath\*" -Exclude $nodel -ea 0 | Remove-Item -Recurse -Force -ea 0
         Write-Host "Delete old files: OK" @green
      } else {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      if ($Edition -eq 1) {
         $forwin7 = @(
            "Supermium\api-ms-win-crt-heap-l1-1-0.dll"
            "Supermium\api-ms-win-crt-math-l1-1-0.dll"
            "Supermium\api-ms-win-crt-runtime-l1-1-0.dll"
            "Supermium\api-ms-win-crt-stdio-l1-1-0.dll"
            "Supermium\api-ms-win-crt-string-l1-1-0.dll"
            "Supermium\p_advp32.dll"
            "Supermium\p_cry32.dll"
            "Supermium\p_cryptp.dll"
            "Supermium\p_dnsa.dll"
            "Supermium\p_dwma.dll"
            "Supermium\p_evapi.dll"
            "Supermium\p_iphlpa.dll"
            "Supermium\p_ntd.dll"
            "Supermium\p_ole.dll"
            "Supermium\p_powrpf.dll"
            "Supermium\p_s232.dll"
            "Supermium\p_setapi.dll"
            "Supermium\p_user.dll"
            "Supermium\p_usren.dll"
            "Supermium\p_vcrt.dll"
            "Supermium\p_whttp.dll"
            "Supermium\pdxg.dll"
            "Supermium\pwp_shd.dll"
            "Supermium\pwp_shl.dll"
            "Supermium\pwrp_k32.dll"
            "Supermium\ucrtbase.dll"
         )
         $SetupExclude = $SetupExclude | Where-Object {-not ($forwin7 -contains $_)}
      }

      $dirver = (Get-ChildItem -Path "$tmpdir\*\*.*.*.*" -Directory -ea 0).Name
      if (-not $dirver) {
         Show-Balloon -Message "Error in defining the directory structure" -MessageType "Error"
         throw 'Not detect directory number version'
      }

      $excludeList = $SetupExclude + @(
         'supermium.exe'
         '7zr.exe'
      ) -replace 'numver',"$dirver"

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\*" -Destination $AppPath -Exclude 'Supermium' -Recurse -Force
      Copy-Item -Path "$tmpdir\Supermium\*" -Destination $AppPath -Exclude $dirver -Recurse -Force
      Copy-Item -Path "$tmpdir\Supermium\$dirver\*" -Destination $AppPath -Recurse -Force
      Write-Host "Copy new files to $($AppPath): OK" @green

      Set-FileVar -Name "current" -Value $latest

      Get-Item -Path "$scriptPath\*.zip" -ea 0 | Sort-Object LastWriteTime -Descending | Select-Object -skip 2 | ForEach-Object {
         $_.Delete()
      }

      if ([IO.Directory]::Exists($profilePath)) {
         if ($Backup) {
            $backupName = "$current"+'_backup_'+"$(Get-Date -Format 'ddMMyyyy_HHmmss')"+'.zip'
            try {
               Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
               [System.IO.Compression.ZipFile]::CreateFromDirectory($profilePath,"$scriptPath\$backupName")
               Write-Host "Create backup: OK" @green
            } catch {
               Write-Host "$_.Exception.Message" @red
               Show-Balloon -Message "Error create backup" -MessageType "Error"
            }
         }
      }

      Show-Balloon -Message "v$latest $instmode is completed"

   } catch {

      Write-Host "$_.Exception.Message" @red
      $Script:updateError = $true

   } finally {

      if ($tmpdir -and (Test-Path -LiteralPath $tmpdir)) {
         try {[System.IO.Directory]::Delete($tmpdir, $true)}
         catch {Write-Host "$_.Exception.Message" @red}
      }

   }

}

# Новый профиль
Function Create-Profile {
   Write-Host "Create-Profile..."

   $localStateContent = @(
      '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":["chrome-labs@3","compact-ui","custo'
      'm-ntp","custom-tab-shapes@1","disable-encryption","disable-machine-id","disable-search-engine-collection","disa'
      'ble-sharing-hub","extension-mime-request-handling@2","hide-sidepanel-button","ignore-gpu-blocklist","override-n'
      'ew-tab-button-shape-default","override-tab-outline-default","popups-to-tabs","read-anything@2","remove-tabsearc'
      'h-button","show-avatar-button@3","smooth-scrolling@2","transparent-tabs"],"enabled_labs_experiments_origin_list'
      's":{"custom-ntp":"chrome://new-tab-page-third-party/"}},"hardware_acceleration_mode_previous":true,"profile":{"'
      'last_used":"Default"}}'
   ) -join ''

   $preferencesContent = @(
     '{"NewTabPage":{"DisabledModules":["dummy","dummy2"],"ModulesVisible":false},"account_id_migration_state":2,"aut'
     'ofill":{"credit_card_enabled":false,"enabled":false,"orphan_rows_removed":true,"profile_enabled":false},"bookma'
     'rk_bar":{"show_apps_shortcut":false,"show_on_all_tabs":false,"show_reading_list":false},"browser":{"check_defau'
     'lt_browser":false,"clear_data":{"browsing_history_basic":true,"cache_basic":true,"cookies_basic":true,"form_dat'
     'a":true,"hosted_apps_data":true,"media_licenses":true,"passwords":true,"preferences_migrated_to_basic":true,"si'
     'te_settings":true,"time_period":4,"time_period_basic":4},"clear_lso_data_enabled":true,"has_seen_welcome_page":'
     'true,"last_clear_browsing_data_tab":1,"window_placement":{"bottom":720,"left":64,"maximized":false,"right":1200'
     ',"top":32}},"credentials_enable_autosignin":false,"credentials_enable_service":false,"default_apps_install_stat'
     'e":2,"download":{"directory_upgrade":true,"prompt_for_download":true},"enable_do_not_track":true,"extensions":{'
     '"alerts":{"initialized":true},"ui":{"developer_mode":true}},"media":{"engagement":{"schema_version":4}},"net":{'
     '"network_prediction_options":2},"omnibox":{"prevent_url_elisions":true},"payments":{"can_make_payment_enabled":'
     'false},"profile":{"avatar_index":24,"block_third_party_cookies":true,"content_settings":{"clear_on_exit_migrate'
     'd":true,"pref_version":1},"default_content_setting_values":{"background_sync":2,"cookies":1},"exit_type":"Norma'
     'l","exited_cleanly":true,"local_avatar_index":24,"managed_user_id":"","name":"","password_manager_enabled":fals'
     'e},"safebrowsing":{"enabled":false,"unhandled_sync_password_reuses":{}},"savefile":{"default_directory":"::{20D'
     '04FE0-3AEA-1069-A2D8-08002B30309D}"},"search":{"suggest_enabled":false},"zerosuggest":{"cachedresults":""}}'
   ) -join ''

   try {
      [IO.Directory]::CreateDirectory("$profilePath\Default") | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])\Default"
      [System.IO.File]::Create("$profilePath\First Run").Dispose()
      Write-Host " ---> $($profilePath.Split('\')[-1])\First Run"

      # Сохранение данных Preferences и Local State в кодировке UTF-8 без BOM и без новой строки в конце
      $localState = Join-Path $profilePath "Local State"
      [System.IO.File]::WriteAllText($localState, $localStateContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Local State"

      $preferences = Join-Path "$profilePath\Default" "Preferences"
      [System.IO.File]::WriteAllText($preferences, $preferencesContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Default\Preferences"
      Write-Host "New profile: Done" @green
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Удаление хлама после закрытия браузера
Function Delete-Traces {
   $list = @($DelDirs+$DelFiles | ForEach-Object {
      Get-Item -Path "$profilePath\$_" -ErrorAction SilentlyContinue
   })
   $list += @($DelReg | ForEach-Object {
      Get-Item -Path "Registry::$_" -ErrorAction SilentlyContinue
   })
   $items = $list | Select-Object -Unique | Sort-Object Mode
   ForEach ($item in $items) {
      try {
         if ($item.GetType().Name -ne 'RegistryKey') {
            $item.Attributes = [System.IO.FileAttributes]::Normal
         }
         switch ($item.GetType().Name) {
            'DirectoryInfo' {
                $item.Delete($true)
                $d += 1
                $msgok = "Deleted directory: $($item.FullName)"
                if ($MakeStub) {
                   if ($NoStub -notcontains $item.BaseName) {
                      [System.IO.File]::Create($item.FullName).Dispose()
                      [System.IO.File]::SetAttributes($item.FullName, [System.IO.FileAttributes]::ReadOnly)
                      $msgok = "Deleted directory and create stub: $($item.FullName)"
                   }
                }
            }
            'FileInfo' {
                if ($DelDirs -contains $item.BaseName) {
                    if (-not $MakeStub) {
                       $item.Delete()
                       $msgok = "Deleted file stub: $($item.FullName)"
                    }
                } else {
                    $item.Delete()
                    $f += 1
                    $msgok = "Deleted file: $($item.FullName)"
                }
            }
            'RegistryKey' {
                Remove-Item -Path "Registry::$item" -Recurse -Force -ErrorAction Stop
                $r += 1
                $msgok = "Deleted registry entry: $item"
            }
         }
         Write-Host "$msgok"
      } catch {
         Write-Host "$_.Exception.Message" @red
      }
   }
   Write-Host "Clean result: $([int]$f) files, $([int]$d) directories, $([int]$r) registry entries" @green
}

# ============================================================================
# ОСНОВНОЙ КОД
# ============================================================================

if (-not (Enter-SingleInstance)) {exit}

if ($scriptName -notmatch "(\.cmd|\.bat)$") {Write-Host "Failed to determine script path" @red; exit}

if ($host.Version.Major -le 4) {Write-Host "PowerShell version is old" @red; exit}

try {
   if ($ShowConsole) {Set-ConsoleWindow -State 'restore'} else {Set-ConsoleWindow -State 'hide'}
} catch {
   Write-Host "$_.Exception.Message" @red
}

if ($RunMode -eq 1) {
   Write-Host "Run mode: only start browser" @yellow
} elseif ($RunMode -eq 2) {
   Write-Host "Run mode: only check update" @yellow
}

Write-Host                  "Initialize variables..."
Write-Host                  "Script:    $scriptName"  @darkcyan
Write-Host                  "App:       $AppPath"     @darkcyan
Write-Host                  "Browser:   $BrowserName" @darkcyan
Write-Host                  'BrowserMode:'$(switch ($BrowserMode) {
   1 {'Ungoogled Portable'}
   2 {'Classic Portable'}
   3 {'Classic Ungoogled Portable'}
default {'Portable'}
})                                                    @darkcyan
Write-Host                  "Profile:   $profilePath" @darkcyan
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
Write-Host                  "Mutex:     $MutexName"   @darkcyan

try {

   if (-not $lastcheck) {$lastcheck='18032026'}
   $daysCheck = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   # Условия проверки обновлений: спец. режим запуска, превышение заданного интервала, отсутствие исполняемого файла
   if ($RunMode -eq 2 -or ($daysCheck -ge [int]$CheckInterval -and $RunMode -ne 1) -or -not [IO.File]::Exists("$AppPath\$ExeName")) {

      if (Check-NewVersion) {
         Update-Browser
         if ($updateError) {
            if ($instmode -eq 'install') {
               Set-FileVar -Name "lastcheck" -Value "18032026"
               Show-Balloon -Message "Installation fail" -MessageType "Error"
               throw 'Installation fail'
            } else {
               Show-Balloon -Message "Update fail, previous used" -MessageType "Error"
               Write-Host "Update fail" @red
               if ($RunMode -eq 2) {exit}
            }
         } else {
            Write-Host "$BrowserName $instmode completed: OK" @green
            if ($RunMode -eq 2) {exit}
         }
      } else {
         if ($checkError) {
            if ($RunMode -eq 2 -or -not [IO.File]::Exists("$AppPath\$ExeName")) {exit}
         } elseif ($RunMode -eq 2) {
            Show-Balloon -Message "The installed v$latest is the latest one"
            exit
         }
      }

   }

   # Создание ярлыка
   if ($CreateShortcut) {
      if (-not [IO.File]::Exists("$env:USERPROFILE\Desktop\$BrowserName.lnk")) {

         $lnkpath = Get-Item -Path "$env:USERPROFILE\Desktop\*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
               (New-Object -COM WScript.Shell).CreateShortcut($_.FullName)
            } catch {$null}
         } | Where-Object {$_.TargetPath -eq $scriptName}

         if ([IO.File]::Exists("$AppPath\$ExeName") -and -not $lnkpath) {
            try {
               $shell = New-Object -ComObject WScript.Shell
               $shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\$BrowserName.lnk")
               $shortcut.TargetPath = $scriptName
               $shortcut.IconLocation = "$AppPath\$ExeName, 0"
               $shortcut.WindowStyle = 7
               $shortcut.WorkingDirectory = $scriptPath
               $shortcut.Description = $BrowserName
               $shortcut.Save()
               Write-Host "Create shortcut: OK" @green

               [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) | Out-Null
               [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            } catch {Write-Host "$_.Exception.Message" @red}
         }
      }
   }

   # Наличие исполняемого файла браузера
   if (-not [IO.File]::Exists("$AppPath\$ExeName")) {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed $ExeName" -MessageType "Error"
      }
      throw "Missed $ExeName"
   }

   # Создание нового профиля
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

   # Заглушки
   if (-not [IO.Directory]::Exists("$AppPath\debug.log")) {
      try {
         [System.IO.File]::Delete("$AppPath\debug.log")
         [IO.Directory]::CreateDirectory("$AppPath\debug.log") | Out-Null
         Set-ItemProperty -LiteralPath "$AppPath\debug.log" -Name Attributes -Value 'ReadOnly,Hidden' -ea 1
         Write-Host "Create ReadOnly,Hidden folder $AppDir\debug.log: OK" @green
      } catch {
         Write-Host "$_.Exception.Message" @red
      }
   }

   # Режим запуска
   $extkeys = @(
      "--ungoogled-supermium"
      "--classic-omnibox"
      "--classic-omnibox-border"
      "--compact-ui"
      "--enable-features=SupermiumCustomTabs"
      "--disable-features=DownloadBubble,TabHoverCards,PowerBookmarksSidePanel"
   )
   $Switches += switch ($BrowserMode) {
      1 {"--ungoogled-supermium"}
      2 {$extkeys -notlike "--ungoogled-supermium"}
      3 {$extkeys}
      default {}
   }

   # Запуск браузера
   Start-Process -FilePath "$AppPath\$ExeName" -ArgumentList $Switches -WorkingDirectory $AppPath
   Start-Sleep -Seconds 2
   Write-Host "Start browser..."

   # Мониторинг с таймаутом
   $browserProcessName = ($ExeName -replace '\.exe$','')
   $maxWaitSeconds = 86400
   $waitStart = Get-Date

   while ($true) {
      if (((Get-Date) - $waitStart).TotalSeconds -gt $maxWaitSeconds) {break}

      $browserRunning = Get-Process -Name $browserProcessName -ErrorAction SilentlyContinue | Where-Object {
         try {$_.Path -eq "$AppPath\$ExeName"} catch {$false}
      }
      if (-not $browserRunning) {break}

      Start-Sleep -Seconds 5
   }

   # Очистка профиля
   if (-not $lastclean) {$lastclean='18032026'}
   
   $sinceclean = (New-TimeSpan -Start $([datetime]::parseexact($lastclean, 'ddMMyyyy', $null))).Days

   if ($sinceclean -ge [int]$CleanInterval) {
      Write-Host "Start profile clean..."
      Delete-Traces
      Set-FileVar -Name "lastclean" -Value $(Get-Date -Format 'ddMMyyyy')
   }

   # Удаление по списку $Trash
   $Trash | ForEach-Object {
      (Get-Item -Path $_ -ErrorAction SilentlyContinue).FullName
   } | Select-Object -Unique | ForEach-Object {
      try {
         Remove-Item -Path $_ -Recurse -Force -ErrorAction Stop
         Write-Host "Deleted trash: $_"
      } catch {
         Write-Host "$_.Exception.Message" @red
      }
   }

} catch {

   Write-Host $_ @red

} finally {

   Exit-SingleInstance
   if ($ShowConsole) {timeout /t -1}
}
