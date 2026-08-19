<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера CatsXP и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию (stable/beta) и разрядность (x64/x86) браузера, указав нужное значение в $Edition и $Bitness.
:: Портабельность обеспечивается ключами запуска --disable-machine-id, --disable-encryption.
:: Если указать свой профиль в ключе --user-data-dir, то подхватится он, иначе создается новый
:: с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=5&topic=51193&start=760#4).
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
$Edition = 0 # 0 - Stable, 1 - Beta
$Bitness = "x64" # для 32bit-версии указать "x86"
$AppDir = "App" # папка сборки, создается рядом со скриптом
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
#   "--disable-direct-write"
   "--disable-features=PrintCompositorLPAC"
   "--disable-catsxp-update"
   "--disable-captive-portals"
   "--disable-catsxp-detect-outdated-install"
   "--disable-catsxp-wayback-machine-extension"
   "--disable-vertical-tabs"
#   "--catsxp-link-force"
#   "--catsxp-keep-history"
#   "--catsxp-microsoft-brand"
#   "--catsxp-redirector"
#   "--catsxp-use-google-sync"
#   "--dark-mode=dark"
#   "--disable-catsxp-extension"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
   "ActorSafetyLists"
   "AmountExtractionHeuristicRegexes"
   "Autofill*"
   "Avatars"
   "BrowserMetrics"
   "Cache"
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
   "hnhlikenpflkalkanekdkpchecegkgbf"
   "hyphen-data"
   "InterventionPolicyDatabase"
   "kfccjfggmjndcomiakdamhplllepilok"
   "kccklbnlfbceckfcepdkbdkgebdgonjj"
   "MediaFoundationWidevineCdm"
   "MEIPreload"
   "mkohloaccnliialcdhpgljfckmcphpaf"
   "ogolnieebfnhlpjoapigplimhmkhglod"
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
   "Default\ads_service"
   "Default\AdBlock Custom Resources"
   "Default\AutofillStrikeDatabase"
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
   "Default\Service Worker\cache*"
   "Default\ShaderCache"
   "Default\Shared*"
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
   "BrowserMetrics*"
   "chrome_shutdown_ms*"
   "Certificate*"
   "CrashpadMetrics*"
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
   "Default\heavy_ad_intervention_opt_out*"
   "Default\History Provider cache*"
   "Default\InterestGroups"
   "Default\MediaDeviceSalts"
   "Default\Network\Network*"
   "Default\Network\Reporting and NEL*"
   "Default\Network\SCT Auditing Pending Reports"
   "Default\passkey_enclave_state"
   "Default\PreferredApps"
   "Default\PrivateAggregation"
   "Default\QuotaManager*"
   "Default\README"
   "Default\Reporting and NEL*"
   "Default\SCT Auditing Pending Reports"
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
#   "Default\File System\Origins\*.log"
#   "Default\Favicons"
#   "Default\File System\Origins\*.log"
#   "Default\History*"
#   "Default\Last Session*"
#   "Default\Last Tabs*"
#   "Default\Login Data For Account"
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
#   "Default\SharedStorage"
#   "Default\Shortcuts"
#   "Default\TransportSecurity"
#   "Default\trust*"
#   "Default\Top Sites*"
#   "Default\Visited Links*"
#   "Default\WebStorage\QuotaManager*"
)

