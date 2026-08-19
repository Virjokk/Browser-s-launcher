<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера MSEdge и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления при их выходе качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию (Stable, Beta, Dev, Canary) и разрядность (x64/x86), указав нужное значение в $Edition и $Bitness.
:: Портабельность обеспечивает version.dll от ca-x (https://github.com/ca-x/vivaldi_plus/) или
:: от Bush2021 (https://github.com/Bush2021/chrome_plus) по выбору, настраиваемому в переменной $VersionDll.
:: Конфиги version.dll настраиваются здесь же, в переменных $ConfigData,$ConfigCache в части имени и расположения папок профиля
:: и кэша, поэтому прописывать их напрямую в chrome++.ini/config.ini смысла нет.
:: Для работы version.dll делается инжект в файл msedge.exe с помощью setdll (https://github.com/Bush2021/setdll).
:: Если папка профиля существует и указан путь к ней в $ConfigData, то браузер запустится с этим профилем.
:: Если нет, то создается новый с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=2&bm=1&topic=5915&start=60#14).
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
$Edition = 0 # 0 - Stable, 1 - Beta, 2 - Dev, 3 - Canary
$Bitness = "x64" # для 32bit-версии указать "x86"
$VersionDll = 0 # 0 - библиотека dll от Bush2021, 1 - от ca-x (czyt.tech)
$AppDir = "App" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$DllPath = "" # локальный путь к windows_x86/x64.zip, если оставить пустым, будет скачан с github.com
$SetDllPath = "" # локальный путь к setdll.7z, если оставить пустым, будет скачан с github.com
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # ключи запуска браузера
   "--no-default-browser-check"
   "--no-first-run"
   "--disable-breakpad"
   "--disable-crash-reporter"
   "--disable-logging"
#   "--disable-component-update" # раскомментировать этот и следующий ключи для запрета автообновления расширений
#   "--disable-background-networking"
#   "--force-device-scale-factor=1.25"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
   "--show-component-extension-options"
   "--disable-features=PrintCompositorLPAC"
   "--allow-legacy-mv2-extensions"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
   "--disable-features=msFeatureGroupNewLookAndFeelHoldout"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
   "ActorSafetyLists"
   "Ad Blocking"
   "AmountExtractionHeuristicRegexes"
   "Autofill*"
   "AutoLaunchProtocolsComponent"
   "BrowserMetrics*"
   "Cache"
   "CertificateRevocation"
   "component_crx_cache"
   "CookieReadinessList"
   "Crashpad"
   "DawnCache"
   "DawnGraphiteCache"
   "DawnWebGPUCache"
   "Domain Actions"
   "EADPData Component"
   "Edge *"
   "extensions_crx_cache"
   "FirstPartySetsPreloaded"
   "GPUCache"
   "GPUPersistentCache"
   "GraphiteDawnCache"
   "GrShaderCache"
   "hyphen-data"
   "MEIPreload"
   "Nurturing"
   "OpenCookieDatabase"
   "OriginTrials"
   "PKIMetadata"
   "ProbabilisticRevealTokenRegistry"
   "Provenance*"
   "RecoveryImproved"
   "SafetyTips"
   "Safe Browsing*"
   "ShaderCache"
   "SmartScreen"
   "Speech Recognition"
   "Subresource Filter"
   "SwiftShader"
   "SwReporter"
   "Trust Protection Lists"
   "TrustTokenKeyCommitments"
   "Typosquatting"
   "VisualCompanion"
   "Webstore Downloads"
   "Web Notifications Deny List"
   "Well Known Domains"
   "WidevineCDM"
   "WorkspacesNavigationComponent"
   "ZxcvbnData"
   "Default\Asset Store"
   "Default\AutofillAiModelCache"
   "Default\AutofillStrikeDatabase"
   "Default\blob_storage"
   "Default\BudgetDatabase"
   "Default\Cache"
   "Default\ClientCertificates"
   "Default\Collections"
   "Default\commerce_subscription_db"
   "Default\Continuous Migration"
   "Default\DawnGraphiteCache"
   "Default\DawnWebGPUCache"
   "Default\discount*"
   "Default\Download Service"
   "Default\DualEngine"
   "Default\EdgeCoupons"
   "Default\EdgeEDrop"
   "Default\EdgeHubAppUsage"
   "Default\EdgeJourneys"
   "Default\EdgePushStorageWithConnectTokenAndKey"
   "Default\EdgeWallet"
   "Default\EntityExtraction"
   "Default\Feature Engagement Tracker"
   "Default\GPUCache"
   "Default\GraphiteDawnCache"
   "Default\GrShaderCache"
   "Default\JumpListIcons*"
   "Default\Nurturing"
   "Default\optimization_guide*"
   "Default\parcel_tracking_db"
   "Default\pdf*"
   "Default\PersistentOriginTrials"
   "Default\Platform Notifications"
   "Default\Safe Browsing*"
   "Default\Segmentation Platform"
   "Default\Service Worker\Cache*"
   "Default\ShaderCache"
   "Default\Site Characteristics Database"
   "Default\Sync App Settings"
   "Default\VideoDecodeStats"
   "Default\Workspaces"
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
   "*.db*"
   "*.json"
   "*.tmp"
   "BrowserMetrics*"
   "CrashpadMetrics*"
   "edge_shutdown_ms*"
   "FirstLaunchAfterInstallation"
   "RevisitationBloomfilter"
   "Safe Browsing *"
   "Variations"
   "Default\*.bak"
   "Default\*.json"
   "Default\*.old"
   "Default\*.tmp"
   "Default\BookmarkMergedSurfaceOrdering"
   "Default\BrowsingTopic*"
   "Default\DashTrackerDatabase"
   "Default\DIPS*"
   "Default\ExtensionActivity*"
   "Default\favorites_diagnostic.log"
   "Default\heavy_ad_intervention_opt_out.db*"
   "Default\HubApps*"
   "Default\InterestGroups"
   "Default\load_statistics.db*"
   "Default\MediaDeviceSalts"
   "Default\Network\Reporting and NEL"
   "Default\Network\SCT Auditing Pending Reports"
   "Default\Network\Sdch Dictionaries"
   "Default\PreferredApps"
   "Default\PrivateAggregation"
   "Default\Reporting and NEL"
   "Default\SCT Auditing Pending Reports"
   "Default\Sdch Dictionaries"
   "Default\Shared*"
   "Default\SiteList.xml"
   "Default\uu_host_config"
   "Default\WebAssistDatabase"
#  Работа браузера во многом ломается, раскомментируйте, если приватность важнее потери данных
#   "*-journal"
#   "Last *"
#   "Default\*.db"
#   "Default\*.ldb"
#   "Default\*-journal"
#   "Default\Affiliation Database"
#   "Default\Device Bound Sessions"
#   "Default\Extension State\*.log"
#   "Default\Extension State\*.ldb"
#   "Default\File System\Origins\*.log"
#   "Default\Last Session*"
#   "Default\Last Tabs*"
#   "Default\Login Data For Account"
#   "Default\Local Storage\leveldb\*.ldb"
#   "Default\LOCK*"
#   "Default\log"
#   "Default\log.old"
#   "Default\MANIFEST-*"
#   "Default\Network *"
#   "Default\Network\*-journal"
#   "Default\Network\Network*"
#   "Default\Network\Trust Tokens"
#   "Default\Network\TransportSecurity"
#   "Default\ServerCertificate"
#   "Default\Session Storage\*"
#   "Default\TransportSecurity"
#   "Default\trust*"
#   "Default\Shortcuts"
#   "Default\Top Sites*"
#   "Default\Visited Links*"
#   "Default\Vpn Tokens*"
#   "Default\WebStorage\*-journal"
#   "Default\WebStorage\QuotaManager*"
)

$DelReg = @( # данные реестра, удаляемые после закрытия браузера
   "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Edge"
   "HKEY_CURRENT_USER\SOFTWARE\Microsoft\EdgeUpdate"
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
   "AdSelectionAttestationsPreloaded"
   "BHO"
   "Dictionaries"
   "EBWebView"
   "edge_feedback"
   "edge_game_assist"
   "identity_proxy"
   "Installer"
   "MEIPreload"
   "PdfPreview"
   "Trust Protection Lists"
   "WidevineCdm"
   "VisualElements"
   "concrt140.dll"
   "cookie_exporter.exe"
   "Copilot.dat"
   "copilot*.pak"
   "delegatedWebFeatures.sccd"
   "dual_engine_adapter_x64.dll"
   "dual_engine_adapter_x86.dll"
   "dxcompiler.dll"
   "dxil.dll"
   "Edge.dat"
   "EdgeWebView.dat"
   "elevated_tracing_service.exe"
   "elevation_service.exe"
   "eventlog_provider.dll"
   "identity_helper.exe"
#   "learning_tools.dll"
   "microsoft_shell_integration.dll"
   "mip_core.dll"
   "mip_core_gn.dll"
   "mip_protection_sdk.dll"
   "mscopilot.exe"
   "msedge.dll.sig"
   "msedge.exe.sig"
   "msedge_proxy.exe"
   "msedge_pwa_launcher.exe"
   "msedge_wer.dll"
   "msedgewebview2.exe"
   "msedgewebview2.exe.sig"
   "msvcp140.dll"
   "msvcp140_codecvt_ids.dll"
   "notification_helper.exe"
   "oneauth.dll"
   "oneds.dll"
   "onnxruntime.dll"
   "onramp.dll"
   "prefs_enclave_x64.dll"
   "pwahelper.exe"
   "show_third_party_software_licenses.bat"
   "telclient.dll"
   "textInputMethod.sccd"
   "uc_connector.exe"
   "vccorlib140.dll"
   "vcruntime140.dll"
   "vcruntime140_1.dll"
   "wdag.dll"
   "webview2_integration.dll"
   "wns_push_client.dll"
   "Locales\*FEMININE.pak"
   "Locales\*MASCULINE.pak"
   "Locales\*NEUTER.pak"
   "Locales\copilot*.pak"
   "Locales\af.pak"
   "Locales\am.pak"
   "Locales\ar.pak"
   "Locales\as.pak"
   "Locales\az.pak"
   "Locales\bg.pak"
   "Locales\bn-IN.pak"
   "Locales\bs.pak"
   "Locales\ca.pak"
   "Locales\ca-Es-VALENCIA.pak"
   "Locales\cs.pak"
   "Locales\cy.pak"
   "Locales\da.pak"
   "Locales\de.pak"
   "Locales\el.pak"
   "Locales\en-GB.pak"
   "Locales\es.pak"
   "Locales\es-419.pak"
   "Locales\et.pak"
   "Locales\eu.pak"
   "Locales\fa.pak"
   "Locales\fi.pak"
   "Locales\fil.pak"
   "Locales\fr.pak"
   "Locales\fr-CA.pak"
   "Locales\ga.pak"
   "Locales\gd.pak"
   "Locales\gl.pak"
   "Locales\gu.pak"
   "Locales\he.pak"
   "Locales\hi.pak"
   "Locales\hr.pak"
   "Locales\hu.pak"
   "Locales\id.pak"
   "Locales\is.pak"
   "Locales\it.pak"
   "Locales\ja.pak"
   "Locales\ka.pak"
   "Locales\kk.pak"
   "Locales\km.pak"
   "Locales\kn.pak"
   "Locales\ko.pak"
   "Locales\kok.pak"
   "Locales\lb.pak"
   "Locales\lo.pak"
   "Locales\lt.pak"
   "Locales\lv.pak"
   "Locales\mi.pak"
   "Locales\mk.pak"
   "Locales\ml.pak"
   "Locales\mr.pak"
   "Locales\ms.pak"
   "Locales\mt.pak"
   "Locales\nb.pak"
   "Locales\ne.pak"
   "Locales\nl.pak"
   "Locales\nn.pak"
   "Locales\or.pak"
   "Locales\pa.pak"
   "Locales\pl.pak"
   "Locales\pt-BR.pak"
   "Locales\pt-PT.pak"
   "Locales\qu.pak"
   "Locales\ro.pak"
   "Locales\sk.pak"
   "Locales\sl.pak"
   "Locales\sq.pak"
   "Locales\sr.pak"
   "Locales\sr-Cyrl-BA.pak"
   "Locales\sr-Latn-RS.pak"
   "Locales\sv.pak"
   "Locales\ta.pak"
   "Locales\te.pak"
   "Locales\th.pak"
   "Locales\tr.pak"
   "Locales\tt.pak"
   "Locales\ug.pak"
   "Locales\uk.pak"
   "Locales\ur.pak"
   "Locales\vi.pak"
   "Locales\zh-CN.pak"
   "Locales\zh-TW.pak"
)

$Trash = @( # папки и файлы вне профиля, удаляемые после закрытия браузера
   "$env:AppData\Edge*"
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

if ($Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = $(switch ($Edition) {
   1 {'MSEdge Beta'; $product = 'Beta'}
   2 {'MSEdge Dev'; $product = 'Dev'}
   3 {'MSEdge Canary'; $product = 'Canary'}
   default {'MSEdge'; $product = 'Stable'}
})+" $Bitness"

$ExeName = 'msedge.exe'

if (-not $ConfigData) {$ConfigData = "%app%\..\Profile"}
$profilePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $($ConfigData -replace '%app%','.')))

if ($ConfigCache -ne 'nul') {
   if (-not $ConfigCache) {$ConfigCache = "%app%\..\Cache"}
   $cachePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $($ConfigCache -replace '%app%','.')))
}

