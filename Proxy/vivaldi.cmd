<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Vivaldi и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления при их выходе качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию (Release, Snapshot) и разрядность (x64/x86) браузера, указав нужное в $Edition и $Bitness.
:: Портабельность обеспечивает version.dll от ca-x (https://github.com/ca-x/vivaldi_plus/) или
:: от Bush2021 (https://github.com/Bush2021/chrome_plus) по выбору, настраиваемому в переменной $versiondll.
:: Конфиги version.dll настраиваются здесь же, в переменных $ConfigData,$ConfigCache в части имени и расположения папок профиля
:: и кэша, поэтому прописывать их напрямую в chrome++.ini/config.ini смысла нет.
:: Для проверки/скачивания обновлений и для браузера можно использовать opera-proxy (https://github.com/Alexey71/opera-proxy),
:: который будет скачан и запущен с заданными параметрами, при выходе новых версий будет автообновляться.
:: Если папка профиля существует и указан путь к ней в $ConfigData, то браузер запустится с этим профилем.
:: Если нет, то создается новый с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=5&topic=51073&start=440#7),
:: а если ещё и присвоено значение $ExtFolder, то дополнительно будут подключены CSS-настройки внешнего вида браузера от Insorg.
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
$ConfigData = "%app%\..\Profile" # путь к профилю, который будет добавлен в chrome++.ini/config.ini
$ConfigCache = "%app%\..\Cache" # путь к кэшу, который будет добавлен в chrome++.ini/config.ini
$RunMode = 0 # 0 - обычный режим, 1 - только запуск, 2 - только проверка/установка обновлений
$CreateShortcut = $false # создать ярлык на рабочем столе
$AskUpdate = $true # перед обновлением спрашивать
$Backup = $false # при обновлении создавать в папке батника zip-бэкап профиля
$MakeStub = $false # создавать взамен удаляемых в профиле папок ($DelDirs) файлы-заглушки нулевого размера
$Edition = 0 # 0 - Release, 1 - snapshot
$Bitness = "x64" # для 32bit-версии указать "x86"
$VersionDll = 0 # 0 - библиотека dll от Bush2021, 1 - от ca-x (czyt.tech)
$ExtFolder = "" # папка для доп. файлов (css,js) рядом со скриптом, если оставить пустым, папка не создается
$AppDir = "App" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$DllPath = "" # локальный путь к windows_x86/x64.zip или setdll.7z, если оставить пустым, будет скачан с github.com
$UseProxy = 0 # 0 - не включать, 1 - только для браузера, 2 - для браузера и для проверки/закачки обновлений
$ProxyPath = "" # путь к файлу опера прокси, если оставить пустым, будет скачан с github.com (при $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18080","-verbosity 30" # параметры прокси
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # ключи запуска браузера
   "--no-default-browser-check"
   "--no-first-run"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
#   "--gpu-disk-cache-size-kb=1"
   "--show-component-extension-options"
   "--proxy-server=$(($ProxyArg -Split " ")[1])"
   "--debug-packed-apps"
#   "--disable-component-update" # раскомментировать этот и следующий ключи для запрета автообновления расширений
#   "--disable-background-networking"
   "--disable-breakpad"
   "--disable-logging"
   "--process-per-site"
   "--disable-crash-reporter"
   "--extension-content-verification@1"
   "--disable-dinosaur-easter-egg"
   "--allow-legacy-extension-manifests"
   "--disable-features=MediaRouter,PreloadMediaEngagementData,MediaEngagementBypassAutoplayPolicies,UseEcoQoSForBackgroundProcess,PrintCompositorLPAC,ExtensionsManifestV3Only,ExtensionManifestV2Disabled,ExtensionManifestV2Unsupported,ExtensionManifestV2DeprecationWarning"
   "--enable-features=dns-over-https,TurnOffStreamingMediaCachingAlways,TurnOffStreamingMediaCachingOnBattery"
   "--allow-legacy-mv2-extensions"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
   "ActorSafetyLists"
   "*BrowserMetrics*"
   "AmountExtractionHeuristicRegexes"
   "AutofillAiModelCache"
   "AutofillStates"
   "Cache"
   "Caps"
   "CaptchaProviders"
   "Certificate*"
   "ClientSidePhishing"
   "CommerceHeuristics"
   "component_crx_cache"
   "CookieReadinessList"
   "Crashpad"
   "Crowd Deny"
   "DawnCache"
   "DawnGraphiteCache"
   "DawnWebGPUCache"
   "DesktopSharingHub"
   "EVWhitelist"
   "extensions_crx_cache"
   "FileTypePolicies"
   "FirstPartySetsPreloaded"
   "GPUCache"
   "GPUPersistentCache"
   "GraphiteDawnCache"
   "Greaselion"
   "GrShaderCache"
   "hyphen-data"
   "InterventionPolicyDatabase"
   "Local Traces"
   "MEIPreload"
   "OnDeviceHeadSuggestModel"
   "OpenCookieDatabase"
   "Optimization*"
   "OriginTrials"
   "PKIMetadata"
   "ProbabilisticRevealTokenRegistry"
   "Safe Browsing*"
   "SafetyTips"
   "screen_ai"
   "segmentation_platform"
   "ShaderCache"
   "SSLErrorAssistant"
   "Subresource Filter"
   "TpcdMetadata"
   "TrustTokenKeyCommitments"
   "UrlParamClassifications"
   "WasmTtsEngine"
   "Webstore Downloads"
   "WidevineCdm"
   "ZxcvbnData"
   "Default\AdBlockRules\*"
   "Default\AutofillStrikeDatabase"
   "Default\blob_storage"
   "Default\BudgetDatabase"
   "Default\Cache"
   "Default\chrome_cart_db"
   "Default\ClientCertificates"
   "Default\commerce_subscription_db"
   "Default\coupon_db"
   "Default\databases"
   "Default\DawnGraphiteCache"
   "Default\DawnWebGPUCache"
   "Default\discount*"
   "Default\Download Service"
   "Default\Feature Engagement Tracker"
   "Default\feedv2"
   "Default\File System"
   "Default\GCM Store"
   "Default\GPUCache"
   "Default\GraphiteDawnCache"
   "Default\GrShaderCache"
   "Default\JumpListIcons*"
   "Default\Managed Extension Settings"
   "Default\optimization_guide*"
   "Default\parcel_tracking_db"
   "Default\PersistentOriginTrials"
   "Default\Platform Notifications"
   "Default\Safe Browsing*"
   "Default\Segmentation Platform"
   "Default\Service Worker\Cache*"
   "Default\ShaderCache"
   "Default\Shared Dictionary"
   "Default\shared_proto_db"
   "Default\Site Characteristics Database"
   "Default\Sync App Settings"
   "Default\SyncedFiles"
   "Default\VideoDecodeStats"
   "Default\VivaldiDirectMatchIcons"
   "Default\VivaldiThumbnails"
   "Default\WebrtcVideoStats"
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
   "*Cache*"
   "*.tmp"
   ".gitignore"
   "AdverseAdSiteList.json"
   "BrowserMetrics*"
   "chrome_shutdown*"
   "CrashpadMetrics*"
   "ev_hashes*"
   "first_party_sets.*"
   "persisted_first_party_sets.json"
   "Safe Browsing *"
   "search_engines*"
   "Variations"
   "Default\*.bak"
   "Default\*.tmp"
   "Default\AdBlockState*"
   "Default\ads_service"
   "Default\BookmarkMergedSurfaceOrdering"
   "Default\BrowsingTopics*"
   "Default\DIPS"
   "Default\heavy_ad_intervention_opt_out.db*"
   "Default\InterestGroups"
   "Default\MailSearchDB"
   "Default\MediaDeviceSalts"
   "Default\Network\*.tmp"
   "Default\Network\Reporting and NEL"
   "Default\Network\SCT Auditing Pending Reports"
   "Default\optimization_guide*"
   "Default\passkey_enclave_state"
   "Default\PreferredApps"
   "Default\PrivateAggregation"
   "Default\README"
   "Default\Reporting and NEL"
   "Default\SCT Auditing Pending Reports"
   "Default\SharedStorage"
   "Default\Shortcuts"
   "Default\Translate*"
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
#   "Default\Session Storage\*"
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
   "HKEY_CURRENT_USER\SOFTWARE\Vivaldi"
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
   "update_notifier.exe"
   "vivaldi_proxy.exe"
   "numver\Dictionaries"
   "numver\IwaKeyDistribution"
   "numver\MEIPreload"
   "numver\PrivacySandboxAttestationsPreloaded"
   "numver\VisualElements"
   "numver\dxcompiler.dll"
   "numver\dxil.dll"
   "numver\eventlog_provider.dll"
   "numver\notification_helper.exe"
   "numver\vivaldi.dll.sig"
   "numver\vivaldi.exe.sig"
   "numver\Locales\*FEMININE.pak"
   "numver\Locales\*MASCULINE.pak"
   "numver\Locales\*NEUTER.pak"
   "numver\Locales\af.pak"
   "numver\Locales\am.pak"
   "numver\Locales\ar.pak"
   "numver\Locales\az.pak"
   "numver\Locales\be.pak"
   "numver\Locales\bg.pak"
   "numver\Locales\bn.pak"
   "numver\Locales\ca.pak"
   "numver\Locales\ca-valencia.pak"
   "numver\Locales\cs.pak"
   "numver\Locales\da.pak"
   "numver\Locales\de.pak"
   "numver\Locales\de-CH.pak"
   "numver\Locales\el.pak"
   "numver\Locales\en-GB.pak"
   "numver\Locales\eo.pak"
   "numver\Locales\es.pak"
   "numver\Locales\es-419.pak"
   "numver\Locales\es-PE.pak"
   "numver\Locales\et.pak"
   "numver\Locales\eu.pak"
   "numver\Locales\fa.pak"
   "numver\Locales\fi.pak"
   "numver\Locales\fil.pak"
   "numver\Locales\fr.pak"
   "numver\Locales\fy.pak"
   "numver\Locales\gd.pak"
   "numver\Locales\gl.pak"
   "numver\Locales\gu.pak"
   "numver\Locales\he.pak"
   "numver\Locales\hi.pak"
   "numver\Locales\hr.pak"
   "numver\Locales\hu.pak"
   "numver\Locales\hy.pak"
   "numver\Locales\id.pak"
   "numver\Locales\io.pak"
   "numver\Locales\is.pak"
   "numver\Locales\it.pak"
   "numver\Locales\ja.pak"
   "numver\Locales\ja-KS.pak"
   "numver\Locales\jbo.pak"
   "numver\Locales\ka.pak"
   "numver\Locales\kab.pak"
   "numver\Locales\kmr.pak"
   "numver\Locales\kn.pak"
   "numver\Locales\ko.pak"
   "numver\Locales\lt.pak"
   "numver\Locales\lv.pak"
   "numver\Locales\mk.pak"
   "numver\Locales\ml.pak"
   "numver\Locales\mr.pak"
   "numver\Locales\ms.pak"
   "numver\Locales\nb.pak"
   "numver\Locales\nl.pak"
   "numver\Locales\nn.pak"
   "numver\Locales\pa.pak"
   "numver\Locales\pl.pak"
   "numver\Locales\pt-BR.pak"
   "numver\Locales\pt-PT.pak"
   "numver\Locales\ro.pak"
   "numver\Locales\sc.pak"
   "numver\Locales\sk.pak"
   "numver\Locales\sl.pak"
   "numver\Locales\sq.pak"
   "numver\Locales\sr.pak"
   "numver\Locales\sr-Latn.pak"
   "numver\Locales\sv.pak"
   "numver\Locales\sw.pak"
   "numver\Locales\ta.pak"
   "numver\Locales\te.pak"
   "numver\Locales\th.pak"
   "numver\Locales\tr.pak"
   "numver\Locales\uk.pak"
   "numver\Locales\ur.pak"
   "numver\Locales\vi.pak"
   "numver\Locales\zh-CN.pak"
   "numver\Locales\zh-TW.pak"
   "numver\resources\vivaldi\adblocker_resources"
   "numver\resources\vivaldi\default-bookmarks"
   "numver\resources\vivaldi\resources\favicons"
   "numver\resources\vivaldi\resources\sd_thumbnails"
   "numver\resources\vivaldi\_locales\af"
   "numver\resources\vivaldi\_locales\am"
   "numver\resources\vivaldi\_locales\ar"
   "numver\resources\vivaldi\_locales\az"
   "numver\resources\vivaldi\_locales\bar"
   "numver\resources\vivaldi\_locales\be"
   "numver\resources\vivaldi\_locales\bg"
   "numver\resources\vivaldi\_locales\bn"
   "numver\resources\vivaldi\_locales\bs"
   "numver\resources\vivaldi\_locales\ca"
   "numver\resources\vivaldi\_locales\ca@valencia"
   "numver\resources\vivaldi\_locales\ckb"
   "numver\resources\vivaldi\_locales\cs"
   "numver\resources\vivaldi\_locales\cy"
   "numver\resources\vivaldi\_locales\da"
   "numver\resources\vivaldi\_locales\de"
   "numver\resources\vivaldi\_locales\de_CH"
   "numver\resources\vivaldi\_locales\el"
   "numver\resources\vivaldi\_locales\en_CA"
   "numver\resources\vivaldi\_locales\en_GB"
   "numver\resources\vivaldi\_locales\en_US"
   "numver\resources\vivaldi\_locales\eo"
   "numver\resources\vivaldi\_locales\es"
   "numver\resources\vivaldi\_locales\es_"
   "numver\resources\vivaldi\_locales\es_419"
   "numver\resources\vivaldi\_locales\es_AR"
   "numver\resources\vivaldi\_locales\es_MX"
   "numver\resources\vivaldi\_locales\es_PE"
   "numver\resources\vivaldi\_locales\et"
   "numver\resources\vivaldi\_locales\eu"
   "numver\resources\vivaldi\_locales\fa"
   "numver\resources\vivaldi\_locales\fi"
   "numver\resources\vivaldi\_locales\fil"
   "numver\resources\vivaldi\_locales\fr"
   "numver\resources\vivaldi\_locales\fy"
   "numver\resources\vivaldi\_locales\ga"
   "numver\resources\vivaldi\_locales\gd"
   "numver\resources\vivaldi\_locales\gl"
   "numver\resources\vivaldi\_locales\gu"
   "numver\resources\vivaldi\_locales\he"
   "numver\resources\vivaldi\_locales\hi"
   "numver\resources\vivaldi\_locales\hr"
   "numver\resources\vivaldi\_locales\hu"
   "numver\resources\vivaldi\_locales\hy"
   "numver\resources\vivaldi\_locales\ia"
   "numver\resources\vivaldi\_locales\id"
   "numver\resources\vivaldi\_locales\io"
   "numver\resources\vivaldi\_locales\is"
   "numver\resources\vivaldi\_locales\it"
   "numver\resources\vivaldi\_locales\ja"
   "numver\resources\vivaldi\_locales\ja_KS"
   "numver\resources\vivaldi\_locales\jbo"
   "numver\resources\vivaldi\_locales\ka"
   "numver\resources\vivaldi\_locales\kab"
   "numver\resources\vivaldi\_locales\kmr"
   "numver\resources\vivaldi\_locales\kn"
   "numver\resources\vivaldi\_locales\ko"
   "numver\resources\vivaldi\_locales\ln"
   "numver\resources\vivaldi\_locales\lt"
   "numver\resources\vivaldi\_locales\lv"
   "numver\resources\vivaldi\_locales\man"
   "numver\resources\vivaldi\_locales\mk"
   "numver\resources\vivaldi\_locales\ml"
   "numver\resources\vivaldi\_locales\mn"
   "numver\resources\vivaldi\_locales\mr"
   "numver\resources\vivaldi\_locales\ms"
   "numver\resources\vivaldi\_locales\nb"
   "numver\resources\vivaldi\_locales\nl"
   "numver\resources\vivaldi\_locales\nn"
   "numver\resources\vivaldi\_locales\pa"
   "numver\resources\vivaldi\_locales\pcm"
   "numver\resources\vivaldi\_locales\pl"
   "numver\resources\vivaldi\_locales\pt_BR"
   "numver\resources\vivaldi\_locales\pt_PT"
   "numver\resources\vivaldi\_locales\ro"
   "numver\resources\vivaldi\_locales\sc"
   "numver\resources\vivaldi\_locales\si"
   "numver\resources\vivaldi\_locales\sk"
   "numver\resources\vivaldi\_locales\sl"
   "numver\resources\vivaldi\_locales\sq"
   "numver\resources\vivaldi\_locales\sr"
   "numver\resources\vivaldi\_locales\sr_Latn"
   "numver\resources\vivaldi\_locales\sv"
   "numver\resources\vivaldi\_locales\sw"
   "numver\resources\vivaldi\_locales\ta"
   "numver\resources\vivaldi\_locales\te"
   "numver\resources\vivaldi\_locales\th"
   "numver\resources\vivaldi\_locales\tr"
   "numver\resources\vivaldi\_locales\uk"
   "numver\resources\vivaldi\_locales\vi"
   "numver\resources\vivaldi\_locales\zh_CN"
   "numver\resources\vivaldi\_locales\zh_HANT"
   "numver\resources\vivaldi\_locales\zh_HK"
   "numver\resources\vivaldi\_locales\zh_TW"
)

$Trash = @( # папки и файлы вне профиля, подлежащие удалению после закрытия браузера
#   "$env:TEMP\*.tmp"
   "$env:LocalAppData\CrashDumps"
   "$env:USERPROFILE\.vivaldi*"
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
if ($Edition -eq 1 -or $Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = 'Vivaldi' + @(if ($Edition -ne 0) {' Snapshot'}) +" $Bitness" -join ''

$ExeName = 'vivaldi.exe'

if (-not $ProxyPath) {$ProxyPath = "$scriptPath\opera-proxy.windows-amd64.exe"}

if (-not $ConfigData) {$ConfigData = "%app%\..\Profile"}
$profilePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $($ConfigData -replace '%app%','.')))

if ($ConfigCache -ne 'nul') {
   if (-not $ConfigCache) {$ConfigCache = "%app%\..\Cache"}
   $cachePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $($ConfigCache -replace '%app%','.')))
}

