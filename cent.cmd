<# :
:: The script creates a portable, auto‑updatable build of the Cent browser from scratch and then works as a launcher.
:: It checks for updates at a specified interval; after closing, it cleans the profile and the registry.
:: To use it, simply place the batch file in any empty folder (except for root, system, and restricted access folders)
:: and run it. The latest version is downloaded immediately, unpacked into a folder next to the batch file,
:: and the browser is launched. Updates are downloaded from the official website to a subfolder within
:: the batch file’s folder and are deleted after installation. You can select the browser’s bitness (x64/x86)
:: by specifying the required value in $Bitness. Portability is ensured by built-in tools - by creating an empty
:: file called "cbportable" in the browser’s directory. If you specify your own profile in the --user-data-dir key,
:: it will be used. Otherwise, a new one is created with a minimal Local State. A folder called App
:: (the name is customizable) is created next to the script; this is where the build will be located.
:: The folders, files, and startup keys to be deleted are added as a separate line in double quotes;
:: anything unnecessary is commented out/deleted. In the $SetupExclude variable, you can specify files
:: and folders that should be excluded from the browser during installation/update.

@echo off
cd /d "%~dp0"
set "Self=%~f0"
powershell.exe -NoP -NoL -NonI -EP Bypass -c "[ScriptBlock]::Create([IO.File]::ReadAllText($env:Self)).Invoke()"
exit /b
#>

# ============================================================================
# USER SETTINGS
# ============================================================================

$CheckInterval = 3 # The update check interval in days; if 0, it will check at each startup.
$CleanInterval = 7 # The interval for cleaning the profile and registry in days; if 0, it will be cleaned at each completion.
$RunMode = 0 # 0 - normal mode, 1 - launch only, 2 - update check/installation only.
$CreateShortcut = $false # Create a shortcut on the desktop.
$AskUpdate = $true # Ask before updating.
$Backup = $false # When updating, create a zip backup of the profile in the batch file folder.
$MakeStub = $false # Create zero-size stub files in place of the folders deleted in the profile ($DelDirs).
$Bitness = "x64" # For the 32-bit version, specify "x86".
$AppDir = "App" # The build folder is created in the same folder as the script.
$7zpath = "" # The local path to 7z.exe; if left empty, it will be downloaded from github.com.
$ShowConsole = $false # Show the console at startup to monitor errors.