if ($VersionDll -eq 0) {
   $DllPath = $SetDllPath
} elseif ($DllPath -and "$(Split-Path -Parent $DllPath)\windows_$Bitness.zip" -ne $DllPath) {
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
$Script:MutexName = "Global\MSEdgePortable$($scriptName -replace '[\\:]','_')"

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
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1HgAnNN5BPTTeQP/'
      'zHYF/7tqCP+tYwv/o10S+ZJOD50AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADU'
      'eAA81HgA9tR5Af/SeAP/qV0K/5RQDP+QTQ3/kE4N/5JOD/+STg//kE0Q9o9M'
      'EDwAAAAAAAAAAAAAAADUeAA81HgA/tR5Af/VewL/p10K/5RQDP+STwz/lVEO'
      '/5hSDv+WUA//lE8P/5FOEP+PTBD+jUsRPAAAAAAAAAAA1HgA9tR5Af/VewL/'
      'xHAF/5VQDP+UUAz/llEM/5pTDv+YUg77llAP3JRPD8CRThDvj0wQ+41LEfYA'
      'AAAA1HgAnNV5Af/VewL/1nwD/7dpB/+WUQz/lFAM/5xUDf6aUw6cAAAAAAAA'
      'AAAAAAAAAAAAAAAAAACNSxFXAAAAANV5Ae/VewL/1n0D/9d/Bf+tYwr/llEM'
      '/5dSDP6dVQ1XAAAAAIW+NjyGvzevacE/51fDRe9NyEyvQM5UPAAAAADVewL/'
      '1n0E/9d/Bf/XgQf/u24J/5RQDP+ZUw3CAAAAAAAAAACavzPniL83/4DCO/9m'
      'w0L/UM1Q/0XRVv461FtX1X0E/9d/Bf/XgQf/2IQI/9aDCv+TUAv/mFINcwAA'
      'AAAAAAAAm78znJLBN/+Nxjz/Z8pI/2PRT/9S11n/QNdd79uMD//WgAf/2IQJ'
      '/9mGCv/aiQz/wHUO/4tLC8cAAAAAAAAAAMWxN92XxDj/jck//4XORf9v1E//'
      'VdZX/0zdX//fnB3/0X8J/9mHC//biQ3/3IwP/92PEf/OhRP/0o4fodyXGMHI'
      'rCT/pcc3/5HLQP+H00r/b9RP/2LgXf9M5Gb/6q8s/cWDEP/Vhg3/24wP/92P'
      'Ef/ekhP/35YW/92XGP/JlRv/0cIq/7/EMP+qyzv/jtVK/4DcU/9o4V3/WOZl'
      '//e8MJzzvTD/15we/8mHE//QiRL/0YsV/8eOGP/NpyH/0cIq/9HCKv/BxzL/'
      'tM08/5rUR/+M21D/aetn/1rubdwAAAAA9r0x9vO+Mv/svzD/58Aw/+DBLv/X'
      'wSv/0sIq/9HCKv/LxzH/vsw4/6rUQ/+a203/fuZe/23qZf9h7208AAAAAPi+'
      'MzzzvjL+778y/+jAMf/hwS//28It/9bELv/SxC3/z8Yw/8bKNv+r1kb/qdlJ'
      '/4jmXf926mScAAAAAAAAAAAAAAAA+L40PPW/NPbwwDT/5cEx/97DMf/WxC7/'
      '0sYw/8/GMP/DzTr/utJA/6TbTP6W4lacAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAA8sA1nOvCNO/lwjP/18Yy/9XHNP/OzDn/wtE/9rbVRMCp20wfAAAAAAAA'
      'AAAAAAAA8A8AAMADAACAAQAAgAEAAAB9AAAAgQAAAYAAAAGAAAABgAAAAAAA'
      'AAAAAAAAAAAAgAAAAIABAADAAwAA8AcAAA=='
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
Function Make-NetRequest ([string]$Url,[string]$Method,[int]$Timeout=10) {

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
            $task = if ($Method -eq 'POST') {
               $httpClient.PostAsync($uri,$null)
            } else {
               $httpClient.GetAsync($uri,'ResponseHeadersRead')
            }
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

# Получение номера версии
Function Get-LatestVersion {
   if (-not (Test-DNS)) {$Script:checkError = $true; return $false}
   Write-Host "Get-LatestVersion..."

   $api = 'https://edgeupdates.microsoft.com/api/products'
   Write-Host "Request GET:  $api"

   try {
      $jsonProducts = (Make-NetRequest -Url $api).Content.ReadAsStringAsync().Result | ConvertFrom-Json
      $Script:latest = (
         ($jsonProducts | Where-Object Product -eq $product).releases |
         Where-Object Platform -eq 'Windows' | Where-Object Architecture -eq $Bitness
      ).ProductVersion | %{[version]$_} | Sort-Object | Select-Object -Last 1
      if (-not $latest) {throw 'latest is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   Write-Host "Latest:       v$latest"
   return $true
}

# Сравнение версий, ссылка на загрузку
Function Check-NewVersion {
   if (-not (Get-LatestVersion)) {return $false}

   Set-FileVar -Name "lastcheck" -Value $(Get-Date -Format 'ddMMyyyy')

   try {
      $Script:current = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\$ExeName").FileVersionRaw
   } catch {
      $Script:current = $null
   }

   if ($latest -le $current) {
      Write-Host "Installed:    v$current - no update required"
      return $false
   } elseif ($current -ne $null) {
      Write-Host "Installed:    v$current - update is available"
   } else {
      Write-Host "New install"
   }

   $url = 'https://msedge.api.cdp.microsoft.com/api/v1.1/internal/contents/Browser/namespaces/Default/names/'
   $url = $url+'msedge-'+$product+'-win-'+$Bitness+'/versions/'+$latest+'/files?action=GenerateDownloadInfo&foregroundPriority=true'

   Write-Host "Request POST: $url"
   try {
      $jsonLinks = (Make-NetRequest -Url $url -Method POST).Content.ReadAsStringAsync().Result | ConvertFrom-Json
      $Script:distrLink = ($jsonLinks | Where-Object FileId -eq "MicrosoftEdge_$($Bitness)_$($latest).exe").Url
      if (-not $distrLink) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error parsing link to download" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }
   Write-Host "Link:         $distrLink"

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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\edge.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      # setdll.7z
      if (-not [IO.File]::Exists("$SetDllPath")) {
          $SetDllPath = "$tmpdir\setdll.7z"
          $setdllUrl = "https://github.com/Bush2021/chrome_plus/releases/latest/download/setdll.7z"
          if (-not (Download-File -Source $setdllUrl -Dest $SetDllPath)) {throw}
          Write-Host "Download setdll.7z: OK" @green
      }

      # windows_x86/x64.zip
      if (-not [IO.File]::Exists("$DllPath")) {
         if ($VersionDll -eq 0) {
            $DllPath = $SetDllPath
         } else {
            $DllPath = "$tmpdir\version.zip"
            $dllUrl = "https://github.com/ca-x/vivaldi_plus/releases/latest/download/windows_$Bitness.zip"
            if (-not (Download-File -Source $dllUrl -Dest $DllPath)) {throw}
            Write-Host "Download windows_$Bitness.zip: OK" @green
         }
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
      &($7zpath) e -aoa "$tmpdir\edge.exe" "MSEDGE.7z" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      &($7zpath) x -t7z -aoa "$tmpdir\MSEDGE.7z" "Chrome-bin\" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack MSEDGE.7z" -MessageType "Error"
         throw 'Error unpack MSEDGE.7z'
      }
      Write-Host "Unpack MSEDGE.7z: OK" @green

      &($7zpath) e -t7z -aoa "$SetDllPath" $("setdll-"+$Bitness+".exe") -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack setdll.7z" -MessageType "Error"
         throw 'Error unpack setdll.7z'
      }
      Write-Host "Unpack setdll.7z: OK" @green

      $dirver = (Get-ChildItem -Path "$tmpdir\Chrome-bin\*.*.*.*" -Directory -ea 0).Name
      if (-not $dirver) {
         Show-Balloon -Message "Error in defining the directory structure" -MessageType "Error"
         throw 'Not detect directory number version'
      }

      if ($VersionDll -eq 0) {
         &($7zpath) e -t7z -aoa "$DllPath" $("version-"+$Bitness+".dll") -o"$tmpdir" | Out-Null
         if ($LASTEXITCODE -ne 0) {
            Show-Balloon -Message "Error unpack setdll.7z" -MessageType "Error"
            throw 'Error unpack setdll.7z'
         }
         Write-Host "Unpack setdll.7z: OK" @green
         Move-Item -Path "$tmpdir\$("version-"+$Bitness+".dll")" -Destination "$tmpdir\Chrome-bin\$dirver\version.dll" -Force -ea 0
      } else {
         try {
            Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DllPath, "$tmpdir\Chrome-bin\$dirver")
            Write-Host "Unpack windows_$Bitness.zip: OK" @green
         } catch {
            Show-Balloon -Message "Error unpack windows_$Bitness.zip" -MessageType "Error"
            throw $_
         }
      }

      # Инжект
      $setdll = $tmpdir+'\setdll-'+$Bitness+'.exe'
      $setdllarg = '/d:version.dll',$ExeName
      Start-Process -FilePath $setdll -ArgumentList $setdllarg -NoNewWindow -WorkingDirectory "$tmpdir\Chrome-bin\$dirver" -Wait -ea 1
      if ([IO.File]::Exists("$tmpdir\Chrome-bin\$dirver\$ExeName#")) {
         Show-Balloon -Message "Error inject version.dll" -MessageType "Error"
         throw 'Error inject version.dll'
      }
      Write-Host "Inject version.dll: OK" @green

      # Список файлов для сохранения
      $nodel = @(
         "$($profilePath.split('\')[-1])"
         "$((($profilePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
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

      $excludeList = $SetupExclude + @(
         "$ExeName~"
         'config.ini.example'
         'config.ini.example.zh-CN'
      )

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\Chrome-bin\$dirver\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\Chrome-bin\$dirver\*" -Destination $AppPath -Recurse -Force
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
     '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":["edge-autoplay-user-setting-block-o'
     'ption@1","ignore-gpu-blocklist","smooth-scrolling@2"]},"edge":{"perf_center":{"efficiency_mode_v2_is_active":fa'
     'lse,"perf_game_mode":true,"performance_mode":0,"performance_mode_is_on":true,"performance_mode_toggled":true}},'
     '"experimentation_and_configuration_service_control":2,"fire_local_softlanding_notification":false,"fre":{"has_u'
     'ser_committed_selection_to_import_during_fre":false,"has_user_completed_fre":true,"has_user_seen_fre":true,"oem'
     '_bookmarks_set":true,"screens":["Microsoft.NewProfileFRE.ScreenId.SyncSignin"],"soft_landing_bubble":{"bubble_r'
     'esponse":0,"has_user_seen_bubble":true,"is_bubble_triggered":0}},"hardware_acceleration_mode_previous":true,"is'
     '_dsp_recommended":false,"phoenix":{"rounded_frame_enabled":false},"profile":{"info_cache":{"Default":{"avatar_i'
     'con":"chrome://theme/IDR_PROFILE_AVATAR_20","background_apps":false,"edge_account_first_name":"","edge_account_'
     'last_name":"","edge_account_oid":"","edge_account_tenant_id":"","edge_account_type":0,"edge_kids_mode":false,"e'
     'dge_test_on_premises":false,"edge_wam_aad_for_app_account_type":0,"force_signin_profile_locked":false,"gaia_giv'
     'en_name":"","gaia_id":"","gaia_name":"","hosted_domain":"","is_consented_primary_account":false,"is_ephemeral":'
     'false,"is_omitted_from_profile_list":false,"is_using_default_avatar":true,"is_using_default_name":true,"local_a'
     'uth_credentials":"","managed_user_id":"","metrics_bucket_index":1,"name":"Default","shortcut_name":"Profile 1",'
     '"signin.with_credential_provider":false,"user_name":""}},"last_active_profiles":[],"metrics":{"next_bucket_inde'
     'x":2}},"profile_network_context_service":{"http_cache_finch_experiment_groups":"None None None"},"site_safety_s'
     'ervices":{"enabled":false},"smartscreen":{"enabled":true,"pua_protection_enabled":false},"startup_boost":{"defa'
     'ult_last_launch":true,"enabled":false},"subresource_filter":{"ruleset_version":{"checksum":0,"content":"","form'
     'at":0}}}'
   ) -join ''

   $preferencesContent = @(
     '{"alternate_error_pages":{"backup":true,"enabled":false},"autocomplete":{"retention_policy_last_version":114},"'
     'autofill":{"autostuff_enabled":false,"credit_card_enabled":false,"custom_data_enabled":false,"orphan_rows_remov'
     'ed":true,"profile_enabled":false},"bookmark_bar":{"show_on_all_tabs":false,"show_only_on_ntp":true},"browser":{'
     '"available_dark_theme_options":"All","clear_data":{"download_history":true,"edge_uwp_browsing_data":true,"form_'
     'data":true,"mf_protected_media_data":true,"on_exit_succeeded":true,"passwords":true,"site_settings":true,"time_'
     'period":4},"clear_data_on_exit":{"cache":true,"download_history":true,"form_data":true,"hosted_apps_data":false'
     ',"passwords":false},"enable_text_prediction_v2":false,"has_seen_welcome_page":false,"should_reset_check_default'
     '_browser":false,"show_discover_toolbar_button":false,"show_hub_app_in_sidebar_buttons":{"0c835d2d-9592-4c7a-8d0'
     'a-0e283c9ad3cd":3,"2354565a-f412-4654-b89c-f92eaa9dbd20":0,"523b5ef3-0b10-4154-8b62-10b2ebd00921":3,"64be4f9b-3'
     'b81-4b6e-b354-0ba00d6ba485":3,"8682d0fa-50b3-4ece-aa5b-e0b33f9919e2":3,"8ac719c5-140b-4bf2-a0b7-c71617f1f377":3'
     ',"92f1b743-e26b-433b-a1ec-912d1f0ad1fa":3,"96defd79-4015-4a32-bd09-794ff72183ef":3,"9ce3c9c2-462f-4cc9-bbd7-57d'
     '656445be0":3,"cd4688a9-e888-48ea-ad81-76193d56b1be":0},"show_hub_apps_tower":false,"show_hub_popup_on_download_'
     'start":true,"show_hubapps_personalization":false,"show_sidebar_notification":false,"show_sidebar_notification_p'
     'referred":false,"show_tab_preview":false,"show_text_in_pill":false,"show_toolbar_bookmarks_button":false,"show_'
     'toolbar_browser_essentials_button":0,"show_toolbar_citations_button":false,"show_toolbar_collections_button":fa'
     'lse,"show_toolbar_downloads_button":true,"show_toolbar_performance_button":0,"show_toolbar_share_button":false,'
     '"show_toolbar_vertical_tabs_button":false,"toolbar_browser_essentials_button_pinned":false,"toolbar_extensions_'
     'hub_button_visibility":0,"underside_chat_bing_signed_in_status":false,"window_placement":{"bottom":640,"left":3'
     '2,"maximized":true,"right":1024,"top":32}},"browser_essentials":{"show_hub_fre":false,"show_safety_fre":false},'
     '"caretbrowsing":{"enabled":false},"collections":{"fre_seen":true},"credentials_enable_autofill_passwords":false'
     ',"credentials_enable_autosignin":false,"credentials_enable_service":false,"download":{"allow_office_viewer_for_'
     'download":false,"default_directory":"C:\\Downloads","directory_upgrade":true,"prompt_for_download":true},"dual_'
     'engine":{"shared_cookie_data":{},"sitelist_data":{},"sitelist_location":"","sitelist_version":""},"edge":{"show'
     '_minimised_pip_overlay":true,"vertical_tabs":{"feedback_do_not_show":true,"first_opened2":true,"hide_titlebar":'
     'false,"opened":false}},"edge_enhance_images_enabled":false,"edge_follow_enabled":false,"edge_follow_notificatio'
     'n_enabled":false,"edge_quick_search":{"show_mini_menu":false,"show_smart_actions_in_full_menu":true},"edge_rewa'
     'rds":{"opened_via_prototocol_launch":false,"show":false},"edge_shopping_assistant_enabled":false,"edge_tab_serv'
     'ices_enabled":false,"edge_underside_triggering_enabled":false,"extensions":{"ui":{"developer_mode":true}},"fami'
     'ly_safety":{"activity_reporting_enabled":false,"web_filtering_enabled":false},"localsuggest":{"enabled":false},'
     '"media":{"edge_autoplay_behavior":2,"engagement":{"schema_version":4}},"ntp":{"background_image_type":"off","en'
     'able_prerender":false,"hide_default_top_sites":true,"layout_mode":3,"news_feed_display":"off","num_personal_sug'
     'gestions":1,"quick_links_options":0,"show_greeting":false,"show_image_of_day":false,"show_settings":false,"show'
     '_top_sites":false,"user_nurturing":[{"key":"campaigns","value":[]},{"key":"meta","value":{"campaignsDataMigrati'
     'onDoneTs":1613484653685}}]},"payments":{"can_make_payment_enabled":false},"previews":{"litepage":{"user-needs-n'
     'otification":false},"offline_helper":{"available_pages":{}}},"profile":{"avatar_bubble_tutorial_shown":2,"avata'
     'r_index":20,"content_settings":{"exceptions":{},"pref_version":1},"exit_type":"Normal","exited_cleanly":true,"h'
     'as_seen_signin_fre":true,"icon_version":15,"managed_user_id":"","name":"1","password_manager_onboarding_state":'
     '1,"were_old_google_logins_removed":true},"reset_prepopulated_engines":false,"signin":{"DiceMigrationComplete":t'
     'rue,"allowed":true},"translate":{"enabled":false},"try_collections_first_time":true,"unified_consent":{"migrati'
     'on_state":10},"user_experience_metrics":{"personalization_data_consent_enabled":false,"personalization_data_con'
     'sent_enabled_last_known_value":false}}'
   ) -join ''

   try {
      [IO.Directory]::CreateDirectory("$profilePath\Default") | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])\Default"

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

Write-Host                   "Initialize variables..."
Write-Host                   "Script:       $scriptName"  @darkcyan
Write-Host                   "App:          $AppPath"     @darkcyan
Write-Host                   "Browser:      $BrowserName" @darkcyan
Write-Host                   "Profile:      $profilePath" @darkcyan
if ($cachePath) {Write-Host  "Cache:        $cachePath"   @darkcyan}
if ($7zpath) {Write-Host     "7z:           $7zpath"      @darkcyan}
if ($DllPath) {Write-Host    "Dll:          $DllPath"     @darkcyan}
if ($SetDllPath) {Write-Host "SetDll:       $SetDllPath"  @darkcyan}
Write-Host                   "Mutex:        $MutexName"   @darkcyan

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
