<# :
:: The script creates a portable, auto updatable build of the SRWare Iron from scratch and then works as a launcher.
:: It checks for updates at a specified interval; after closing, it cleans the profile and the registry.
:: To use it, simply place the batch file in any empty folder (except for root, system, and restricted access folders)
:: and run it. The latest version is downloaded immediately, unpacked into a folder next to the batch file,
:: and the browser is launched. Updates are downloaded from the official website to a subfolder within
:: the batch file’s folder and are deleted after installation. You can select the browser’s bitness (x64/x86)
:: by specifying the required value in $Bitness. Portability is ensured by built-in tools. If you specify your
:: own profile in the --user-data-dir key, it will be used. Otherwise, a new one is created with a minimal
:: Local State. A folder called App (the name is customizable) is created next to the script; this is where
:: the build will be located. The folders, files, and startup keys to be deleted are added as a separate line
:: in double quotes; anything unnecessary is commented out/deleted. In the $SetupExclude variable, you can specify files
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
   "--disable-notifications"
   "--no-default-browser-check"
   "--no-first-run"
#   "--disk-cache-dir=nul"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
   "--show-component-extension-options"
#   "--disable-component-update"
#   "--disable-background-networking"
   "--disable-features=GlobalMediaControls"
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
#   "HKEY_CURRENT_USER\SOFTWARE\SRWare Iron"
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
   "Profile"
   "7za.dll"
   "howto_update.txt"
   "Iron_Backup_Config_Portable.exe"
   "IronPortable.exe"
   "Iron\7za.dll"
   "Iron\adblock.ini"
   "Iron\chrome_proxy.exe"
   "Iron\icon.txt"
   "Iron\Iron_Backup_Config.exe"
   "Iron\iron.exe"
   "Iron\license.txt"
   "Iron\master_preferences"
   "Iron\Locales\*FEMININE.pak"
   "Iron\Locales\*MASCULINE.pak"
   "Iron\Locales\*NEUTER.pak"
   "Iron\Locales\af.pak"
   "Iron\Locales\am.pak"
   "Iron\Locales\ar.pak"
   "Iron\Locales\ar-XB.pak"
   "Iron\Locales\as.pak"
   "Iron\Locales\az.pak"
   "Iron\Locales\be.pak"
   "Iron\Locales\bg.pak"
   "Iron\Locales\bn.pak"
   "Iron\Locales\bs.pak"
   "Iron\Locales\ca.pak"
   "Iron\Locales\cs.pak"
   "Iron\Locales\cy.pak"
   "Iron\Locales\da.pak"
   "Iron\Locales\de.pak"
   "Iron\Locales\el.pak"
   "Iron\Locales\en-GB.pak"
   "Iron\Locales\en-XA.pak"
   "Iron\Locales\es-419.pak"
   "Iron\Locales\es.pak"
   "Iron\Locales\et.pak"
   "Iron\Locales\eu.pak"
   "Iron\Locales\fa.pak"
   "Iron\Locales\fi.pak"
   "Iron\Locales\fil.pak"
   "Iron\Locales\fr-CA.pak"
   "Iron\Locales\fr.pak"
   "Iron\Locales\gl.pak"
   "Iron\Locales\gu.pak"
   "Iron\Locales\he.pak"
   "Iron\Locales\hi.pak"
   "Iron\Locales\hr.pak"
   "Iron\Locales\hu.pak"
   "Iron\Locales\hy.pak"
   "Iron\Locales\id.pak"
   "Iron\Locales\is.pak"
   "Iron\Locales\it.pak"
   "Iron\Locales\ja.pak"
   "Iron\Locales\ka.pak"
   "Iron\Locales\kk.pak"
   "Iron\Locales\km.pak"
   "Iron\Locales\kn.pak"
   "Iron\Locales\ko.pak"
   "Iron\Locales\ky.pak"
   "Iron\Locales\lo.pak"
   "Iron\Locales\lt.pak"
   "Iron\Locales\lv.pak"
   "Iron\Locales\mk.pak"
   "Iron\Locales\ml.pak"
   "Iron\Locales\mn.pak"
   "Iron\Locales\mr.pak"
   "Iron\Locales\ms.pak"
   "Iron\Locales\my.pak"
   "Iron\Locales\nb.pak"
   "Iron\Locales\ne.pak"
   "Iron\Locales\nl.pak"
   "Iron\Locales\or.pak"
   "Iron\Locales\pa.pak"
   "Iron\Locales\pl.pak"
   "Iron\Locales\pt-BR.pak"
   "Iron\Locales\pt-PT.pak"
   "Iron\Locales\ro.pak"
   "Iron\Locales\si.pak"
   "Iron\Locales\sk.pak"
   "Iron\Locales\sl.pak"
   "Iron\Locales\sq.pak"
   "Iron\Locales\sr-Latn.pak"
   "Iron\Locales\sr.pak"
   "Iron\Locales\sv.pak"
   "Iron\Locales\sw.pak"
   "Iron\Locales\ta.pak"
   "Iron\Locales\te.pak"
   "Iron\Locales\th.pak"
   "Iron\Locales\tr.pak"
   "Iron\Locales\uk.pak"
   "Iron\Locales\ur.pak"
   "Iron\Locales\uz.pak"
   "Iron\Locales\vi.pak"
   "Iron\Locales\zh-CN.pak"
   "Iron\Locales\zh-HK.pak"
   "Iron\Locales\zh-TW.pak"
   "Iron\Locales\zu.pak"
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