if ($VersionDll -ne 0 -and $DllPath -and "$(Split-Path -Parent $DllPath)\windows_$Bitness.zip" -ne $DllPath) {
   $DllPath = $null
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
$Script:MutexName = "Global\VivaldiPortable$($scriptName -replace '[\\:]','_')"

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
      'AAABAAEAEBAgAAAAAAAoBQAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAUA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAABNzfmMjg467E4OOvwODjq/zc36P83N+j/'
      'Nzfn/zc35v83N+b/Nzfm/zc35/83N+bxNzflsjMz1DUAAAAFNzfmMjk57fA4'
      'OOv/ODjq/zg46f83N+j/Nzfn/zc35v83N+X/Nzfl/zc35f83N+b/Nzfm/zc3'
      '5/83N+jwMzPUNTg47LE4OOz/ODjr/zg46v83N+j/Nzfo/zc35/83N+X/RETn'
      '/zY25P82NuT/Nzfl/zc35v83N+f/Nzfo/zc357I5Oe3wODjs/zg46/84OOr/'
      'Nzfo/zc36P9dXev/5+f8/+fn/P9cXOn/Njbk/zc35f83N+b/Nzfn/zc36P84'
      'OOnwOTnt/zg47P84OOv/ODjq/zc36P83N+j/zs75////////////zc34/zY2'
      '5P83N+X/Nzfm/zc35/83N+j/ODjp/zk57f84OOz/ODjr/zg46v83N+j/goLx'
      '//////////////////////+Cgu//Nzfm/zc35v83N+f/Nzfo/zg46f85Oe3/'
      'ODjs/zg46/84OOr/RETq/+fn/P//////////////////////5+f8/0RE6f83'
      'N+f/Nzfo/zc36P84OOr/OTnt/zk57f84OOz/ODjr/5yc9f//////////////'
      '//+0tPb/qKj1//////+bm/T/Nzfo/zc36P84OOn/ODjq/zk57v85Oe3/ODjs'
      '/1FR7v////////////////9qau//Nzfo/zc36P+bm/T//////1FR7P84OOr/'
      'ODjq/zg46/85Oe7/OTnt/zk57f/Bwfn///////////+1tff/ODjq/zg46v84'
      'OOr/dnbx///////Bwfj/ODjr/zg46/84OOz/OTnu/zk57v85Oe3/29v8////'
      '///z8/7/RETs/zg46/84OOv/ODjr/4OD8////////////zg47P84OOz/OTnt'
      '/zk57v85Oe7/OTnu/2tr8v/z8/7/hIT0/zg47P84OOz/ODjs/zg47P84OOz/'
      '5+f9/5yc9v85Oe3/OTnt/zk57f85Oe/wOTnu/zk57v85Oe7/OTnu/zk57f85'
      'Oe3/OTnt/zk57f85Oe3/OTnt/zk57f85Oe3/OTnt/zk57v85Oe7wOTnvsDk5'
      '7/85Oe7/OTnu/zk57v85Oe7/OTnu/zk57v85Oe7/OTnu/zk57v85Oe7/OTnu'
      '/zk57v85Oe7/OTnusDk57zA5Oe/wOTnv/zk57/85Oe//OTnu/zk57v85Oe7/'
      'OTnu/zk57v85Oe7/OTnu/zk57v85Oe7/OTnv8Dk57zD///8AOTnvMDk577A5'
      'Oe/wOTnv/zk57/85Oe//OTnv/zk57/85Oe//OTnv/zk57/85Oe/wOTnvsDk5'
      '7zD///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
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

   $arch = if ($Bitness -ne 'x86') {'.x64'} else {$null}
   $url = if ($Edition -ne 1) {
      "https://update.vivaldi.com/update/1.0/public/appcast$($arch).xml"
   } else {
      'https://vivaldi.com/feed'
   }

   Write-Host "Request:   $url"

   try {
      $response = (Make-NetRequest -Url $url).Content.ReadAsStringAsync().Result
      if (-not $response) {throw 'response is NULL'}
      if ($Edition -ne 1) {
         $Script:distrLink = ([xml]$response).rss.channel.item.enclosure.url
         $Script:latest = [version](([xml]$response).rss.channel.item.enclosure.version)
      } else {
         $script:distrLink = (Get-HtmlLinks -Html $response) -like "*x64.exe" | Select-Object -First 1
         if ($distrLink -match '\.(\d+\.\d+\.\d+\.\d+)\.x64\.exe') {
            $script:latest = [version]$matches[1]
         }
      }
      if (-not $distrLink) {throw 'distrLink is NULL'}
      if (-not $latest) {throw 'latest is NULL'}
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\vivaldi.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      # setdll.7z, windows_x86/x64.zip
      if (-not [IO.File]::Exists("$DllPath")) {
         $DllPath,$dllUrl = if ($VersionDll -eq 0) {
            "$tmpdir\setdll.7z","https://github.com/Bush2021/chrome_plus/releases/latest/download/setdll.7z"
         } else {
            "$tmpdir\windows_$Bitness.zip","https://github.com/ca-x/vivaldi_plus/releases/latest/download/windows_$Bitness.zip"
         }
         if (-not (Download-File -Source $dllUrl -Dest $DllPath)) {throw}
         Write-Host "Download $($DllUrl.Split('/')[-1]): OK" @green
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
      &($7zpath) e -aoa "$tmpdir\vivaldi.exe" "vivaldi.7z" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      &($7zpath) x -t7z -aoa "$tmpdir\vivaldi.7z" "Vivaldi-bin\" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack vivaldi.7z" -MessageType "Error"
         throw 'Error unpack vivaldi.7z'
      }
      Write-Host "Unpack vivaldi.7z: OK" @green

      if ($VersionDll -eq 0) {
         &($7zpath) e -t7z -aoa "$DllPath" $("version-"+$Bitness+".dll") -o"$tmpdir" | Out-Null
         if ($LASTEXITCODE -ne 0) {
            Show-Balloon -Message "Error unpack setdll.7z" -MessageType "Error"
            throw 'Error unpack setdll.7z'
         }
         Write-Host "Unpack setdll.7z: OK" @green
         Move-Item -Path "$tmpdir\$("version-"+$Bitness+".dll")" -Destination "$tmpdir\Vivaldi-bin\version.dll" -Force -ea 0
      } else {
         try {
            Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DllPath, "$tmpdir\Vivaldi-bin")
            Write-Host "Unpack windows_$Bitness.zip: OK" @green
         } catch {
            Show-Balloon -Message "Error unpack windows_$Bitness.zip" -MessageType "Error"
            throw $_
         }
      }

      # Список файлов для сохранения
      $nodel = @(
         "$($profilePath.split('\')[-1])"
         "$((($profilePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      $nodel += @(
         "$($ProxyPath.split('\')[-1])"
         "$((($ProxyPath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      if ($cachePath) {
         $nodel += @(
            "$(($cachePath -Split '\\')[-1])"
            "$((($cachePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
         )
      }

      $nodel += @(
         'chrome++.ini'
         'config.ini'
         'debug.log'
      )

      if ([IO.Directory]::Exists($AppPath)) {
         Get-Item -Path "$AppPath\*" -Exclude $nodel -ea 0 | Remove-Item -Recurse -Force -ea 0
         Write-Host "Delete old files: OK" @green
      } else {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      $dirver = (Get-ChildItem -Path "$tmpdir\Vivaldi-bin\*.*.*.*" -Directory -ea 0).Name
      if (-not $dirver) {
         Show-Balloon -Message "Error in defining the directory structure" -MessageType "Error"
         throw 'Not detect directory number version'
      }

      $excludeList = $SetupExclude + @(
         'config.ini.example'
         'config.ini.example.zh-CN'
      ) -replace 'numver',"$dirver"

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\vivaldi-bin\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\vivaldi-bin\*" -Destination $AppPath -Exclude $dirver -Recurse -Force
      Copy-Item -Path "$tmpdir\vivaldi-bin\$dirver\*" -Destination $AppPath -Recurse -Force
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
      '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":["vivaldi-css-mods@1"],"ignore-gpu-b'
      'locklist":["smooth-scrolling@2"]},"hardware_acceleration_mode_previous":true,"profile":{"last_used":"Default"}}'
   ) -join ''

   $preferencesContent = @(
      '{"NewTabPage":{"DisabledModules":["dummy","dummy2"],"ModulesVisible":false},"alternate_error_pages":{"backup":f'
      'alse},"autocomplete":{"retention_policy_last_version":108},"autofill":{"credit_card_enabled":false,"enabled":fa'
      'lse,"orphan_rows_removed":true,"payment_card_benefits":false,"payment_cvc_storage":false,"profile_enabled":fals'
      'e},"bookmark_bar":{"show_apps_shortcut":false,"show_on_all_tabs":false,"show_only_on_ntp":true},"browser":{"che'
      'ck_default_browser":false,"clear_data":{"browsing_history_basic":true,"cache_basic":true,"cookies_basic":true,"'
      'form_data":true,"hosted_apps_data":true,"media_licenses":true,"passwords":true,"preferences_migrated_to_basic":'
      'true,"site_settings":true,"time_period":4,"time_period_basic":4},"clear_lso_data_enabled":true,"has_seen_welcom'
      'e_page":true,"last_clear_browsing_data_tab":1,"window_placement":{"bottom":720,"left":64,"maximized":true,"righ'
      't":1200,"top":32}},"credentials_enable_autosignin":false,"credentials_enable_service":false,"default_apps_insta'
      'll_state":2,"download":{"directory_upgrade":true,"prompt_for_download":true},"enable_a_ping":false,"enable_do_n'
      'ot_track":true,"first_run_tabs":[],"https_only_mode_enabled":true,"import_bookmarks":false,"import_history":fal'
      'se,"import_home_page":false,"import_search_engine":false,"invalidation":{"per_sender_topics_to_handler":{"10133'
      '09121859":{},"8181035976":{}}},"media":{"engagement":{"schema_version":5}},"net":{"network_prediction_options":'
      '2},"ntp":{"num_personal_suggestions":0},"omnibox":{"prevent_url_elisions":true},"payments":{"can_make_payment_e'
      'nabled":false},"plugins":{"plugins_list":[]},"profile":{"avatar_index":3,"block_third_party_cookies":true,"cont'
      'ent_settings":{"clear_on_exit_migrated":true,"enable_quiet_permission_ui_enabling_method":{"notifications":1},"'
      'exceptions":{},"pref_version":1},"default_content_setting_values":{"background_sync":2,"cookies":1},"exit_type"'
      ':"Normal","exited_cleanly":true,"local_avatar_index":3,"managed_user_id":"","name":"","password_manager_enabled'
      '":false,"were_old_google_logins_removed":true},"safebrowsing":{"enabled":false,"event_timestamps":{}},"search":'
      '{"suggest_enabled":false},"settings":{"a11y":{"apply_page_colors_only_on_increased_contrast":true}},"signin":{"'
      'allowed":false},"spellcheck":{"dictionaries":["ru"],"dictionary":""},"translate":{"enabled":false},"unified_con'
      'sent":{"migration_state":10},"vivaldi":{"address_bar":{"extensions":{"hidden_extensions":[],"render_in_dropdown'
      '":true,"show_all_toggle":true},"highlight_base_domain":true,"omnibox":{"show_top_sites":false},"search":{"displ'
      'ay":1,"show_favicon":true,"suggest_enabled":false},"show_full_url":true,"show_profile":false,"show_qr_generator'
      '":true,"visible":false},"appearance":{"css_ui_mods_directory":"","density":false,"range_buttons":true},"bookmar'
      'ks":{"panel":{"sorting":{"sortField":"manually","sortOrder":1}}},"chained_commands":{"command_list":[],"deleted'
      '_command_list":[],"version":1},"dashboard":{"column_limit":4,"enabled":false,"sticky_notes":[],"widgets":[]},"d'
      'ownloads":{"start_automatically":false},"experiments":["css_mods","custom_buttons"],"features":{"calendar":fals'
      'e,"feeds":false,"mail":false},"homepage":"vivaldi://startpage","homepage_cache":"","incognito":{"show_intro":fa'
      'lse},"language_at_install":"ru","menu":{"compact":true,"display":0,"icon_type":1},"panels":{"web":{"elements":['
      '],"removed_elements":[{"id":"WEBPANEL_949d4873-deed-4168-b306-92d1848687a5","mobileMode":true,"title":"Social",'
      '"url":"https://social.vivaldi.net/","zoom":1},{"id":"WEBPANEL_ckmam0bsw00002y5xoafpww5i","mobileMode":true,"ori'
      'gin":"bundle","resizable":false,"title":"Help","url":"https://help.vivaldi.com/","width":-1,"zoom":1},{"id":"WE'
      'BPANEL_ckn7fhhqx0000hc2roo8jshm4","mobileMode":true,"origin":"bundle","resizable":false,"title":"Wiki","url":"h'
      'ttps://wikipedia.org","width":-1,"zoom":1}]},"window_defaults":{"barVisible":false,"panelVisible":false,"select'
      'edPanel":"PanelDownloads","width":310}},"popups":{"show_in_tab":true},"privacy":{"adverse_ad_block":{},"google_'
      'component_extensions":{"hangout_services":false}},"settings":{"in_tab":true,"mono_icons":false},"show_extension'
      's_banner":false,"startpage":{"navigation":2,"speed_dial":{"add_button_visible":false,"display_search":false,"ga'
      'me_button_show":false,"privacy_stats_show":false}},"startup":{"check_is_default":false,"has_seen_feature":1},"s'
      'tatus_bar":{"display":2,"minimized":1},"system":{"desktop_theme_color":0,"show_exit_confirmation_dialog":false}'
      ',"tabs":{"active_min_size":30,"at_edge":true,"cycle_by_recent_order":false,"dim_hibernated":true,"horizontal_sc'
      'rolling":false,"show_synced_tabs_button":false,"show_trash_can":true,"stacking":{"allow_dnd":true,"dnd_delay":5'
      '0,"mode":3,"open_accordions":[]},"thumbnails":false,"tooltip":false},"theme":{"dim_blurred":false,"schedule":{"'
      'enabled":0,"o_s":{"dark":"Vivaldi2","light":"Vivaldi5"}},"simple_scrollbar":false,"use_animation":false},"theme'
      's":{"current":"Vivaldi5"},"toolbars":{"navigation":[],"panel":["PanelBookmarks","PanelReadingList","PanelDownlo'
      'ads","PanelHistory","PanelNotes","PanelTranslate","PanelWindow","PanelSession","PanelMail","PanelCalendar","Pan'
      'elTasks","PanelFeeds","PanelContacts","PanelWeb","FlexibleSpacer","Settings"],"tabbar_after":["NewTab","Flexibl'
      'eSpacer","TabButton","Extensions"],"tabbar_before":["PanelToggle","Back","Forward","Reload","AddressField","Spa'
      'cer","WorkspaceButton"]},"translate":{"enabled":false},"webpages":{"smooth_scrolling":{"enabled":false},"tab_zo'
      'om":{"enabled":false}},"welcome":{"read_pages":["welcome_four","import_data","tracker_and_ad","personalize","ta'
      'bs","touch","welcome_four","import_data","tracker_and_ad","personalize","tabs","touch"],"seen_pages":["welcome_'
      'four","import_data","tracker_and_ad","personalize","tabs","touch"]},"windows":{"show_window_close_confirmation_'
      'dialog":false},"workspaces":{"button":{"mouse_wheel_enabled":false,"show_in_tabbar":false,"show_name":true},"en'
      'abled":false}}}'
   ) -join ''

   try {

      [IO.Directory]::CreateDirectory("$profilePath\Default") | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])\Default"

      if ($ExtFolder) {
         $extFolderPath = Join-Path $scriptPath $ExtFolder
         if (-not [IO.Directory]::Exists($extFolderPath)) {
            [IO.Directory]::CreateDirectory($extFolderPath) | Out-Null
            Write-Host " ---> $($ExtFolder)"
         }
         $repl = $extFolderPath -replace '\\','\\'
         $preferencesContent = $preferencesContent -replace '(?<=css_ui_mods_directory\x22:\x22)',$repl
         @(
            '#browser, #browser + div, #browser + div + div, #browser button, #browser input, #browser select, '
            '#browser textarea, .info , .tab-position .tab { font-family:Arial,Tahoma,''MS Sans Serif'',system-'
            'ui,sans-serif !important; font-weight:400; font-size:11px; line-height:1.0; text-shadow:transparen'
            't 0px 0px 0px, rgba(0,0,0,0.125) 0px 0px 0px !important; }'
         ) -join '' | Set-Content -Path "$extFolderPath\custom.css"
         @(
            '.tabs-top #tabs-tabbar-container .toolbar-tabbar-before .UrlBar-AddressField, .tabs-top #tabs-tabb'
            'ar-container .toolbar-tabbar-after .UrlBar-AddressField, .tabs-bottom #tabs-tabbar-container .tool'
            'bar-tabbar-before .UrlBar-AddressField, .tabs-bottom #tabs-tabbar-container .toolbar-tabbar-after '
            '.UrlBar-AddressField { min-width: 25vw !important; max-width: 25vw !important; margin-top: 0 !important; }'
         ) -join '' | Add-Content -Path "$extFolderPath\custom.css"
         Write-Host " ---> $($ExtFolder)\custom.css"
      }
   
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

