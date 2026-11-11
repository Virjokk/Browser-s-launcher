<# :
:: The script creates a portable, auto updating build of the Ungoogled Chromium browser from scratch and thenworks as a launcher.
:: It checks for updates at a specified interval; after closing, it cleans the profile and the registry.
:: To use it, you just need to place the batch file in any empty folder (except for root, system, and restricted
:: access folders) and run it. The latest version is downloaded immediately, unpacked into the folder next to the
:: batch file, and the browser is launched. Updates are downloaded from the official website to a subfolder within
:: the batch file’s folder and are deleted after installation.
:: Each new build from Macchrome will be downloaded, even if the Ungoogled version remains unchanged.
:: Portability is ensured by the launch keys --disable-machine-id, --disable-encryption.
:: To check/download updates and for the browser, you can use opera-proxy (https://github.com/Alexey71/opera-proxy),
:: which will be downloaded and launched with the specified parameters; it will auto update when new versions are released.
:: If you specify your profile in the --user-data-dir key, it will be used; otherwise, a new one will be created
:: with pre-settings from Insorg (https://forum.ru-board.com/topic.cgi?forum=2&bm=1&topic=5915&start=60#1).
:: A folder named App (the name is customizable) will be created next to the script, and the build will be located there.
:: The folders, files, and launch keys to be deleted are added as a separate line in double quotes; anything
:: unnecessary is commented out or deleted. In the $SetupExclude variable, you can specify files and folders that
:: should be excluded from the browser during installation/update.

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
$RunMode = 0 # 0 - normal mode, 1 - launch only, 2 - update check/installation only.
$CreateShortcut = $false # Create a shortcut on the desktop.
$AskUpdate = $true # Ask before updating.
$Backup = $false # When updating, create a zip backup of the profile in the batch file folder.
$MakeStub = $false # Create zero‑size stub files in place of the folders deleted in the profile ($DelDirs).
$AppDir = "App" # The build folder is created in the same folder as the script.
$7zpath = "" # The local path to 7zr.exe or 7z.exe; if left empty, it will be downloaded from github.com.
$UseProxy = 0 # 0 - do not include, 1 - only for the browser, 2 - for the browser and for checking/downloading updates
$ProxyPath = "" # The local path to the Opera Proxy; if left empty, it will be downloaded from github.com (if $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18088","-verbosity 30" # Proxy parameters
$ShowConsole = $false # Show the console at startup to monitor errors.

$Switches = @( # browser launch keys
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
   "--hide-sidepanel-button"
   "--remove-tabsearch-button"
   "--remove-grab-handle"
   "--scroll-tabs=always"
   "--popups-to-tabs"
   "--close-window-with-last-tab=never"
   "--show-avatar-button=never"
   "--tab-hover-cards=tooltip"
   "--extension-mime-request-handling=always-prompt-for-install"
   "--enable-features=#enable-parallel-downloading"
   "--force-punycode-hostnames"
   "--proxy-server=$(($ProxyArg -Split " ")[1])"
   "--disable-features=PrintCompositorLPAC"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
   "--no-first-run"
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
   "Default\AutofillAiModelCache"
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
#  The browser’s functionality breaks down in many ways; uncomment it if privacy is more important than data loss.
#   "*-journal"
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
   "VisualElements"
   "WidevineCdm"
   "chrome_pwa_launcher.exe"
   "chrome_wer.dll"
   "chrome_proxy.exe"
#   "chromedriver.exe"
   "dxcompiler.dll"
   "dxil.dll"
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
$BuildLocal = "1"

$scriptName = $MyInvocation.Line -replace "[^']+'([A-Za-z]:\\.+)'[^']+",'$1'
$scriptPath = Split-Path -Path $scriptName -Parent

if (-not $AppDir) {$AppDir = 'App'}
$AppPath = Join-Path $scriptPath $AppDir

$BrowserName = "Ungoogled Chromium"

$ExeName = "chrome.exe"

if (-not $ProxyPath) {$ProxyPath = "$scriptPath\opera-proxy.windows-amd64.exe"}

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
$Script:MutexName = "Global\UngoogledPortable$($scriptName -replace '[\\:]','_')"

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
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsT'
      'AAALEwEAmpwYAAADlUlEQVR4nO2U+0tTYRzG979EEf1UBBbFtF21C0TShXJa'
      'gVFkkd0oKCFkU1mmaYhlRqUeN2dNu7iZba3UMt0vao0uK7rQ1Wp2YddzeeI9'
      'skp33u247LceeOBwfnk+3+f9vq9C8V9pSF97L0NlHC1ZZnzQWlTvHdlV18sc'
      'utC5RvEvpTLfL1h2+O1rZWFEUG4SIOXlOzkUlL+LHDjfXTZjwerafmXmvrFx'
      'ZZ50qJQzDQI2HvvCHTpnN/xduNF3QrmFkx081bptPIobBu6kFa4qfeRQGtIL'
      '/tNZ+QJ21Y8+n164cfTkdCpPCWEQUNx41yMvvM69RLk1/dpp1hTyOGK7uiEl'
      'gLbl7sOle9kZByDeWBpgk4dbLBo18x3KmjAWb5duQb1ZQM1FAT4/EI4CMQ54'
      'EwCco4DpGlB6ZbJNXQIqbvI4fodF1UAM5T0X9lABdNZbvWomCOKM3TEs3jEZ'
      'IrdIgP8VEIkB14cBs2PCXSMT/z58A2o9AipcHCp7WVQPRnFyaLJNLu84FUDT'
      '6g/HAVSNISxYy/+CIJOT8BefgLzTgNY82YYzwMvPwFhQwClvYnDcZX1fIRm+'
      '3G6ZEw+Pe0lJDPNXC1i0nRNrJ1NKhf8JEWEBz0uOClBNWug+o0qc3mbbMBVA'
      '3RzEwnxOhPC9EMTaaeFxO0aA9z8EKoDYwo2mygSA7LaOkgQAJojM6ogIEAwD'
      'x52pASqdQIxHCoBOl8QCdh6VAhAXsoidFkCUSwVg75EAaF9HA8g6G8IDP2bu'
      'CLqbzAkAKxlmNg2AuMrJiUtIFo0Wnt8wsYTXH6exhETa1qchGkC2JQh/gBev'
      'mhQECX/1GXg2BlTdTzJ9/7j0NSTSWd23k7WwviMkQpApSdVkJ4jJN/n37CNw'
      'sItNWr/JNRRQ0KS/ZFWpmW9UAGK9JYhabxS+TzxCLET7Pgg45QJW1fFixdT6'
      'B6MwO87vpgIQ6ax9I8kApKyt5sVjKO6KJZ/e4wsqUinH1jxPzbzjZQM0h8Tw'
      'VfX0xSM23wujoqchWyFH+jb7NjXzVRaApjEiAhxx0ac/MRhBmbPtoqzwuPTW'
      'a1VyIDR1LHLPscnDbzq8inSktV4uTHUcuhoexl567dOefKr0l5i5Okv/sNTt'
      '0DSHkNfCSm676ZYvJPvM5SjHZs/SWd0eDfPk12O1oimMyoHfweV94zC5vYGU'
      'V+1vlWOxzMpub8/df9XeUtbT4SZvO/V5/S9Fcv0EOC7m4RioxTcAAAAASUVO'
      'RK5CYII='
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

# The simplest HTML parser for extracting links.
Function Get-HtmlLinks ([string]$Html) {
   $pattern = '<a\s+[^>]*href=["''](.*?)["'']'
   $matches = [regex]::Matches($html, $pattern, "IgnoreCase")

   foreach ($m in $matches) {
       $href = $m.Groups[1].Value;
       if ($href -match '^(#|javascript:)') { continue };
       $href
   }
}

# Obtaining the version number and the installer link
Function Get-LatestVersion {
   if (-not (Test-DNS)) {$Script:checkError = $true; return $false}
   Write-Host "Get-LatestVersion..."

   $url = 'https://github.com/macchrome/winchrome/releases/latest'
   Write-Host "Request:   $url"

   try {
      $html = (Make-NetRequest -Url $url).Content.ReadAsStringAsync().Result
      if (-not $html) {throw 'html is NULL'}
      $Script:distrLink = (Get-HtmlLinks -Html $html) -like "*Win64.7z" | Select-Object -Last 1
      if (-not $html) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   try {
      $Script:latest,$Script:buildRemote = if ($distrLink -match '.+?-([\d\.]+)-?(\d+)?_Win64\.7z') {
         [version]$matches[1],[int]$matches[2]
      }
      if (-not $latest) {throw 'latest is NULL'}
      if (-not $buildRemote) {throw 'buildRemote is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error parsing version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   Write-Host "Link:      $distrLink"
   Write-Host "Latest:    v$latest-$buildRemote"

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
      if ($buildRemote -le [int]$buildLocal) {
         Write-Host "Installed v$current-$buildLocal - no update required"
         return $false
      }
   }

   if ($current -ne $null) {
      Write-Host "Installed: v$current-$buildLocal - update is available"
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
         $query = "$BrowserName v$latest-$buildRemote is new version, update?"; $title = "Current v$current-$buildLocal"
         if ([System.Windows.Forms.MessageBox]::Show($query,$title,4,32) -like 'Yes') {
            return $true
         } else {
            $Script:checkError = $true
            return $false
         }
      } else {
         Show-Balloon -Message "v$latest-$buildRemote is new version, start update..."
         return $true
      }
   } else {
      $script:instmode = 'install'
      Show-Balloon -Message "v$latest-$buildRemote start install..."
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\ungoogled.7z" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Unpacking
      &($7zpath) x -t7z -aoa "$tmpdir\ungoogled.7z" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      $nodel = @(
         "$($profilePath.split('\')[-1])"
         "$((($profilePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      $nodel += @(
         "$($ProxyPath.split('\')[-1])"
         "$((($ProxyPath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
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

      $SetupExclude | ForEach-Object {
         $excludePath = "$tmpdir\ungoogled-chromium*\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\ungoogled-chromium*\*" -Destination $AppPath -Recurse -Force
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

   $localStateContent = @(
     '{"background_mode":{"enabled":false},"browser":{"enabled_labs_experiments":["close-window-with-last-tab@1","dis'
     'able-encryption","disable-machine-id","extension-mime-request-handling@2","hide-sidepanel-button","ignore-gpu-b'
     'locklist","popups-to-tabs","read-anything@2","remove-tabsearch-button","show-avatar-button@3","side-search@2","'
     'smooth-scrolling@2"]},"hardware_acceleration_mode_previous":true,"profile":{"last_used":"Default"}}'
   ) -join ''

   $preferencesContent = @(
     '{"distribution":{"alternate_shortcut_text":false,"chrome_shortcut_icon_index":0,"create_all_shortcuts":true,"do'
     '_not_create_desktop_shortcut":true,"do_not_create_quick_launch_shortcut":true,"do_not_create_taskbar_shortcut":'
     'true,"do_not_launch_chrome":true,"do_not_register_for_update_launch":true,"import_bookmarks":false,"import_hist'
     'ory":false,"import_home_page":false,"import_search_engine":false,"make_chrome_default":false,"make_chrome_defau'
     'lt_for_user":false,"show_welcome_page":false,"skip_first_run_ui":true,"system_level":false,"verbose_logging":fa'
     'lse},"first_run_tabs":[],"homepage":"chrome://chrome-urls","homepage_is_newtabpage":false,"safebrowsing":{"enab'
     'led":false},"session":{"restore_on_startup":1},"alternate_error_pages":{"enabled":false},"NewTabPage":{"Disable'
     'dModules":["dummy","dummy2"],"ModulesVisible":false},"account_id_migration_state":2,"autofill":{"credit_card_en'
     'abled":false,"enabled":false,"orphan_rows_removed":true,"profile_enabled":false},"bookmark_bar":{"show_apps_sho'
     'rtcut":false,"show_on_all_tabs":false,"show_only_on_ntp":true,"show_reading_list":false},"browser":{"show_home_'
     'button":true,"check_default_browser":false,"clear_data":{"browsing_history_basic":true,"cache_basic":true,"cook'
     'ies_basic":true,"form_data":true,"hosted_apps_data":true,"media_licenses":true,"passwords":true,"preferences_mi'
     'grated_to_basic":true,"site_settings":true,"time_period":4,"time_period_basic":4},"clear_lso_data_enabled":true'
     ',"has_seen_welcome_page":true,"last_clear_browsing_data_tab":1,"window_placement":{"bottom":720,"left":64,"maxi'
     'mized":true,"right":1200,"top":32}},"credentials_enable_autosignin":false,"credentials_enable_service":false,"d'
     'efault_apps_install_state":2,"download":{"directory_upgrade":true,"prompt_for_download":true},"enable_do_not_tr'
     'ack":true,"extensions":{"alerts":{"initialized":true},"ui":{"developer_mode":true}},"media":{"engagement":{"sch'
     'ema_version":4}},"net":{"network_prediction_options":2},"omnibox":{"prevent_url_elisions":true},"payments":{"ca'
     'n_make_payment_enabled":false},"profile":{"avatar_index":24,"block_third_party_cookies":true,"content_settings"'
     ':{"clear_on_exit_migrated":true,"pref_version":1},"default_content_setting_values":{"background_sync":2,"cookie'
     's":1},"exit_type":"Normal","exited_cleanly":true,"local_avatar_index":24,"managed_user_id":"","name":"","passwo'
     'rd_manager_enabled":false},"search":{"suggest_enabled":false}}'
   ) -join ''

   try {
      [IO.Directory]::CreateDirectory($profilePath) | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"

      # Saving Preferences and Local State data in UTF-8 encoding without BOM and without a newline at the end.
      $localState = Join-Path $profilePath "Local State"
      [System.IO.File]::WriteAllText($localState, $localStateContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\Local State"

      $preferences = Join-Path "$AppPath" "initial_preferences"
      [System.IO.File]::WriteAllText($preferences, $preferencesContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $AppDir\initial_preferences"
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
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
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

   # Creating a new profile
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

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