$BrowserName = "SRWare Iron $Bitness"

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
$Script:MutexName = "Global\IronPortable_$hash"

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
   try {
      Add-Type -Name Win -Namespace Native -MemberDefinition @'
         [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
         [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
         [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
'@ -ea 0
   } catch {
      Write-Host "$_.Exception.Message" @red
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
      'AAABAAEAGDAAAAEAIACICQAAFgAAACgAAAAYAAAAMAAAAAEAIAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMfH'
      'xy/e3t6A5uXmvOrp6uTs6+z25+fn9ODg4NzZ2dmrysrKX6mpqgsAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADHx8dF2trbxerq'
      '6v7v7/D/8vLy//Pz8//y8vL/7+/v/+rq6//k5OT/3d3e/9DQ0Oi+vr5imJiZAQAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAq6urDsnJyqXd3d3/5eTl/+vr'
      '6//w8PD/8/Pz//T09P/z8vP/7+/v/+np6v/j4uP/29rb/9LS0v/JyMn/uLi4oI2N'
      'jQQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACko6QaxcTF09PS0//a2tv/4uLi/+np'
      '6f/u7u//8vHy//Py8//x8PH/7ezt/+bm5//f3+D/1tbX/83Nzf/Dw8P/urq7/6ur'
      'q54AAAAAAAAAAAAAAAAAAAAAAAAAAJaWlg23t7jTxcTF/83Nzv/W1db/3d3e/+Tk'
      '5f/q6ur/7e3u/+7u7v/s7Oz/5+fo/+Hg4f/Z2dr/0NDQ/8bGxv+1tLX/paWl/6ys'
      'rP+bmptgAAAAAAAAAAAAAAAAAAAAAHhwa3Spp6X/vb2+/8bGxv/Pzs//1tbX/97d'
      '3v/j4+T/5+bn/+fm5//k5OT/4ODg/9nY2f/R0dL/yMjI/76+vv+enZ7/WFhY/5SU'
      'lf+cm5zrhISEEAAAAAAAAAAAWFRRCWdGJatSSkL0l5KQ/729vv/Gxcb/zs3O/9XU'
      '1f/a2tv/3t3e/97d3v/b29v/1tXW/8/Pz//Hx8j/vr6+/7W1tf+ZmJn/SUlK/1VV'
      'Vv+Pj4//ioqKewAAAAB0dHQClpWVqFc7IJKETxj/UkEv/3x1cf+3trX/w8PD/8vK'
      'y//R0dL/1dXV/9XV1f/R0dL/y8rL/8TDxP+8u7z/tLS0/6yrrP+Li4z/SkpK/0RE'
      'RP9gYGH/hoaG4mhpaQODg4NEkZGS/3d1c8B1RRPknVwW/3BKIf9VTET/npaR/8DA'
      'wP/Kysv/0M/Q/8/Pz//Kycr/wMDB/7m4uf+wsLH/qamq/6Kio/+GhYb/S0tL/0RE'
      'Rf9DQ0T/c3N0/2tqaz58fH2ZhYWF/5KRkf9NPi/FoF0U/7JpGP+raB3/YEMk/2db'
      'UP+0rab/0dHS/8/Oz//Gxsf/ubi5/6+ur/+mpab/np6f/5mYmf+BgYL/TExM/0VF'
      'Rv8+Pj7/T0hCz1VFNSZ1dXXWfX19/4CAgP9wbm3mfkwW3rtvGf/KeBv/14Ed/7x0'
      'Iv9xTSf/bWFV/6ylnv/IxcP/tra3/6emp/+cm5z/lJOU/4+Pj/95eXn/TUxN/0lE'
      'Qf9DOS/gYT0ZqVg4F45vb2/5dnV2/3d2d/+HhYX/Tz0qysJzGf/Vfxz/44ke//GS'
      'IP/8myL/5JIm/6JuKv9/Y0P/hHpw/5CIgv+If3f/eG9o/2xkXf9STEj/PzYv/0ky'
      'G/9lOhDvXTAF/04xFHJoaGj/cG9w/3BwcP96enr/WldU47NqF/3hhx3/8ZIf//2b'
      'Iv/+oiX//qgp//6tLP/+qSr/85kl/8yAJf+payX/kVwh/4RSG/+DThb/hEkN/3U+'
      'B/9pNwb/XzEF/0o/NFpcW1zxbGxs/29vcP9ycnP/YmFg/6pnGv/tjx3/+Zcg//6f'
      'JP/+pyj//q8t//65Nf//szD//qYo//iYIv/lih3/znoY/7dqFP+fWxH/ikwL/3lB'
      'CP9sOQb/UjER/FhYWN1QUFHBbW1t/25tbv94c2//TkY//8p4Gf/wkR7/+5kh//6h'
      'Jf/+qyr//rw3//7ORv//wTv//6ws//ybIv/qjR3/030Z/7xuFP+kXhH/kFAN/35E'
      'Cf9rOQj/SUI7/1NTU9pDPz1zZ19Z/19XUP9nVkX/l1wa/9J8GP/tjx3//Joh//6j'
      'Jf/+ry3//tJK//7rYf//1U3//rUy//2eI//tjx3/1n8Z/8BwFf+oYBH/lFMN/3pC'
      'CvxLOy3eSEhI/zs7O7hfUEMYZksy8YBNGf+gWxD/tmkT/815Fv/lihz/+pkh//6k'
      'Jv/+tTL//uxn//7+iv//6mL//r45//6hJP/wkR3/2YEZ/8NyFf+qYRH/c0EN91dJ'
      'O69TUlL8Pz8//zExMoUAAAAAUDggN2Q7EdeKTg7/smcS/8l2Ff/ghhr/9ZUf//6k'
      'Jv/+vzv//vqW//7+4///9nf//8Q///6iJf/wkR3/xnUW/49UEv9XORnyaGFa2Vtb'
      'W/5JSEn/QUFB/yYkIzoAAAAAAAAAAGNXTWtgUD/0c04m/4VQFP+fYBX/vXMZ/9KE'
      'H//cojT/38R8/9q+mP/Oq0z/vIQn/61vIf+XZCj/l3NM/4FvXf9kYmH+U1NT/1FR'
      'Uv9LS0v/RkA70ColIgEAAAAAAAAAAHppXhl4bGTXWFdY/3JsZv+JeWf/oopt/7ma'
      'dP+/mm3/wJho/8Sba//KpXn/17qX/869qv+YlJD/YWFi/0xMTf9ISEj/Tk5O/1NT'
      'VP9STkz9WEUzRQAAAAAAAAAAAAAAAAAAAACAbF4TdWRYt1tXVf9jY2T/kZCR/9/f'
      '3//+/v7//v7+//7+/v///////v7+/8/Oz/9/fn//WFdY/0lISf9EQ0T/SEhI/1ZU'
      'U/9bSTh+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANi4pAldGOXZmW1L5kI2L/9PS'
      '0//+/v7//v7+//7+/v///////f39/8DAwf95eXn/VFRV/0VFRf9AQED/RUE+9lZG'
      'N20AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbGRYpSjkqq5J6'
      'ZPu/s6j/29XP//Xz8f/9/f3/8vLz/62srf9zcXD/WFFN/0xCOv9AODG5STkrJgAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGpK'
      'LByFYD5th2VHrH5eQtiGaEzxim9V939kTOt3W0HJcFM3jjosIDcAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAD/gP8A/gA/APgADwDwAAcA4AAHAOAAAwDAAAMAgAABAIAA'
      'AQAAAAEAAAAAAAAAAQAAAAEAAAAAAAAAAACAAAAAgAAAAMAAAQDgAAEA4AADAPAA'
      'BwD8AA8A/gAfAP/AfwA='
   ) -join ''
   $memStream = $null
   try {
      $iconBytes = [Convert]::FromBase64String($iconBase64)
      $memStream = New-Object System.IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
      return [System.Drawing.Icon]::new($memStream)
   }
   catch {
      Write-Host "$_.Exception.Message" @red
      return [System.Drawing.SystemIcons]::Application.Clone()
   }
   finally {
      if ($memStream) {$memStream.Dispose()}
   }
}

# Create icon tray
Function New-TrayIcon {
   try {
      Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
      Add-Type -AssemblyName System.Drawing  -ErrorAction Stop
      
      $icon = Extract-IconFromBase64
      $Script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
      $Script:TrayIcon.Icon          = $icon
      $Script:TrayIcon.Visible       = $true
      $Script:TrayIcon.Text          = "$BrowserName launcher"
      $Script:TrayIcon.BalloonTipTitle = $BrowserName
   } catch {
      Write-Host "$_.Exception.Message" @red
      return
   }
}

# Windows notifications
Function Show-Balloon {
   param(
      [string]$Message,
      [string]$MessageType = 'Info'
   )

   if (-not $Script:TrayIcon) {
      Write-Host "$Message" @yellow
      return
   }

   try {
      $Script:TrayIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]$MessageType
      $Script:TrayIcon.BalloonTipText = $Message
      $Script:TrayIcon.ShowBalloonTip(10000)
   } catch {
      Write-Host "Balloon: $($_.Exception.Message)" @yellow
   }
}

# Move icon tray
Function Close-TrayIcon {
   if ($Script:TrayIcon) {
      try {
         $Script:TrayIcon.Visible = $false
         $Script:TrayIcon.Dispose()
      } catch {}
      $Script:TrayIcon = $null
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
      try {
         Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
         $Script:HttpClient = New-Object System.Net.Http.HttpClient
         $Script:HttpClient.Timeout = [TimeSpan]::FromSeconds(30)
         $Script:HttpClient.DefaultRequestHeaders.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      } catch {
         Write-Host "$_.Exception.Message" @red
      }
   }
   return $Script:HttpClient
}

# Network Request
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
   $Script:TrayIcon.Text = "Checking updates..."

   $Script:arch = if ($Bitness -eq 'x64') {'64'} else {$null}
   $url = 'https://www.srware.net/forum/viewforum.php?f=21'
   Write-Host "Request:   $url"

   try {
      $response = Make-NetRequest -Url $url
      if (-not $response) {throw 'HTTP-response is NULL'}
      $html = $response.Content.ReadAsStringAsync().Result
      if (-not $html) {throw 'HTTP-content is NULL'}
      $Script:latest = $html | Where-Object {$_ -match ".+version: (\d+\.\d+\.\d+\.\d+)"} | ForEach-Object {
         [version]$matches[1]} | Select-Object -First 1
      if (-not $latest) {throw 'latest is NULL'}
      $Script:distrLink = 'https://www.srware.net/downloads/IronPortable'+$arch+'.exe'
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
      $script:instmode = 'update'
      if ($AskUpdate) {
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
      Write-Host "New install"
      Show-Balloon -Message "v$latest start install..."
      $script:instmode = 'install'
      return $true
   }
}

# Form for the progress bar
Function Get-ProgressForm {
   param(
      [string]$Title
   )
   try {
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\instiron.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # Unpacker
      if (-not [IO.File]::Exists("$7zpath")) {
         if (Get-Command tar -ErrorAction SilentlyContinue) {
            $tar = $true
         } else {
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
      }
      Show-Balloon -Message "Unpack and copy files..."

      # Unpacking
      if ($tar) {
         &tar.exe -xf "$tmpdir\instiron.exe" -C "$tmpdir" | Out-Null
      } else {
         &($7zpath) x -aoa "$tmpdir\instiron.exe" -o"$tmpdir" | Out-Null
      }

      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }

      Write-Host "Unpack installer: OK" @green

      # List of files to save
      $nodel = @(
         (Split-Path $profilePath -Leaf)
         'debug.log'
         's.ini'
      )

      $SetupExclude | ForEach-Object {
         $excludePath = "$tmpdir\IronPortable$($arch)\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      if (-not [IO.Directory]::Exists($AppPath)) {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      Copy-Item -Path "$tmpdir\IronPortable$($arch)\*" -Destination $AppPath -Exclude 'Iron' -Recurse -Force
      Copy-Item -Path "$tmpdir\IronPortable$($arch)\Iron\*" -Destination $AppPath -Recurse -Force

      Get-ChildItem -Path $AppPath -Force -ea 0 | Where-Object {
         ($nodel -notcontains $_.Name) -and
         -not (Test-Path -LiteralPath (Join-Path "$tmpdir\IronPortable$($arch)" $_.Name)) -and
         -not (Test-Path -LiteralPath (Join-Path "$tmpdir\IronPortable$($arch)\Iron" $_.Name))
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

New-TrayIcon

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
      $Script:TrayIcon.Text = "Browser running"

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

   Close-TrayIcon
   Exit-SingleInstance
   if ($ShowConsole) {[void][Console]::ReadKey($true)}
}