# Настройка прокси
Function Get-Proxy {
   if (-not $UseProxy) {return $false}

   if (-not $ProxyArg) {$Script:ProxyArg = '-'}

   if (-not $lastcheck) {$lastcheck='18032026'}
   $daysCheckProxy = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   if ($RunMode -eq 1 -or $daysCheckProxy -lt [int]$CheckInterval+99) {
      if ([IO.File]::Exists($ProxyPath)) {
         return $true
      }
   }

   try {
      $proxyResponse = Make-NetRequest -Url 'https://github.com/Alexey71/opera-proxy/releases/latest'
      $lastproxy = [version]($proxyResponse.RequestMessage.RequestUri.AbsoluteUri -Split 'tag/v')[1]
      if (-not $lastproxy) {throw 'lastproxy is NULL'}
      $urlproxy = 'https://github.com/Alexey71/opera-proxy/releases/latest/download/opera-proxy.windows-amd64.exe'
      Write-Host "Proxy latest: $lastproxy"
   } catch {
      Write-Host "$_.Exception.Message" @red
      Write-Host "Error check proxy latest" @red
      if ([IO.File]::Exists($ProxyPath)) {return $true} else {return $false}
   }

   if ([IO.File]::Exists($ProxyPath)) {

      try {
         $proxyVersion = (&($ProxyPath) -version 2>$null) -Split 'v'
         if ($proxyVersion.Count -gt 1) {
            $currproxy = [version]$proxyVersion[1]
         } else {
            $currproxy = [version]"0.0.0"
         }
      } catch {
         Write-Host "Error check proxy current" @red
         $currproxy = [version]"0.0.0"
      }

      if ($lastproxy -gt $currproxy) {
         Write-Host "Proxy installed: $currproxy - update is available"
         Move-Item -LiteralPath $ProxyPath -Destination "$ProxyPath.old" -ErrorAction SilentlyContinue
         if (Download-File -Source $urlproxy -Dest $ProxyPath) {
            Write-Host "Proxy new v$lastproxy download: OK" @green
            try {[System.IO.File]::Delete("$ProxyPath.old")}
            catch {Write-Host "$_.Exception.Message" @red}
         } else {
            Move-Item -LiteralPath "$ProxyPath.old" -Destination $ProxyPath -Force -ErrorAction SilentlyContinue
         }
      }  else {
         Write-Host "Proxy installed: $currproxy - no update required"
      }
      return $true

   } else {

      try {
         $dirproxy = Split-Path -Path $ProxyPath -Parent
      } catch {
         Write-Host "$_.Exception.Message" @red
         Show-Balloon -Message "Error path opera-proxy" -MessageType "Error"
         return $false
      }

      if (-not [IO.Directory]::Exists($dirproxy)) {
         [IO.Directory]::CreateDirectory($dirproxy) | Out-Null
         Write-Host "Create folder $($dirproxy): OK" @green
      }
      if (Download-File -Source $urlproxy -Dest $ProxyPath) {
         Write-Host "Proxy v$lastproxy download: OK" @green
         return $true
      }
   }

   return $false
}