$Switches = @( # browser launch keys
   "--user-data-dir=`"..\Profile`""
   "--cb-disable-auto-detect-search-provider"
   "--disable-features=GlobalMediaControls"
   "--cb-do-not-focus-location-bar"
   "--disable-notifications"
   "--no-default-browser-check"
   "--no-first-run"
#   "--disk-cache-dir=nul"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
   "--show-component-extension-options"
   "--cb-disable-auto-update"
#   "--cb-disable-components-auto-update" # Uncomment this and the following 3 keys to disable automatic extension updates.
#   "--cb-disable-extensions-auto-update"
#   "--disable-component-update"
#   "--disable-background-networking"
   "--cb-disable-google-probing"
)

$DelDirs = @( # Profile folders that are deleted after the browser is closed.
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
#  Deleting these folders affects the browser’s operation; uncomment them if you know what you’re doing.
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

$DelFiles = @( # Profile files that are deleted after the browser is closed.
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
   "Default\Reporting and NEL"
   "Default\SCT Auditing Pending Reports"
   "Default\Shared Dictionary"
#  The browser’s functionality breaks down in many ways; uncomment it if privacy is more important than data loss.
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
#   "Default\SharedStorage"
#   "Default\Shortcuts"
#   "Default\TransportSecurity"
#   "Default\trust*"
#   "Default\Top Sites*"
#   "Default\Visited Links*"
#   "Default\WebStorage\QuotaManager*"
)

$DelReg = @( # Registry data that is deleted after the browser is closed.
   "HKEY_CURRENT_USER\SOFTWARE\CentBrowser"
)

$NoStub = @( # Folders for which stub files will not be created
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

$SetupExclude = @( # Folders and files excluded during installation/update
   "chrome.VisualElementsManifest.xml"
   "chrome_proxy.exe"
   "numver\Installer"
   "numver\IwaKeyDistribution"
   "numver\MEIPreload"
   "numver\PrivacySandboxAttestationsPreloaded"
   "numver\VisualElements"
   "numver\bookmarks_cn.html"
   "numver\bookmarks_en.html"
   "numver\bookmarks_ru.html"
   "numver\centbrowserupdater.exe"
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
)

$Trash = @( # Folders and files outside the profile that should be deleted after closing the browser.
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$lastcheck = "18032026"
$lastclean = "18032026"

$scriptName = $env:Self
$scriptPath = Split-Path -Path $scriptName -Parent

if (-not $AppDir) {$AppDir = 'App'}
$AppPath = Join-Path $scriptPath $AppDir

if ($Bitness -ne 'x86') {$Bitness = 'x64'}

$BrowserName = "Cent $Bitness"

$ExeName = "chrome.exe"

if ($Switches | Where-Object {$_ -match '--user-data-dir[^\x22]+\x22([^\x22]+)\x22'}) {
   $profilePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $matches[1]))
} else {
   $profilePath = "$scriptPath\Profile"
}

# TLS 1.2/1.3 for Windows 11
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
# DUPLICATE PROTECTION (MUTEX)
# ============================================================================

$Script:AppMutex = $null
$hash = [BitConverter]::ToString(
   [Security.Cryptography.SHA256]::Create().ComputeHash(
      [Text.Encoding]::UTF8.GetBytes($scriptName)
   )
).Replace('-','').Substring(0,8)
$Script:MutexName = "Global\CentPortable_$hash"

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
# AUXILIARY FUNCTIONS
# ============================================================================

# Controlling the visibility of the console window
Function Set-ConsoleWindow {
   param(
      [string]$State
   )
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

# Icon for notifications and progress bar
Function Extract-IconFromBase64 {
   $iconBase64 = @(
      'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADtgEEc'
      '84U/PvODQD3sgDwaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAQEBAfSDQVzzhULS9IVC//SFQv/0hUL/9IVC//OFQtD0hUJbAQEBAQAA'
      'AAAAAAAAAAAAAAAAAAAAAAAA5oA0CvSFQrD0hUL/9IVC//SFQv/0hUL/9IVC'
      '//SFQv/0hUL/9IVC//SEQa/mgDQKAAAAAAAAAAAAAAAAAQEBAfSFQrD0hUL/'
      '9IVC//SFQv/0hUL/9IVC//SFQv/0hUL/9IVC//SFQv/0hUL/9IRCsQEBAQEA'
      'AAAAAAAAAPSDQVz0hUL/9IVC//SFQv/0hUL/9YdF//adZ/32nWf99YZE//SF'
      'Qv/0hUL/9Y9R//rNsvi+7PtpAAAAAAAAAADzhULR9IVC//SFQv/0hUL/9ptk'
      '/+7n1P+t1p7/rdae/+7m0v/2nWf/+buW/8/s9f9Czfz/HsP75wAAAADthTob'
      '9IVC//SFQv/0hUL/9YdF/+7n1P9isEb/U6g0/1OoNP9isEb/7fbq/2zY/f8H'
      'vfz/Bbz7/wW8+/8Bu/Ya84U/PvSFQv/0hUL/9IVC//efav+u1p//U6g0/1Oo'
      'NP9TqDT/U6g0/67Wn/85yvz/Bbz7/wW8+/8FvPv/Abr7PvOFPz70hUL/9IVC'
      '//SFQv/3n2r/rtaf/1OoNP9TqDT/U6g0/1OoNP+u1p//Ocr8/wW8+/8FvPv/'
      'Bbz7/wG6+z7thTob9IVC//SFQv/0hUL/9YdF/+7n1P9isEb/U6g0/1OoNP9i'
      'sEb/7fbq/2zY/f8Hvfz/Bbz7/wW8+/8Bu/YaAAAAAPOFQtH0hUL/9IVC//SF'
      'Qv/2m2T/7ufU/63Wnv+t1p7/7ubS//adZ//5u5b/z+z1/0LN/P8ew/vnAAAA'
      'AAAAAAD0g0Fc9IVC//SFQv/0hUL/9IVC//WHRf/2nWf99p1n/fWGRP/0hUL/'
      '9IVC//WPUf/6zbL4vuz7aQAAAAAAAAAAAQEBAfSFQrD0hUL/9IVC//SFQv/0'
      'hUL/9IVC//SFQv/0hUL/9IVC//SFQv/0hUL/9IRCsQEBAQEAAAAAAAAAAAAA'
      'AADmgDQK9IVCsPSFQv/0hUL/9IVC//SFQv/0hUL/9IVC//SFQv/0hUL/9IRB'
      'r+aANAoAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQH0g0Fc84VC0vSFQv/0hUL/'
      '9IVC//SFQv/zhULQ9IVCWwEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAADtgEEc84U/PvODQD3sgDwaAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAA/D8AAOAHAADAAwAAgAEAAIABAACAAQAAAAAAAAAAAAAAAAAAAAAA'
      'AIABAACAAQAAgAEAAMADAADgBwAA/D8AAA=='
   ) -join ''
   $memStream = $null
   try {
      $iconBytes = [Convert]::FromBase64String($iconBase64)
      $memStream = New-Object System.IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
      return [System.Drawing.Icon]::new($memStream)
   }
   catch {
      Write-Host "$_.Exception.Message" -ForegroundColor Red
      return [System.Drawing.SystemIcons]::Application
   }
   finally {
      if ($memStream) {$memStream.Dispose()}
   }
}

# Windows notifications
Function Show-Balloon {
   param(
       [string]$Message,
       [string]$Title = $BrowserName,
       [string]$MessageType = "Info",
       [int]$Duration = 10000
   )
   $balloon = $null
   $icon = $null
   try {
      if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.NotifyIcon').Type) {
         Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
         Add-Type -AssemblyName System.Drawing -ErrorAction Stop
      }
      $balloon = New-Object System.Windows.Forms.NotifyIcon
      $icon = Extract-IconFromBase64
      $balloon.Icon = $icon
      $balloon.Text = $Title
      $balloon.Visible = $true
      $balloon.ShowBalloonTip($Duration, $Title, $Message, [System.Windows.Forms.ToolTipIcon]$MessageType)
      Start-Sleep -Milliseconds 3000
   } catch {
      Write-Host "$_.Exception.Message" @red
   } finally {
      if ($balloon) {
          try {
              $balloon.Visible = $false
              if ($balloon.Icon) {
                  $balloon.Icon.Dispose()
              }
              $balloon.Dispose()
          }
          catch {}
      }
      elseif ($icon) {
          $icon.Dispose()
      }
   }
}

# Storing variable values within this file.
Function Set-FileVar {
   param(
      [string]$Name,
      [string]$Value
   )
   try {
      $content = Get-Content -LiteralPath $scriptName -Encoding UTF8
      $newContent = $content -replace "(?<=^\s*\x24$Name\s*=\s*\x22)[^\x22]*",$Value
      [System.IO.File]::WriteAllLines("$($scriptName).tmp", $newContent, (New-Object System.Text.UTF8Encoding $false))
      Move-Item -LiteralPath "$($scriptName).tmp" -Destination $scriptName -Force
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Network check
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

# HTTP client
Function Get-HttpClient {
   if (-not $Script:HttpClient) {
      if (-not ([AppDomain]::CurrentDomain.GetAssemblies() |
          Where-Object { $_.GetName().Name -eq 'System.Net.Http' })) {
         Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
      }
      $Script:HttpClient = New-Object System.Net.Http.HttpClient
      $Script:HttpClient.Timeout = [TimeSpan]::FromSeconds(30)
      $Script:HttpClient.DefaultRequestHeaders.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
   }
   return $Script:HttpClient
}

# Network request
Function Make-NetRequest {
   param(
      [string]$Url,
      [int]$Timeout=10
   )

   $client = Get-HttpClient
   $cts = $null
   $task = $null
   $response = $null

   try {
      $uri = New-Object System.Uri $Url
      $cts = New-Object System.Threading.CancellationTokenSource
      $cts.CancelAfter([TimeSpan]::FromSeconds($Timeout))

      for ($i = 1; $i -le 3; $i++) {
         try {
            $task = $client.GetAsync($uri,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead,$cts.Token)
            $response = $task.GetAwaiter().GetResult()

            if ($response.IsSuccessStatusCode) {
               $result = $response
               $response = $null
               return $result
            }

            $statusCode = [int]$response.StatusCode
            $response.Dispose(); $response = $null
            throw "Bad StatusCode: $statusCode"
         } catch {
            Write-Host "$($_.Exception.Message)" @red
            Show-Balloon -Message "Failed response $($uri.Host), try again..." -MessageType "Warning"
            if ($i -lt 3) {Start-Sleep -Seconds $(3*$i)}
         } finally {
            if ($task) {$task.Dispose(); $task = $null}
         }
      }
   } catch {
      Write-Host "$($_.Exception.Message)" @red
   } finally {
      if ($cts) {$cts.Dispose()}
      if ($response) {
         try {$response.Dispose()} catch {}
         $response = $null
      }
   }
   return $null
}

# Obtaining the version number and the installer link
Function Get-LatestVersion {
   if (-not (Test-DNS)) {$Script:checkError = $true; return $false}
   Write-Host "Get-LatestVersion..."

   $arch = if ($Bitness -eq 'x64') {'_x64'} else {$null}
   $url = 'https://www.centbrowser.com/history.html'
   Write-Host "Request:   $url"

   try {
      $response = Make-NetRequest -Url $url
      if (-not $response) {throw 'HTTP-response is NULL'}
      $html = $response.Content.ReadAsStringAsync().Result
      if (-not $html) {throw 'HTTP-content is NULL'}
      if ($html -match "(https?://.+?_[\d\.]+$($arch)_portable\.exe)") {
         $Script:distrLink = $matches[1]
      } else {
         throw 'distrLink is NULL'
      }
      if ($distrLink -match '.+/(\d+\.\d+\.\d+\.\d+)/.+') {
         $Script:latest = [version]$matches[1]
      } else {
         throw 'latest is NULL'
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   } finally {
      if ($response) {$response.Dispose()}
   }

   Write-Host "Link:      $distrLink"
   Write-Host "Latest:    v$latest"

   return $true
}

# Version comparison
Function Check-NewVersion {
   if (-not (Get-LatestVersion)) {return $false}

   Set-FileVar -Name "lastcheck" -Value $(Get-Date -Format 'ddMMyyyy')

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
# Form for the progress bar
Function Get-ProgressForm {
   param(
      [string]$Title
   )
   try {
      if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type) {
         Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
         Add-Type -AssemblyName System.Drawing -ErrorAction Stop
      }
      if (-not [System.Windows.Forms.SystemInformation]::UserInteractive) {throw}
      $progressForm = New-Object System.Windows.Forms.Form
      $progressForm.Size = New-Object System.Drawing.Size(317,150)
      $progressForm.StartPosition = 'CenterScreen'
      $progressForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
      $progressForm.BackColor = '#0B5162'
      $progressForm.TopMost = $True
      $progressForm.Text = "$Title"
      $icon = Extract-IconFromBase64
      $progressForm.Icon = $icon

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
      if ($icon) {$icon.Dispose()}
      return $null
   }
}

# Downloading files
Function Download-File {
   param(
      [string]$Source,
      [string]$Dest,
      [string]$Text,
      [boolean]$Pbar
   )

   try {
      $response = Make-NetRequest -Url $Source

      $progressForm,$progressBar,$progressLabel = Get-ProgressForm -Title $BrowserName
      $totalLength = $response.Content.Headers.ContentLength / 1MB
      if (-not $progressForm -or -not $totalLength) {$Pbar = $false}

      if ($Pbar) {

         $responseStream = $response.Content.ReadAsStreamAsync().Result

         $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList "$Dest", Create
         $buffer = New-Object byte[] 8192
         $count = $responseStream.Read($buffer,0,$buffer.length)
         $downloadedBytes = $count

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
          try {
              $progressForm.Close()
              if ($progressForm.Icon) {
                  $progressForm.Icon.Dispose()
              }
              $progressForm.Dispose()
          }
          catch {}
      }
   }
}

# Downloading, unpacking, copying
Function Update-Browser {
   if ($instmode -eq 'update') {Write-Host "Update-Browser..."}
   try {
      Get-ChildItem -Path $scriptPath -Filter 'temp_*' -Directory -ea 0 | Remove-Item -Recurse -Force -ea 0
      $Script:tmpdir = Join-Path $scriptPath "temp_$([IO.Path]::GetRandomFileName())"
      [IO.Directory]::CreateDirectory($tmpdir) | Out-Null
      Write-Host "Create temporary $($tmpdir): OK" @green

      # Installer
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\instcent.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
         $7zurl='https://github.com/ip7z/7zip/releases'
         $response = Make-NetRequest -Url "$7zurl/latest"
         $7zlatest = ($response.RequestMessage.RequestUri.AbsoluteUri -Split 'tag/')[1]
         if (-not $7zlatest) {throw '7zlatest is NULL'}
         try {$response.Dispose()} catch {}
         $response = $null
         $response = Make-NetRequest -Url "$7zurl/expanded_assets/$7zlatest"
         $assets = $response.Content.ReadAsStringAsync().Result
         if (-not $assets) {throw '7z assets is NULL'}
         if ($assets -match "href=\x22(/[^-]+\.msi)") {
            $7zlink = 'https://github.com'+$matches[1]
         } else {
            throw 'Error 7-zip check link'
         }
         try {$response.Dispose()} catch {}
         $response = $null
         if (-not (Download-File -Source $7zlink -Dest "$tmpdir\7z.msi")) {throw}
         Start-Process msiexec.exe -ArgumentList "/a `"$tmpdir\7z.msi`" /qn TARGETDIR=`"$tmpdir\unp`"" -Wait
         $7zpath = "$tmpdir\unp\Files\7-Zip\7z.exe"
         if ([IO.File]::Exists($7zpath)) {
             Write-Host "Download and unpack 7-zip: OK" @green
         } else {
            throw 'Error unpack 7-zip'
         }
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Unpacking
      &($7zpath) x -aoa "$tmpdir\instcent.exe" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      # List of files to save
      $nodel = @(
         (Split-Path $profilePath -Leaf)
         'debug.log'
      )

      $dirver = (Get-ChildItem $tmpdir -Recurse -Filter chrome.dll -ea 0 | Select-Object -First 1).Directory.Name
      if (-not $dirver) {
         Show-Balloon -Message "Error in defining the directory structure" -MessageType "Error"
         throw 'Not detect directory number version'
      }

      $excludeList = $SetupExclude + @(
         'instcent.exe'
      ) -replace 'numver',"$dirver"

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      if (-not [IO.Directory]::Exists($AppPath)) {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      Copy-Item -Path "$tmpdir\*" -Destination $AppPath -Exclude $dirver -Recurse -Force
      Copy-Item -Path "$tmpdir\$dirver\*" -Destination $AppPath -Recurse -Force

      Get-ChildItem -Path $AppPath -Force -ea 0 | Where-Object {
         ($nodel -notcontains $_.Name) -and
         -not (Test-Path -LiteralPath (Join-Path "$tmpdir" $_.Name)) -and
         -not (Test-Path -LiteralPath (Join-Path "$tmpdir\$dirver" $_.Name))
      } | Remove-Item -Recurse -Force -ea 0

      Write-Host "Update files in $($AppPath): OK" @green

      Get-Item -Path "$scriptPath\*_backup_*.zip" -ea 0 |
         Sort-Object LastWriteTime -Descending |
         Select-Object -skip 2 | ForEach-Object {
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

# New profile
Function Create-Profile {
   Write-Host "Create-Profile..."
   try {
      $localStateContent = @(
         '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":["compact-mode@1","disable-direct-wr'
         'ite","enable-webrtc-hide-local-ips-with-mdns@1","overlay-scrollbars@1"],"first_run_finished":true},"cent":{"bro'
         'wser_muted":false,"disable_audio_context":true,"disable_battery_status":true,"disable_canvas_reading":true,"dis'
         'able_webrtc":true,"enable_auto_update":false,"show_mute_toggle_button":true},"intl":{"app_locale":"ru"}}'
      ) -join ''
      [IO.Directory]::CreateDirectory($profilePath) | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"
      $localState = Join-Path $profilePath "Local State"
      [System.IO.File]::WriteAllText($localState, $localStateContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Local State"
      Write-Host "New profile: Done" @green
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Removing junk after closing the browser
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
                if ($MakeStub -and ($NoStub -notcontains $item.BaseName)) {
                   [System.IO.File]::Create($item.FullName).Dispose()
                   [System.IO.File]::SetAttributes($item.FullName, [System.IO.FileAttributes]::ReadOnly)
                   $msgok = "Deleted directory and create stub: $($item.FullName)"
                }
            }
            'FileInfo' {
                $escpath = $null; $escpath = [System.Management.Automation.WildcardPattern]::Escape($profilePath)
                $isStub = [bool](@($DelDirs | Where-Object {$item.FullName -like "$escpath\$_"}))
                if (-not ($isStub -and -not $item.length) -or -not $MakeStub) {
                   $item.Delete()
                   $f += 1
                   $msgok = "Deleted file$(if($isStub){'-stub'}): $($item.FullName)"
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
         Write-Host "Error deleted $item.FullName: $_.Exception.Message" @red
      }
   }
   Write-Host "Clean result: $([int]$f) files, $([int]$d) directories, $([int]$r) registry entries" @green
}

# ============================================================================
# MAIN CODE
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
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
Write-Host                  "Mutex:     $MutexName"   @darkcyan

try {

   try {[datetime]::parseexact($lastcheck, 'ddMMyyyy', $null)} catch {$lastcheck='18032026'}
   $daysCheck = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   # Update check conditions: special launch mode, exceeding the specified interval, absence of an executable file.
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

   # Creating a shortcut
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

   # The presence of an executable browser file
   if (-not [IO.File]::Exists("$AppPath\$ExeName")) {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed $ExeName" -MessageType "Error"
      }
      throw "Missed $ExeName"
   }

   # Creating a new profile
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

   # Stub
   if (-not [IO.File]::Exists("$AppPath\cbportable")) {
       [System.IO.File]::Create("$AppPath\cbportable").Dispose()
   }
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

   # Launching the browser
   $browserProcessName = ($ExeName -replace '\.exe$','')

   $sameBrowser = {
      Get-Process -Name $browserProcessName -ErrorAction SilentlyContinue | Where-Object {
         try {$_.Path -eq "$AppPath\$ExeName"} catch {$true}
      }
   }

   $browserRunning = @(& $sameBrowser)

   if (-not $browserRunning) {
      Start-Process -FilePath "$AppPath\$ExeName" -ArgumentList $Switches -WorkingDirectory $AppPath

      for ($i = 0; $i -lt 6; $i++) {
         $browserRunning = @(& $sameBrowser)
         if ($browserRunning) {break}
         Start-Sleep -Seconds 5
      }
   } else {
      Write-Host "Browser already running - attaching to it" @yellow
   }

   Write-Host "Start browser..."

   # Monitoring with a timeout
   $maxWaitSeconds = 86400
   $waitStart = Get-Date

   while ($true) {
      if (((Get-Date) - $waitStart).TotalSeconds -gt $maxWaitSeconds) {$Script:timedOut = $true; break}

      $browserRunning = @(& $sameBrowser)
      if (-not $browserRunning) {break}

      Start-Sleep -Seconds 5
   }

   # Profile cleaning
   try {[datetime]::parseexact($lastclean, 'ddMMyyyy', $null)} catch {$lastclean='18032026'}
   
   $sinceclean = (New-TimeSpan -Start $([datetime]::parseexact($lastclean, 'ddMMyyyy', $null))).Days

   if ($browserRunning -or $timedOut) {
      Write-Host "Browser still running - cleanup skipped" @yellow
   } elseif ($sinceclean -ge [int]$CleanInterval) {
      Write-Host "Start profile clean..."
      Delete-Traces
      Set-FileVar -Name "lastclean" -Value $(Get-Date -Format 'ddMMyyyy')
   }

   # Deletion according to the $Trash list
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

   if ($Script:HttpClient) {
      try {$Script:HttpClient.Dispose()} catch {}
      $Script:HttpClient = $null
   }

   Exit-SingleInstance
   if ($ShowConsole) {[void][Console]::ReadKey($true)}
}
