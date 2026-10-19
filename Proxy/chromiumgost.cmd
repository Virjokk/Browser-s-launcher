<# :
:: The script creates a portable, auto updating build of the Chromium-Gost browser from scratch and then works as a launcher.
:: It checks for updates at a specified interval; after closing, it cleans the profile and the registry.
:: To use it, simply place the batch file in any empty folder (except for root, system, and restricted access folders)
:: and run it. The latest version is downloaded immediately, unpacked into a folder next to the batch file, and
:: the browser is launched. Updates are downloaded from the official website to a subfolder within the batch file’s
:: folder and are deleted after installation. You can select the browser’s bitness (x64/x86) by specifying the
:: required value in $Bitness. Portability is ensured by version.dll from ca-x (https://github.com/ca-x/vivaldi_plus/) or
:: from Bush2021 (https://github.com/Bush2021/chrome_plus), as selected and configured in the $versiondll variable.
:: The version.dll configurations are set up here, in the $ConfigData and $ConfigCache variables, in terms of the
:: name and location of the profile folders and cache, so there’s no point in specifying them directly in chrome++.ini/config.ini.
:: To check/download updates and for the browser, you can use opera-proxy (https://github.com/Alexey71/opera-proxy),
:: which will be downloaded and launched with the specified parameters; it will auto update when new versions are released.
:: If you specify the path to your profile in $ConfigData, it will be picked up. Otherwise, a new one is created with
:: a minimal Local State. A folder named App (the name is customizable) is created next to the script, and the
:: build will be located in it. The folders, files, and launch keys to be deleted are added as a separate line
:: in double quotes; anything unnecessary is commented out/deleted. In the $SetupExclude variable, you can specify
:: files and folders that should be excluded from the browser during installation/update.

@echo off
cd /d "%~dp0"
powershell.exe -NoP -NoL -NonI -EP Bypass -c "&{[ScriptBlock]::Create((gc -lit '%~f0' -enc UTF8) -join [Char]10).Invoke()}"
exit /b
#>

# ============================================================================
# USER SETTINGS
# ============================================================================

$CheckInterval = 3 # The update check interval in days; if 0, it will check at each startup.
$CleanInterval = 7 # The interval for cleaning the profile and registry in days; if 0, it will be cleaned at each completion.
$ConfigData = "%app%\..\Profile" # The path to the profile that will be added to chrome++.ini/config.ini.
$ConfigCache = "%app%\..\Cache" # The path to the cache that will be added to chrome++.ini/config.ini.
$RunMode = 0 # 0 - normal mode, 1 - launch only, 2 - update check/installation only.
$CreateShortcut = $false # Create a shortcut on the desktop.
$AskUpdate = $true # Ask before updating.
$Backup = $false # When updating, create a zip backup of the profile in the batch file folder.
$MakeStub = $false # Create zero-size stub files in place of the folders deleted in the profile ($DelDirs).
$Bitness = "x64" # For the 32-bit version, specify "x86".
$VersionDll = 0 # 0 - version.dll the Bush2021, 1 - the ca-x (czyt.tech)
$AppDir = "App" # The build folder is created in the same folder as the script.
$7zpath = "" # The local path to 7zr.exe or 7z.exe; if left empty, it will be downloaded from github.com.
$DllPath = "" # The local path to windows_x86/x64.zip or setdll.7z; if left empty, it will be downloaded from github.com.
$UseProxy = 0 # 0 - do not include, 1 - only for the browser, 2 - for the browser and for checking/downloading updates
$ProxyPath = "" # The local path to the Opera Proxy; if left empty, it will be downloaded from github.com (if $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18081","-verbosity 30" # Proxy parameters
$ShowConsole = $false # Show the console at startup to monitor errors.

$Switches = @( # browser launch keys
   "--no-default-browser-check"
   "--no-first-run"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
   "--show-component-extension-options"
#   "--disable-component-update" # Uncomment this and the following keys to disable automatic extension updates.
#   "--disable-background-networking"
   "--proxy-server=$(($ProxyArg -Split " ")[1])"
   "--disable-features=PrintCompositorLPAC"
   "--allow-legacy-mv2-extensions"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
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
#  The browser’s functionality breaks down in many ways; uncomment it if privacy is more important than data loss.
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

$DelReg = @( # Registry data that is deleted after the browser is closed.
   "HKEY_CURRENT_USER\SOFTWARE\Chromium"
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

$Trash = @( # Folders and files outside the profile that should be deleted after closing the browser.
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# GLOBAL VARIABLES
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
      Start-Sleep -Milliseconds 10000
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

# Network request
Function Make-NetRequest {
   param(
      [string]$Url,
      [int]$Timeout=10
   )

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

# Obtaining the version number and the installer link
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

# Version comparison
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
      if (-not [System.Windows.Forms.SystemInformation]::UserInteractive) {
         return $null
      }
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

      # Unpacking
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

      # List of files to save
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

# New profile
Function Create-Profile {
   Write-Host "Create-Profile..."
   try {
      $localStateContent = @(
        '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":'
        '["chrome-labs@3","enable-parallel-downloading@1"]}}'
      ) -join ''
      [IO.Directory]::CreateDirectory($profilePath) | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"
      # Saving Local State data in UTF-8 encoding without BOM and without a newline at the end
      $localState = Join-Path $profilePath "Local State"
      [System.IO.File]::WriteAllText($localState, $localStateContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Local State"
      Write-Host "New profile: Done" @green
   } catch {
      Write-Host "$_.Exception.Message" @red
   }
}

# Proxy settings
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

# Configuration of ini for version.dll
Function Check-IniFile {
    param(
       [string]$Dlldescr
    )

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

# Removing junk after closing the browser
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
if ($UseProxy) {Write-Host  "Proxy:     $ProxyPath"   @darkcyan}
Write-Host                  "Profile:   $profilePath" @darkcyan
if ($cachePath) {Write-Host "Cache:     $cachePath"   @darkcyan}
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
if ($DllPath) {Write-Host   "Dll:       $DllPath"     @darkcyan}
Write-Host                  "Mutex:     $MutexName"   @darkcyan

try {

   if (-not $lastcheck) {$lastcheck='18032026'}
   $daysCheck = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   # Update check conditions: special launch mode, exceeding the specified interval, absence of an executable file.
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

   # The presence of version.dll
   try {
      $dllInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\version.dll").FileDescription
      if (-not $dllInfo) {throw}
   } catch {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed version.dll" -MessageType "Error"
      }
      throw 'Missed version.dll'
   }

   # Creating a new profile
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

   # INI setting
   try {if (-not (Check-IniFile -Dlldescr $dllInfo)) {Write-Host "Not changed $baseini"}}
   catch {throw "Error tuned $($baseini): $_"}

   # Stub
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

   # Empty Switches Filter
   if ($Switches.Count -eq 0) {$Switches = @('--no-first-run')}

   # Starting the proxy
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

   # Launching the browser
   Start-Process -FilePath "$AppPath\$ExeName" -ArgumentList $Switches -WorkingDirectory $AppPath
   Start-Sleep -Seconds 2
   Write-Host "Start browser..."

   # Monitoring with a timeout
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

   # Profile cleaning
   if (-not $lastclean) {$lastclean='18032026'}
   
   $sinceclean = (New-TimeSpan -Start $([datetime]::parseexact($lastclean, 'ddMMyyyy', $null))).Days

   if ($sinceclean -ge [int]$CleanInterval) {
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
