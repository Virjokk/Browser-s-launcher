<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Chromium-Gost и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать разрядность браузера (x64/x86), указав нужное значение в $Bitness.
:: Портабельность обеспечивает version.dll от ca-x (https://github.com/ca-x/vivaldi_plus/) или
:: от Bush2021 (https://github.com/Bush2021/chrome_plus) по выбору, настраиваемому в переменной $versiondll.
:: Конфиги version.dll настраиваются здесь же, в переменных $ConfigData,$ConfigCache в части имени и расположения папок профиля
:: и кэша, поэтому прописывать их напрямую в chrome++.ini/config.ini смысла нет.
:: Для проверки/скачивания обновлений и для браузера можно использовать opera-proxy (https://github.com/Alexey71/opera-proxy),
:: который будет скачан и запущен с заданными параметрами, при выходе новых версий будет автообновляться.
:: Если указать путь к своему профилю в $ConfigData, то подхватится он. Иначе создается новый с минимальным Local State.
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
$Bitness = "x64" # для 32bit-версии указать "x86"
$VersionDll = 0 # 0 - библиотека dll от Bush2021, 1 - от ca-x (czyt.tech)
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
   "--show-component-extension-options"
#   "--disable-component-update" # раскомментировать этот и следующий ключи для запрета автообновления расширений
#   "--disable-background-networking"
   "--proxy-server=$(($ProxyArg -Split " ")[1])"
   "--disable-features=PrintCompositorLPAC"
   "--allow-legacy-mv2-extensions"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
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
#   "Default\AccountBookmarks"
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
   "HKEY_CURRENT_USER\SOFTWARE\Chromium"
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
   "IwaKeyDistribution"
   "MEIPreload"
   "PrivacySandboxAttestationsPreloaded"
   "VisualElements"
   "chrome_proxy.exe"
   "chrome_pwa_launcher.exe"
   "chrome_wer.dll"
   "dxcompiler.dll"
   "dxil.dll"
   "eventlog_provider.dll"
   "notification_helper.exe"
   "Locales\*FEMININE.pak"
   "Locales\*MASCULINE.pak"
   "Locales\*NEUTER.pak"
   "Locales\af.pak"
   "Locales\am.pak"
   "Locales\ar.pak"
   "Locales\as.pak"
   "Locales\az.pak"
   "Locales\be.pak"
   "Locales\bg.pak"
   "Locales\bn.pak"
   "Locales\bs.pak"
   "Locales\ca.pak"
   "Locales\cs.pak"
   "Locales\cy.pak"
   "Locales\da.pak"
   "Locales\de.pak"
   "Locales\el.pak"
   "Locales\en-GB.pak"
   "Locales\es-419.pak"
   "Locales\es.pak"
   "Locales\et.pak"
   "Locales\eu.pak"
   "Locales\fa.pak"
   "Locales\fi.pak"
   "Locales\fil.pak"
   "Locales\fr-CA.pak"
   "Locales\fr.pak"
   "Locales\gl.pak"
   "Locales\gu.pak"
   "Locales\he.pak"
   "Locales\hi.pak"
   "Locales\hr.pak"
   "Locales\hu.pak"
   "Locales\hy.pak"
   "Locales\id.pak"
   "Locales\is.pak"
   "Locales\it.pak"
   "Locales\ja.pak"
   "Locales\ka.pak"
   "Locales\kk.pak"
   "Locales\km.pak"
   "Locales\kn.pak"
   "Locales\ko.pak"
   "Locales\ky.pak"
   "Locales\lo.pak"
   "Locales\lt.pak"
   "Locales\lv.pak"
   "Locales\mk.pak"
   "Locales\ml.pak"
   "Locales\mn.pak"
   "Locales\mr.pak"
   "Locales\ms.pak"
   "Locales\my.pak"
   "Locales\nb.pak"
   "Locales\ne.pak"
   "Locales\nl.pak"
   "Locales\or.pak"
   "Locales\pa.pak"
   "Locales\pl.pak"
   "Locales\pt-BR.pak"
   "Locales\pt-PT.pak"
   "Locales\ro.pak"
   "Locales\si.pak"
   "Locales\sk.pak"
   "Locales\sl.pak"
   "Locales\sq.pak"
   "Locales\sr-Latn.pak"
   "Locales\sr.pak"
   "Locales\sv.pak"
   "Locales\sw.pak"
   "Locales\ta.pak"
   "Locales\te.pak"
   "Locales\th.pak"
   "Locales\tr.pak"
   "Locales\uk.pak"
   "Locales\ur.pak"
   "Locales\uz.pak"
   "Locales\vi.pak"
   "Locales\zh-CN.pak"
   "Locales\zh-HK.pak"
   "Locales\zh-TW.pak"
   "Locales\zu.pak"
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

if ($Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = "Chromium-Gost $Bitness"

$ExeName = "chrome.exe"

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
$Script:MutexName = "Global\ChromiumGostPortable$($scriptName -replace '[\\:]','_')"

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
      'AAABAAEAEBAgAAAAAABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///wL+/v4q'
      '/v7+Tv7+/k7+/v4q/v7+AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAA/v7+BP7+/m7+/v7h8u3r/9/Qy//f0Mv/8+3r//7+/t/+/v5u/v7+BAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAA/v7+Ev7+/sPi1tH/oHVk/4JJM/+CSTP/gkkz'
      '/4JJM/+gdWX/49fS//7+/sH+/v4QAAAAAAAAAAAAAAAA/v7+BP7+/sPOuLD/'
      'g0s1/4JJM/+CSjT/k2JP/5NhTv+CSjT/gkkz/4NLNv/m29b//v7+rQAAAAAA'
      'AAAAAAAAAP7+/nDi1dD/g0s1/4JJM/+shnj/8Onn////////////8Onm/6uF'
      'dv++oJX//v7+3/7+/iAAAAAAAAAAAP7+/gL+/v7jnnJh/4JJM/+th3n//v7+'
      '///////5+P3/+fj9///////+/v7//v7+4f7+/iAAAAAAAAAAAAAAAAD+/v4u'
      '8ero/4JJM/+DSjX/8evp//////+2pO3/VyzX/1ct1/+4pu7///////7+/uP+'
      '/v4CAAAAAAAAAAAAAAAA/v7+UtzNx/+CSTP/lWVT///////39f3/VivX/1Im'
      '1v9SJtb/VyzX//j2/f///////v7+JgAAAAAAAAAAAAAAAP7+/lTczMb/gkkz'
      '/5ZmVP//////9vT8/1Uq1v9SJtb/UibW/1Uq1v/39f3///////7+/igAAAAA'
      'AAAAAAAAAAD+/v4y7+jm/4JJM/+DSzX/8+7s//////+wnOz/VCnW/1Up1v+x'
      'nuz///////7+/uX+/v4CAAAAAAAAAAAAAAAA/v7+Av7+/uecb17/gkkz/7GN'
      'f//+/v7///////Tx/P/08vz///////7+/v/+/v7f////GgAAAAAAAAAAAAAA'
      'AAAAAAD+/v5239DL/4JKNP+CSTP/sY6A//Tv7f////////////Tv7f+wjX//'
      'w6ie//7+/tn///8aAAAAAAAAAAAAAAAA/v7+Bv7+/svJsaj/gko0/4JJM/+E'
      'TDb/mGpY/5hqWP+ETDb/gkkz/4NKNP/m29b//v7+rwAAAAAAAAAAAAAAAAAA'
      'AAD+/v4W/v7+y97Pyf+abVv/gkkz/4JJM/+CSTP/gkkz/5ttXP/e0Mr//v7+'
      'yf7+/hYAAAAAAAAAAAAAAAAAAAAAAAAAAP7+/gb+/v56/v7+6e3l4v/ZyML/'
      '2cjC/+3m4//+/v7p/v7+eP7+/gYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAP7+/gT+/v42/v7+WP7+/lj+/v42/v7+BAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAA+B8AAOAHAADAAwAAgAMAAIADAAAABwAAAAcAAAAHAAAABwAAAAcA'
      'AAAHAACAAwAAgAMAAMADAADgBwAA+B8AAA=='
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

# Получение номера версии и ссылки на установщик
Function Get-LatestVersion {
   if (-not (Test-DNS)) {$Script:checkError = $true; return $false}
   Write-Host "Get-LatestVersion..."

   $url = 'https://update.cryptopro.ru/get/chromium-gost/version'
   Write-Host "Request:   $url"

   try {
      $Script:latest = [version]((Make-NetRequest -Url $url).Content.ReadAsStringAsync().Result)
      if (-not $latest) {throw 'latest is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }
   $arch = if ($Bitness -ne 'x86') {'amd64'} else {'386'}
   $Script:distrLink = 'https://update.cryptopro.ru/get/chromium-gost/windows/'+$arch+'/zip'

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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\gost.zip" -Text $Latest -Pbar $true)) {throw}
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
      try {
         Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
         [System.IO.Compression.ZipFile]::ExtractToDirectory("$tmpdir\gost.zip",$tmpdir)
      } catch {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw $_
      }
      Write-Host "Unpack installer: OK" @green

      $dirver = (Get-ChildItem -Path "$tmpdir\*.*.*.*" -Directory -ea 0).Name
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
         Move-Item -Path "$tmpdir\$("version-"+$Bitness+".dll")" -Destination "$tmpdir\$dirver\version.dll" -Force -ea 0
      } else {
         try {
            Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DllPath, "$tmpdir\$dirver")
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

      $excludeList = $SetupExclude + @(
         'config.ini.example'
         'config.ini.example.zh-CN'
      )

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\$dirver\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

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
   try {
      $localStateContent = @(
        '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":'
        '["chrome-labs@3","enable-parallel-downloading@1"]}}'
      ) -join ''
      [IO.Directory]::CreateDirectory($profilePath) | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"
      # Сохранение данных Local State в кодировке UTF-8 без BOM и без новой строки в конце
      $localState = Join-Path $profilePath "Local State"
      [System.IO.File]::WriteAllText($localState, $localStateContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Local State"
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