# Настройка ini для version.dll
Function Check-IniFile ([string]$Dlldescr) {
    Write-Host "Check-IniFile..."
    if ($Dlldescr -like "chrome++*") {
        $Script:baseini = 'chrome++.ini'; $ini = Join-Path $AppPath $baseini
        $sect = @('[general]')
        $keys = @{'data_dir'=$ConfigData;'cache_dir'=$ConfigCache}
        $enc = New-Object Text.UnicodeEncoding
    } else {
        $Script:baseini = 'config.ini'; $ini = Join-Path $AppPath $baseini
        $sect = @('[dir_setting]')
        $keys = @{'data'=$ConfigData;'cache'=$ConfigCache}
        $enc = New-Object Text.UTF8Encoding($false)
    }
    try {
        $lines = if ([IO.File]::Exists($ini)) {
           Get-Content -LiteralPath $ini -Encoding $($enc.EncodingName -replace '.+UTF-8.+','UTF8')
        }
        if ($lines -notcontains $sect) {
           $lines = $sect+@($lines)
           $changed = $true
        }
        foreach ($k in $keys.Keys) {
           if ($lines -notcontains "$k=$($keys[$k])") {
              $lines = $lines | ForEach-Object {
                 if ($_ -eq $sect) {
                    $_; "$k=$($keys[$k])"
                 } else {
                    if ($_ -notlike "$k=*") {$_}
                 }
              }
              $changed = $true
           }
        }
        if ($changed) {
           [IO.File]::WriteAllLines($ini,$lines,$enc)
           Write-Host "File $baseini tuned: OK" @green
           return $true
        }
    } catch {
        throw "$_.Exception.Message"
    }
}