$DelReg = @( # данные реестра, удаляемые после закрытия браузера
   "HKEY_CURRENT_USER\SOFTWARE\CatsxpSoftware"
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
   "chrome_proxy.exe"
   "ReadMe.txt"
   "StartupParm.txt"
   "numver\IwaKeyDistribution"
   "numver\MEIPreload"
   "numver\PrivacySandboxAttestationsPreloaded"
   "numver\VisualElements"
   "numver\chrome_pwa_launcher.exe"
   "numver\chrome_wer.dll"
   "numver\dxcompiler.dll"
   "numver\dxil.dll"
   "numver\elevation_service.exe"
   "numver\eventlog_provider.dll"
   "numver\notification_helper.exe"
   "numver\Locales\*FEMININE.pak"
   "numver\Locales\*MASCULINE.pak"
   "numver\Locales\*NEUTER.pak"
   "numver\Locales\af.pak"
   "numver\Locales\am.pak"
   "numver\Locales\ar.pak"
   "numver\Locales\as.pak"
   "numver\Locales\az.pak"
   "numver\Locales\be.pak"
   "numver\Locales\bg.pak"
   "numver\Locales\bn.pak"
   "numver\Locales\bs.pak"
   "numver\Locales\ca.pak"
   "numver\Locales\cs.pak"
   "numver\Locales\cy.pak"
   "numver\Locales\da.pak"
   "numver\Locales\de.pak"
   "numver\Locales\el.pak"
   "numver\Locales\en-GB.pak"
   "numver\Locales\es-419.pak"
   "numver\Locales\es.pak"
   "numver\Locales\et.pak"
   "numver\Locales\eu.pak"
   "numver\Locales\fa.pak"
   "numver\Locales\fi.pak"
   "numver\Locales\fil.pak"
   "numver\Locales\fr-CA.pak"
   "numver\Locales\fr.pak"
   "numver\Locales\gl.pak"
   "numver\Locales\gu.pak"
   "numver\Locales\he.pak"
   "numver\Locales\hi.pak"
   "numver\Locales\hr.pak"
   "numver\Locales\hu.pak"
   "numver\Locales\hy.pak"
   "numver\Locales\id.pak"
   "numver\Locales\is.pak"
   "numver\Locales\it.pak"
   "numver\Locales\ja.pak"
   "numver\Locales\ka.pak"
   "numver\Locales\kk.pak"
   "numver\Locales\km.pak"
   "numver\Locales\kn.pak"
   "numver\Locales\ko.pak"
   "numver\Locales\ky.pak"
   "numver\Locales\lo.pak"
   "numver\Locales\lt.pak"
   "numver\Locales\lv.pak"
   "numver\Locales\mk.pak"
   "numver\Locales\ml.pak"
   "numver\Locales\mn.pak"
   "numver\Locales\mr.pak"
   "numver\Locales\ms.pak"
   "numver\Locales\my.pak"
   "numver\Locales\nb.pak"
   "numver\Locales\ne.pak"
   "numver\Locales\nl.pak"
   "numver\Locales\or.pak"
   "numver\Locales\pa.pak"
   "numver\Locales\pl.pak"
   "numver\Locales\pt-BR.pak"
   "numver\Locales\pt-PT.pak"
   "numver\Locales\ro.pak"
   "numver\Locales\si.pak"
   "numver\Locales\sk.pak"
   "numver\Locales\sl.pak"
   "numver\Locales\sq.pak"
   "numver\Locales\sr-Latn.pak"
   "numver\Locales\sr.pak"
   "numver\Locales\sv.pak"
   "numver\Locales\sw.pak"
   "numver\Locales\ta.pak"
   "numver\Locales\te.pak"
   "numver\Locales\th.pak"
   "numver\Locales\tr.pak"
   "numver\Locales\uk.pak"
   "numver\Locales\ur.pak"
   "numver\Locales\uz.pak"
   "numver\Locales\vi.pak"
   "numver\Locales\zh-CN.pak"
   "numver\Locales\zh-HK.pak"
   "numver\Locales\zh-TW.pak"
   "numver\Locales\zu.pak"
   "numver\resources\catsxp_extension\_locales\af"
   "numver\resources\catsxp_extension\_locales\am"
   "numver\resources\catsxp_extension\_locales\ar"
   "numver\resources\catsxp_extension\_locales\az"
   "numver\resources\catsxp_extension\_locales\bg"
   "numver\resources\catsxp_extension\_locales\bn"
   "numver\resources\catsxp_extension\_locales\ca"
   "numver\resources\catsxp_extension\_locales\cs"
   "numver\resources\catsxp_extension\_locales\da"
   "numver\resources\catsxp_extension\_locales\de"
   "numver\resources\catsxp_extension\_locales\el"
   "numver\resources\catsxp_extension\_locales\en_GB"
   "numver\resources\catsxp_extension\_locales\es"
   "numver\resources\catsxp_extension\_locales\es_419"
   "numver\resources\catsxp_extension\_locales\et"
   "numver\resources\catsxp_extension\_locales\fa"
   "numver\resources\catsxp_extension\_locales\fi"
   "numver\resources\catsxp_extension\_locales\fil"
   "numver\resources\catsxp_extension\_locales\fr"
   "numver\resources\catsxp_extension\_locales\gu"
   "numver\resources\catsxp_extension\_locales\he"
   "numver\resources\catsxp_extension\_locales\hi"
   "numver\resources\catsxp_extension\_locales\hr"
   "numver\resources\catsxp_extension\_locales\hu"
   "numver\resources\catsxp_extension\_locales\id"
   "numver\resources\catsxp_extension\_locales\it"
   "numver\resources\catsxp_extension\_locales\ja"
   "numver\resources\catsxp_extension\_locales\ka"
   "numver\resources\catsxp_extension\_locales\kk"
   "numver\resources\catsxp_extension\_locales\km"
   "numver\resources\catsxp_extension\_locales\kn"
   "numver\resources\catsxp_extension\_locales\ko"
   "numver\resources\catsxp_extension\_locales\lo"
   "numver\resources\catsxp_extension\_locales\lt"
   "numver\resources\catsxp_extension\_locales\lv"
   "numver\resources\catsxp_extension\_locales\mk"
   "numver\resources\catsxp_extension\_locales\ml"
   "numver\resources\catsxp_extension\_locales\mn"
   "numver\resources\catsxp_extension\_locales\mr"
   "numver\resources\catsxp_extension\_locales\ms"
   "numver\resources\catsxp_extension\_locales\my"
   "numver\resources\catsxp_extension\_locales\nb"
   "numver\resources\catsxp_extension\_locales\nl"
   "numver\resources\catsxp_extension\_locales\pl"
   "numver\resources\catsxp_extension\_locales\pt_BR"
   "numver\resources\catsxp_extension\_locales\pt_PT"
   "numver\resources\catsxp_extension\_locales\ro"
   "numver\resources\catsxp_extension\_locales\si"
   "numver\resources\catsxp_extension\_locales\sk"
   "numver\resources\catsxp_extension\_locales\sl"
   "numver\resources\catsxp_extension\_locales\sq"
   "numver\resources\catsxp_extension\_locales\sr"
   "numver\resources\catsxp_extension\_locales\sr_Latn"
   "numver\resources\catsxp_extension\_locales\sv"
   "numver\resources\catsxp_extension\_locales\sw"
   "numver\resources\catsxp_extension\_locales\ta"
   "numver\resources\catsxp_extension\_locales\te"
   "numver\resources\catsxp_extension\_locales\th"
   "numver\resources\catsxp_extension\_locales\tr"
   "numver\resources\catsxp_extension\_locales\uk"
   "numver\resources\catsxp_extension\_locales\ur"
   "numver\resources\catsxp_extension\_locales\uz"
   "numver\resources\catsxp_extension\_locales\vi"
   "numver\resources\catsxp_extension\_locales\zh_CN"
   "numver\resources\catsxp_extension\_locales\zh_TW"
)
$Trash = @( # папки и файлы вне профиля, подлежащие удалению после закрытия браузера
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================

$lastcheck = "18032026"
$lastclean = "18032026"

$scriptName = $MyInvocation.Line -replace "[^']+'([A-Za-z]:\\.+)'[^']+",'$1'
$scriptPath = Split-Path -Path $scriptName -Parent

if (-not $AppDir) {$AppDir = 'App'}
$AppPath = Join-Path $scriptPath $AppDir

if ($Edition -ne 1) {$Edition = 0}
if ($Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = 'CatsXP' + @(if ($Edition -ne 0) {' Beta'}) +" $Bitness" -join ''

$ExeName = 'catsxp.exe'

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
$Script:MutexName = "Global\CatsXPPortable$($scriptName -replace '[\\:]','_')"

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
      'AAABAAEAECAAAAEACABoBQAAFgAAACgAAAAQAAAAIAAAAAEACAAAAAAAAAEA'
      'AAAAAAAAAAAAAAEAAAABAAAAAAAAiEccAJJNGgC1ZRAAk1QrAJRYMgCbXjYA'
      'w2sMAMJxDQAAg0sAAIdLAASHUAAQhlcAGo9dABWUWQAAoFQAAKVXAACoVwAA'
      'tlsAAbZcAAC5XQAAvF4AAL5gABW7aAAbvm0AAMFhAADEYwAAx2QAAMhlABfD'
      'bQAXxm8AFspwABrOdQAww3oANMV9AOOMBgD/lgAA/50AAP+iAAD+pQAA/6oA'
      'AP+tAAD/sQAA/7YAAP+0BQD/uQAA/70AAP+iFQD/shUA/7YXAP+/FwD/sBsA'
      '/7QbAP+7JwD/vC8A/6w/AP+1NAD/vzsA/8EAAP/ANQC4jW8A5p9QAP/MRgD/'
      'wUkA/81VAP/CbAD/x24A/9RxAP/TdwD/2HIAV6+IAHy7owA/xoIAPcmDACzT'
      'gAAy0oMARs+KAEzKiwBG040AVcuSAHLEnQBs058AbtShAHHZpQB75K8AvZmB'
      'AMeiggAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAD///8AAAAAAABSIhgYIlMAAAAAAAAAAFEXExQUFBQWHVMAAAAAAEgTFBQU'
      'GRkZGRkZTgAAAE0TFBQZGRkZGRQRDw9PAAATFBQZGRkcIABQDgoKCwAiFBQZ'
      'GRwcIAAAAABGDQxHSRQZGRwcSgAAAAAAAAAAAABOHR9LVAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAARDYwMD8AAAAAAAAAAAAANSoqKiopP1UEBjwAAAAAMSotLS0q'
      'KjkAAgEBBVYAMCotLS06LSoAAD0HAwgjJykqLS06Oi1AAAAANyQlJycpKio6'
      'Oi0+AAAAAABBLyUnKSkqLTJFAAAAAAAAAABBODM0O0QAAAAAAPgfAADgBwAA'
      'wAMAAIABAACAQQAAAPAAAAH/AACD/wAA/8EAAP+AAAAPAAAAggEAAIABAADA'
      'AwAA4AcAAPgfAAA='
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

   $url = 'https://www.catsxp.com'+$(if ($Edition -ne 1) {'/rss'})
   Write-Host "Request:   $url"

      try {

         $response = (Make-NetRequest -Url $url).Content.ReadAsStringAsync().Result
         if (-not $response) {throw 'response is NULL'}

         if ($Edition -ne 1) {
            $ver = (([xml]$response).rss.channel.item | Select-Object -Property title -First 1).title
            $core = (([xml]$response).rss.channel.item | Select-Object -ExpandProperty description | Where-Object {
               $_.'#cdata-section' -like "*upgrade:*"
            } | Select-Object -First 1).'#cdata-section' -Split '\r?\n' | Select-Object -First 1
            $Script:latest = [version]($($core -replace '.+upgrade:\s*(\d+).+','$1')+'.'+$ver)
            $baselink = 'https://b2.catsxp.com/catsxp_portable/win_'
            $Script:distrLink = $baselink+$Bitness+'/portable_'+$Bitness+'_release_'+"$latest".Replace('.','_')+'.zip'
         } else {
            $Script:distrLink = (Get-HtmlLinks -Html $response) -like "*_$($Bitness)_*.zip" | Select-Object -First 1
            if ($distrLink -match '.+?_(\d+_\d+_\d+_\d+).+') {
               $Script:latest = [version]$matches[1].Replace('_','.')
            }
         }

         if (-not $latest) {throw 'latest is NULL'}
         if (-not $distrLink) {throw 'distrLink is NULL'}

      } catch {
         Write-Host "$_.Exception.Message" @red
         Show-Balloon -Message "Error check version" -MessageType "Error"
         $Script:checkError = $true
         return $false
      }

   Write-Host "Link:      $distrLink"
   Write-Host "Latest:    v$latest"

   return $true
}

# Сравнение версий
Function Check-NewVersion {
   if (-not (Get-LatestVersion)) {return $false}

   Set-FileVar -name "lastcheck" -value $(Get-Date -Format 'ddMMyyyy')

   try {
      $Script:current = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\$ExeName").FileVersionRaw
   } catch {
      $Script:current = $null
   }

   if ($latest -le $current) {
      Write-Host "Installed: v$current - no update required"
      return $false
   } elseif ($current -ne $null) {
      Write-Host "Installed: v$current - update is available"
   } else {
      Write-Host "New install"
   }

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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\catsxp.zip" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
      try {
         Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
         [System.IO.Compression.ZipFile]::ExtractToDirectory("$tmpdir\catsxp.zip",$tmpdir)
      } catch {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw $_
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

      $dirver = (Get-ChildItem -Path "$tmpdir\*.*.*.*" -Directory -ea 0).Name
      if (-not $dirver) {
         Show-Balloon -Message "Error in defining the directory structure" -MessageType "Error"
         throw 'Not detect directory number version'
      }

      $SetupExclude -replace 'numver',"$dirver" | ForEach-Object {
         $excludePath = "$tmpdir\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\*" -Destination $AppPath -Exclude 'catsxp.zip',$dirver -Recurse -Force
      Copy-Item -Path "$tmpdir\$dirver\*" -Destination $AppPath -Recurse -Force
      Write-Host "Copy new files to $($AppPath): OK" @green

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
      '{"background_mode" : {"enabled" : false},"browser" : {"enabled_labs_experiments" : ["enable-parallel-downloadin'
      'g@1"]},"catsxp" : {"dark_mode" : 1}}'
   ) -join ''

   $preferencesContent = @(
      '{"alternate_error_pages":{"backup":false},"apps":{"shortcuts_arch":"","shortcuts_version":0},"autocomplete":{"r'
      'etention_policy_last_version":0},"autofill":{"orphan_rows_removed":true},"browser":{"has_seen_welcome_page":tru'
      'e,"window_placement":{"bottom":728,"left":10,"maximized":true,"right":1060,"top":10,"work_area_bottom":738,"wor'
      'k_area_left":0,"work_area_right":1366,"work_area_top":0}},"catsxp":{"accelerators":{"33000":["Alt+ArrowLeft","A'
      'ltGr+ArrowLeft"],"33001":["Alt+ArrowRight","AltGr+ArrowRight"],"33002":["Control+KeyR","F5"],"33003":["Alt+Home'
      '"],"33007":["Control+Shift+KeyR","Control+F5","Shift+F5"],"34000":["Control+KeyN"],"34001":["Control+Shift+KeyN'
      '"],"34012":["Control+Shift+KeyW","Alt+F4"],"34014":["Control+KeyT"],"34015":["Control+KeyW","Control+F4"],"3401'
      '6":["Control+Tab","Control+PageDown"],"34017":["Control+Shift+Tab","Control+PageUp"],"34018":["Control+Digit1",'
      '"Control+Numpad1"],"34019":["Control+Digit2","Control+Numpad2"],"34020":["Control+Digit3","Control+Numpad3"],"3'
      '4021":["Control+Digit4","Control+Numpad4"],"34022":["Control+Digit5","Control+Numpad5"],"34023":["Control+Digit'
      '6","Control+Numpad6"],"34024":["Control+Digit7","Control+Numpad7"],"34025":["Control+Digit8","Control+Numpad8"]'
      ',"34026":["Control+Digit9","Control+Numpad9"],"34028":["Control+Shift+KeyT"],"34030":["F11"],"34032":["Control+'
      'Shift+PageDown"],"34033":["Control+Shift+PageUp"],"35000":["Control+KeyD"],"35001":["Control+Shift+KeyD"],"3500'
      '2":["Control+KeyU"],"35003":["Control+KeyP"],"35004":["Control+KeyS"],"35007":["Control+Shift+KeyP"],"37000":["'
      'Control+KeyF"],"37001":["Control+KeyG","F3"],"37002":["Control+Shift+KeyG","Shift+F3"],"37003":["Escape"],"3800'
      '1":["Control+Equal","Control+NumpadAdd","Control+Shift+Equal"],"38002":["Control+Digit0","Control+Numpad0"],"38'
      '003":["Control+Minus","Control+NumpadSubtract","Control+Shift+Minus"],"39000":["Alt+Shift+KeyT"],"39001":["Cont'
      'rol+KeyL","Alt+KeyD"],"39002":["BrowserSearch","Control+KeyE","Control+KeyK"],"39003":["F10","Alt","Alt","AltGr'
      '"],"39004":["F6"],"39005":["Shift+F6"],"39006":["Alt+Shift+KeyB"],"39007":["Alt+Shift+KeyA"],"39009":["Control+'
      'F6"],"40000":["Control+KeyO"],"40004":["Control+Shift+KeyI"],"40005":["Control+Shift+KeyJ"],"40006":["Shift+Esc'
      'ape"],"40009":["Control+Shift+KeyB"],"40010":["Control+KeyH"],"40011":["Control+Shift+KeyO"],"40012":["Control+'
      'KeyJ"],"40013":["Control+Shift+Delete"],"40019":["F1"],"40021":["Alt+KeyE","Alt+KeyF"],"40023":["Control+Shift+'
      'KeyC"],"40134":["Control+Shift+KeyM"],"40237":["F12"],"40260":["F7"],"40261":["Control+Space"],"52500":["Contro'
      'l+Shift+KeyA"],"56003":["Alt+Shift+KeyN"],"56041":["Control+KeyM"],"56044":["Control+KeyB"]},"built_in":{"dark_'
      'enabled":true,"pip_enabled":true},"cache_data_location":"","default_accelerators":{"33000":["Alt+ArrowLeft","Al'
      'tGr+ArrowLeft"],"33001":["Alt+ArrowRight","AltGr+ArrowRight"],"33002":["Control+KeyR","F5"],"33003":["Alt+Home"'
      '],"33007":["Control+Shift+KeyR","Control+F5","Shift+F5"],"34000":["Control+KeyN"],"34001":["Control+Shift+KeyN"'
      '],"34012":["Control+Shift+KeyW","Alt+F4"],"34014":["Control+KeyT"],"34015":["Control+KeyW","Control+F4"],"34016'
      '":["Control+Tab","Control+PageDown"],"34017":["Control+Shift+Tab","Control+PageUp"],"34018":["Control+Digit1","'
      'Control+Numpad1"],"34019":["Control+Digit2","Control+Numpad2"],"34020":["Control+Digit3","Control+Numpad3"],"34'
      '021":["Control+Digit4","Control+Numpad4"],"34022":["Control+Digit5","Control+Numpad5"],"34023":["Control+Digit6'
      '","Control+Numpad6"],"34024":["Control+Digit7","Control+Numpad7"],"34025":["Control+Digit8","Control+Numpad8"],'
      '"34026":["Control+Digit9","Control+Numpad9"],"34028":["Control+Shift+KeyT"],"34030":["F11"],"34032":["Control+S'
      'hift+PageDown"],"34033":["Control+Shift+PageUp"],"35000":["Control+KeyD"],"35001":["Control+Shift+KeyD"],"35002'
      '":["Control+KeyU"],"35003":["Control+KeyP"],"35004":["Control+KeyS"],"35007":["Control+Shift+KeyP"],"37000":["C'
      'ontrol+KeyF"],"37001":["Control+KeyG","F3"],"37002":["Control+Shift+KeyG","Shift+F3"],"37003":["Escape"],"38001'
      '":["Control+Equal","Control+NumpadAdd","Control+Shift+Equal"],"38002":["Control+Digit0","Control+Numpad0"],"380'
      '03":["Control+Minus","Control+NumpadSubtract","Control+Shift+Minus"],"39000":["Alt+Shift+KeyT"],"39001":["Contr'
      'ol+KeyL","Alt+KeyD"],"39002":["BrowserSearch","Control+KeyE","Control+KeyK"],"39003":["F10","Alt","Alt","AltGr"'
      '],"39004":["F6"],"39005":["Shift+F6"],"39006":["Alt+Shift+KeyB"],"39007":["Alt+Shift+KeyA"],"39009":["Control+F'
      '6"],"40000":["Control+KeyO"],"40004":["Control+Shift+KeyI"],"40005":["Control+Shift+KeyJ"],"40006":["Shift+Esca'
      'pe"],"40009":["Control+Shift+KeyB"],"40010":["Control+KeyH"],"40011":["Control+Shift+KeyO"],"40012":["Control+K'
      'eyJ"],"40013":["Control+Shift+Delete"],"40019":["F1"],"40021":["Alt+KeyE","Alt+KeyF"],"40023":["Control+Shift+K'
      'eyC"],"40134":["Control+Shift+KeyM"],"40237":["F12"],"40260":["F7"],"40261":["Control+Space"],"52500":["Control'
      '+Shift+KeyA"],"56003":["Alt+Shift+KeyN"],"56041":["Control+KeyM"],"56044":["Control+KeyB"]},"default_private_se'
      'arch_provider_data":{"alternate_urls":["{google:baseURL}#q={searchTerms}","{google:baseURL}search#q={searchTerm'
      's}","{google:baseURL}webhp#q={searchTerms}","{google:baseURL}s#q={searchTerms}","{google:baseURL}s?q={searchTer'
      'ms}"],"contextual_search_url":"{google:baseURL}_/contextualsearch?{google:contextualSearchVersion}{google:conte'
      'xtualSearchContextData}","created_by_policy":false,"created_from_play_api":false,"date_created":"0","doodle_url'
      '":"","favicon_url":"https://www.google.com/images/branding/product/ico/googleg_lodp.ico","id":"0","image_search'
      '_branding_label":"","image_translate_source_language_param_key":"sourcelang","image_translate_target_language_p'
      'aram_key":"targetlang","image_translate_url":"{google:baseSearchByImageURL}upload?filtertype=tr&{imageTranslate'
      'SourceLocale}{imageTranslateTargetLocale}","image_url":"{google:baseSearchByImageURL}upload","image_url_post_pa'
      'rams":"encoded_image={google:imageThumbnail},image_url={google:imageURL},sbisrc={google:imageSearchSource},orig'
      'inal_width={google:imageOriginalWidth},original_height={google:imageOriginalHeight}","input_encodings":["UTF-8"'
      '],"is_active":0,"keyword":":g","last_modified":"0","last_visited":"0","logo_url":"","new_tab_url":"","originati'
      'ng_url":"","preconnect_to_search_url":true,"prefetch_likely_navigations":true,"prepopulate_id":1,"safe_for_auto'
      'replace":true,"search_intent_params":["si","gs_ssp"],"search_url_post_params":"","short_name":"Google","side_im'
      'age_search_param":"sideimagesearch","side_search_param":"sidesearch","starter_pack_id":0,"suggestions_url":"{go'
      'ogle:baseSuggestURL}search?{google:searchFieldtrialParameter}client={google:suggestClient}&gs_ri={google:sugges'
      'tRid}&xssi=t&q={searchTerms}&{google:inputType}{google:omniboxFocusType}{google:cursorPosition}{google:currentP'
      'ageUrl}{google:pageClassification}{google:clientCacheTimeToLive}{google:searchVersion}{google:sessionToken}{goo'
      'gle:prefetchQuery}sugkey={google:suggestAPIKeyParameter}","suggestions_url_post_params":"","synced_guid":"11111'
      '111-1111-1111-1111-111111111111","url":"{google:baseURL}search?q={searchTerms}&{google:RLZ}{google:originalQuer'
      'yForSuggestion}{google:assistedQueryStats}{google:searchFieldtrialParameter}{google:iOSSearchLanguage}{google:p'
      'refetchSource}{google:searchClient}{google:sourceId}{google:contextualSearchVersion}ie={inputEncoding}","usage_'
      'count":0},"default_private_search_provider_guid":"11111111-1111-1111-1111-111111111111","location_bar_is_wide":'
      'true,"mouse_gesture":{"tip_font_name":"Times New Roman"},"need_administrator":0,"new_tab_page":{"background":{"'
      'random":false,"selected_value":"#000000","type":"color"},"hide_all_widgets":false,"show_background_image":true,'
      '"show_clock":false,"show_stats":false,"shows_options":1},"other_bookmarks_migrated":true,"search":{"default_ver'
      'sion":25},"shields_fp_settings_migration":true,"shields_settings_version":4,"tabs":{"mouse_shortcut_method":0},'
      '"today":{"p3a_curr_session_card_views":"0","p3a_total_card_views":[{"day":1683230400.0,"value":0.0}],"p3a_weekl'
      'y_card_views_count":[{"day":1683230400.0,"value":0.0}],"p3a_weekly_card_visits_count":[{"day":1683230400.0,"val'
      'ue":0.0}]},"toolbar":{"show_vertical_tab_button":false}},"catsxp_shields":{"p3a_ads_allow_domain_count":0,"p3a_'
      'ads_standard_domain_count":0,"p3a_ads_strict_domain_count":0,"p3a_first_reported_v2":true,"p3a_fp_allow_domain_'
      'count":0,"p3a_fp_standard_domain_count":0,"p3a_fp_strict_domain_count":0},"catsxp_sync_v2":{"reset_devices_prog'
      'ress_token_time":"13327757833155538","v1_meta_info_cleared":true,"v1_migrated":true},"countryid_at_install":210'
      '77,"default_apps_install_state":3,"domain_diversity":{"last_reporting_timestamp":"13327757834824807"},"download'
      '":{"default_directory":"D:\\Inet_OK"},"extensions":{"alerts":{"initialized":true},"chrome_url_overrides":{},"la'
      'st_chrome_version":"0.0.0.0"},"gcm":{"product_category_for_subtypes":"com.catsxp.windows"},"google":{"services"'
      ':{"consented_to_sync":false,"signin_scoped_device_id":"11111111-1111-1111-1111-111111111111"}},"intl":{"selecte'
      'd_languages":"ru-RU,ru,en-US,en"},"invalidation":{"per_sender_topics_to_handler":{"1013309121859":{},"818103597'
      '6":{}}},"media":{"device_id_salt":"2DB70DE6C473F9436E1848B302E5EA57","engagement":{"schema_version":5}},"media_'
      'router":{"enable_media_router":true,"receiver_id_hash_token":"LCR7WscJuVcV7CMIuv4JlnCJjsEG4aqM2vEj21FAoeq6rG8Gm'
      'xbEQceyEmswhm4HzeH+UcPTx4GT4s17bFopnw=="},"ntp":{"num_personal_suggestions":0,"shortcust_visible":false},"omnib'
      'ox":{"prevent_url_elisions":true},"privacy_sandbox":{"anti_abuse_initialized":true},"profile":{"avatar_index":2'
      '6,"content_settings":{"enable_quiet_permission_ui_enabling_method":{"notifications":1},"exceptions":{"accessibi'
      'lity_events":{},"anti_abuse":{},"app_banner":{},"ar":{},"auto_select_certificate":{},"automatic_downloads":{},"'
      'autoplay":{},"background_sync":{},"bluetooth_chooser_data":{},"bluetooth_guard":{},"bluetooth_scanning":{},"cam'
      'era_pan_tilt_zoom":{},"catsxpShields":{},"catsxpSpeedreader":{},"catsxp_ethereum":{},"catsxp_google_sign_in":{}'
      ',"catsxp_localhost_access":{},"catsxp_remember_1p_storage":{},"catsxp_solana":{},"client_hints":{},"clipboard":'
      '{},"cookies":{},"cosmeticFiltering":{},"durable_storage":{},"fedcm_active_session":{},"fedcm_idp_registration":'
      '{},"fedcm_idp_signin":{},"fedcm_share":{},"file_system_access_chooser_data":{},"file_system_last_picked_directo'
      'ry":{},"file_system_read_guard":{},"file_system_write_guard":{},"fingerprintingV2":{},"formfill_metadata":{},"g'
      'eolocation":{},"get_display_media_set_select_all_screens":{},"hid_chooser_data":{},"hid_guard":{},"httpUpgradab'
      'leResources":{},"http_allowed":{},"httpsUpgrades":{},"idle_detection":{},"images":{},"important_site_info":{},"'
      'insecure_private_network":{},"intent_picker_auto_display":{},"javascript":{},"javascript_jit":{},"legacy_cookie'
      '_access":{},"local_fonts":{},"media_engagement":{},"media_stream_camera":{},"media_stream_mic":{},"midi_sysex":'
      '{},"mixed_script":{},"nfc_devices":{},"notification_interactions":{},"notification_permission_review":{},"notif'
      'ications":{},"password_protection":{},"payment_handler":{},"permission_autoblocking_data":{},"permission_autore'
      'vocation_data":{},"popups":{},"private_network_chooser_data":{},"private_network_guard":{},"protected_media_ide'
      'ntifier":{},"protocol_handler":{},"reduced_accept_language":{},"referrers":{},"safe_browsing_url_check_data":{}'
      ',"sensors":{},"serial_chooser_data":{},"serial_guard":{},"shieldsAds":{},"shieldsCookiesV3":{},"site_engagement'
      '":{},"sound":{},"ssl_cert_decisions":{},"storage_access":{},"subresource_filter":{},"subresource_filter_data":{'
      '},"third_party_storage_partitioning":{},"top_level_storage_access":{},"trackers":{},"unused_site_permissions":{'
      '},"usb_chooser_data":{},"usb_guard":{},"vr":{},"webid_api":{},"webid_auto_reauthn":{},"window_placement":{}},"p'
      'ref_version":1},"created_by_version":"0.0.0.0","creation_time":"13327757825628624","default_content_setting_val'
      'ues":{"anti_abuse":2},"exit_type":"Normal","last_time_obsolete_http_credentials_removed":1683284292.442684,"las'
      't_time_password_store_metrics_reported":1683284262.464805,"managed_user_id":"","name":"User 1","were_old_google'
      '_logins_removed":true},"safebrowsing":{"event_timestamps":{},"metrics_last_log_time":"13327757832"},"savefile":'
      '{"default_directory":"D:\\Inet_OK"},"sessions":{"event_log":[{"crashed":false,"time":"13327757832550393","type"'
      ':0},{"restore_browser":true,"synchronous":true,"time":"13327757832831433","type":5},{"errored_reading":false,"t'
      'ab_count":0,"time":"13327757834234623","type":1,"window_count":0},{"did_schedule_command":true,"first_session_s'
      'ervice":true,"tab_count":1,"time":"13327758246138298","type":2,"window_count":1}],"session_data_status":3},"set'
      'tings":{"a11y":{"apply_page_colors_only_on_increased_contrast":true}},"signin":{"allowed":false},"spellcheck":{'
      '"dictionaries":["ru","en-US"],"dictionary":""},"supervised_user":{"metrics":{"day_id":154255}},"translate_site_'
      'blacklist":[],"translate_site_blocklist_with_time":{},"unified_consent":{"migration_state":10},"web_apps":{"did'
      '_migrate_default_chrome_apps":["MigrateDefaultChromeAppToWebAppsGSuite","MigrateDefaultChromeAppToWebAppsNonGSu'
      'ite"],"last_preinstall_synchronize_version":"0"}}'
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
Write-Host                  "Profile:   $profilePath" @darkcyan
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