# Удаление хлама после закрытия браузера
Function Delete-Traces {
   $list = @($DelDirs+$DelFiles | ForEach-Object {
      Get-Item -Path "$profilePath\$_","$cachePath\$_" -ErrorAction SilentlyContinue
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
if ($UseProxy) {Write-Host  "Proxy:     $ProxyPath"   @darkcyan}
Write-Host                  "Profile:   $profilePath" @darkcyan
if ($cachePath) {Write-Host "Cache:     $cachePath"   @darkcyan}
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
if ($DllPath) {Write-Host   "Dll:       $DllPath"     @darkcyan}
Write-Host                  "Mutex:     $MutexName"   @darkcyan

try {

   if (-not $lastcheck) {$lastcheck='18032026'}
   $daysCheck = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   # Условия проверки обновлений: спец. режим запуска, превышение заданного интервала, отсутствие исполняемого файла
   if ($RunMode -eq 2 -or ($daysCheck -ge [int]$CheckInterval -and $RunMode -ne 1) -or -not [IO.File]::Exists("$AppPath\$ExeName")) {

      if ($UseProxy -eq 2) {
         if (Get-Proxy) {
            $proxypid = (Start-Process -FilePath $ProxyPath -ArgumentList $ProxyArg -NoNewWindow -PassThru).id
            if ($proxypid) {Write-Host "Proxy ID $proxypid start: OK" @green}
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy ($('http://'+($ProxyArg -Split " ")[1]), $true)
         } else {
            throw 'Error run proxy'
         }
      }

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

   # Наличие version.dll
   try {
      $dllInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\version.dll").FileDescription
      if (-not $dllInfo) {throw}
   } catch {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed version.dll" -MessageType "Error"
      }
      throw 'Missed version.dll'
   }

   # Создание нового профиля
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

   # Настройка ini
   try {if (-not (Check-IniFile -Dlldescr $dllInfo)) {Write-Host "Not changed $baseini"}}
   catch {throw "Error tuned $($baseini): $_"}

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

   # Фильтр пустого Switches
   if ($Switches.Count -eq 0) {$Switches = @('--no-first-run')}

   # Запуск прокси
   if (Get-Proxy) {
      if (-not $proxypid) {
         try {
            $proxypid = (Start-Process -FilePath $ProxyPath -ArgumentList $ProxyArg -NoNewWindow -PassThru).id
            if ($proxypid) {Write-Host "Proxy ID $proxypid start: OK" @green}
         } catch {
            Write-Host "$_.Exception.Message" @red
            $proxypid = $null
         }
      }
   }
   if (-not $proxypid) {$Switches = @($Switches | Where-Object {$_ -notlike "--proxy-server=*"})}


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

      if ($proxypid) {
         if (-not (Get-Process -Id $proxypid -ErrorAction SilentlyContinue)) {
            try {
               Write-Host "Proxy ID $proxypid is interrupted, try again run..." @red
               $proxypid = (Start-Process -FilePath $ProxyPath -ArgumentList $ProxyArg -NoNewWindow -PassThru).id
               if ($proxypid) {Write-Host "Proxy ID $proxypid start: OK" @green}
            } catch {$proxypid = $null}
         }
      }

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

   if ($proxypid) {
      Write-Host "Kill proxy..."
      try {
         Stop-Process -Id $proxypid -Force -ErrorAction Stop
         Write-Host "Proxy ID $proxypid kill: OK" @green
      } catch {
         Write-Host "$_.Exception.Message" @red
      }
   }

   Exit-SingleInstance
   if ($ShowConsole) {timeout /t -1}
}
