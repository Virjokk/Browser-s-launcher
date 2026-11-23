<# :
:: The script creates a portable, auto updatable build of the Firefox browser from scratch and then works as a launcher.
:: It checks for updates at a specified interval; after closing, it cleans the profile and the registry.
:: To use it, simply place the batch file in any empty folder (except for root, system, and restricted access folders)
:: and run it. The latest version is downloaded immediately, unpacked into a folder next to the batch file, and
:: the browser is launched. Updates are downloaded from the official website to a subfolder within the batch file’s
:: folder and are deleted after installation. You can select the browser edition (Stable, Beta, Developer, Nightly, ESR),
:: bitness (x64/x86), and language (en/ru).
:: Portability is ensured by the "three files" method (https://github.com/adonais/libportable).
:: To check/download updates and for the browser, you can use opera-proxy (https://github.com/Alexey71/opera-proxy),
:: which will be downloaded and launched with the specified parameters; it will auto update when new versions are released.
:: If the profile exists and its relative path is specified in $profileName, the browser will launch with this profile.
:: Otherwise, a new one is created with pre-settings from Insorg (https://forum.ru-board.com/topic.cgi?forum=2&topic=5924#1).
:: A Core folder (the name is customizable) is created next to the script, and the build will be located in it.
:: The folders, files, and launch keys to be deleted are added as a separate line in double quotes; anything
:: unnecessary is commented out/deleted. In the $SetupExclude variable, you can specify files and folders that
:: should be excluded from the browser during installation/update.

@echo off
cd /d "%~dp0"
set "Self=%~f0"
powershell.exe -NoP -NoL -NonI -EP Bypass -c "[ScriptBlock]::Create([IO.File]::ReadAllText($env:Self)).Invoke()"
exit /b
#>

# ============================================================================
# USER SETTINGS
# ============================================================================

$profileName = "..\Profile" # The profile folder name relative to portable.dll
$CheckInterval = 3 # The update check interval in days; if 0, it will check at each startup.
$CleanInterval = 7 # The interval for cleaning the profile and registry in days; if 0, it will be cleaned at each completion.
$RunMode = 0 # 0 - normal mode, 1 - launch only, 2 - update check/installation only.
$CreateShortcut = $false # Create a shortcut on the desktop.
$AskUpdate = $true # Ask before updating.
$Backup = $false # When updating, create a zip backup of the profile in the batch file folder.
$MakeStub = $false # Create zero-size stub files in place of the folders deleted in the profile ($DelDirs).
$Edition = 0 # 0 - Stable, 1 - Beta, 2 - Developer, 3 - Nightly, 4 - ESR
$Bitness = "x64" # For the 32-bit version, specify "x86".
$Language = "EN" # For the Russian language version, specify RU.
$AppDir = "Core" # The build folder is created in the same folder as the script.
$7zpath = "" # The local path to 7zr.exe or 7z.exe; if left empty, it will be downloaded from github.com.
$DllPath = "" # The local path to chrome-windows-x86/x64.zip or setdll.7z; if left empty, it will be downloaded from github.com.
$SqlVacuum = $false # Used sqlite3.exe for compress sql-files in profile.
$SqlPath = "" # The local path to sqlite3.exe, if empty and $SqlVacuum = $true, it will be downloaded from github.com.
$UseProxy = 0 # 0 - do not include, 1 - only for the browser, 2 - for the browser and for checking/downloading updates
$ProxyPath = "" # The local path to the Opera Proxy; if left empty, it will be downloaded from github.com (if $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18083","-verbosity 30" # Proxy parameters
$ShowConsole = $false # Show the console at startup to monitor errors.

$Switches = @( # browser launch keys
   "-no-remote"
)

$DelDirs = @( # Profile folders that are deleted after the browser is closed.
   "AppData\Mozilla\Firefox\Crash Reports"
   "AppData\Mozilla\Firefox\Pending Pings"
   "bookmarkbackups"
   "Cache*"
   "crashes"
   "datareporting"
   "jumpListCache"
   "LocalAppData\Temp\Fx\*"
   "minidumps"
   "safebrowsing"
   "saved-telemetry-pings"
   "security_state"
   "shader-cache"
   "startupCache"
   "storage\default\*"
   "storage\permanent\*"
   "thumbnails"
)

$ExcludeDirs = @( # folders that cannot be deleted
   "storage\default\app"
   "storage\default\chrome"
   "storage\default\data"
   "storage\default\file+++UNIVERSAL_FILE_URI_ORIGIN"
   "storage\default\http+++192.168.1.1"
   "storage\default\http+++192.168.0.1"
   "storage\default\https+++4pda.to"
   "storage\default\https+++forum.mozilla-russia.org"
   "storage\default\https+++forum.ru-board.com"
   "storage\default\https+++rutracker.org"
   "storage\default\https+++web.telegram.org"
   "storage\default\https+++www.aliexpress.com"
   "storage\default\https+++www.ebay.com"
   "storage\default\https+++www.epicgames.com"
   "storage\default\https+++www.farmanager.com"
   "storage\default\https+++www.google.com"
   "storage\default\https+++www.ixbt.com"
   "storage\default\moz-extension+++*"
   "storage\permanent\moz-extension+++*"
)

$DelFiles = @( # Profile files that are deleted after the browser is closed.
   "*.log"
   "*-journal"
   "*-shm"
   "*.txt"
   "*-wal"
   "activity-stream*"
   "parent.lock"
)

$DelReg = @( # Registry data that is deleted after the browser is closed.
   "HKEY_CURRENT_USER\SOFTWARE\Mozilla\Firefox"
)

$NoStub = @( # Folders for which stub files will not be created
   "datareporting"
   "minidumps"
)

$SetupExclude = @( # Folders and files excluded during installation/update
   "desktop-launcher"
   "installation_dir_layout"
   "uninstall"
   "AccessibleMarshal.dll"
   "crashhelper.exe"
   "crashreporter.exe"
   "crashreporter.ini"
   "default-browser-agent.exe"
   "firefox.exe.sig"
   "firefox.VisualElementsManifest.xml"
   "InstallationDirLayout.dll"
   "maintenanceservice.exe"
   "maintenanceservice_installer.exe"
   "minidump-analyzer.exe"
   "notificationserver.dll"
   "pingsender.exe"
   "plugin-container.exe.sig"
   "precomplete"
   "private_browsing.VisualElementsManifest.xml"
   "removed-files"
   "update-settings.ini"
   "updater.exe"
   "updater.ini"
   "webcompat-reporter@mozilla.org.xpi"
   "xul.dll.sig"
)

$Trash = @( # Folders and files outside the profile that should be deleted after closing the browser.
   "$env:ProgramData\Mozilla*"
   "$env:AppData\Mozilla"
   "$env:LocalAppData\Mozilla"
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$lastcheck = "18032026"
$lastclean = "18032026"
$sha256local = ""

$scriptName = $env:Self
$scriptPath = Split-Path -Path $scriptName -Parent

if (-not $AppDir) {$AppDir = 'Core'}
$AppPath = Join-Path $scriptPath $AppDir

if ($Bitness -ne 'x86') {$Bitness = 'x64'}
if ($language -eq 'en') {$language = 'EN'} else {$language = 'RU'}

$BrowserName = $(switch ($Edition) {
   1 {'Firefox Beta'}
   2 {'Firefox Developer'}
   3 {'Firefox Nightly'}
   4 {'Firefox ESR'}
   default {'Firefox'}
})+" $Bitness"+" $language"

$ExeName = 'firefox.exe'

if (-not $ProxyPath) {$ProxyPath = "$scriptPath\opera-proxy.windows-amd64.exe"}

if (-not $SqlPath) {$SqlPath = "$scriptPath\sqlite3.exe"}

if ($profileName) {
   $profilePath = [IO.Path]::GetFullPath([IO.Path]::Combine($AppPath, $profileName))
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
$Script:MutexName = "Global\FirefoxPortable_$hash"

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
      'AAABAAEAECAAAAEAIAAoBQAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAUA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcQvlYG0M479qDeL/'
      'aA7h/2kO4f9tDeP/cAvlr3QK52AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABx'
      'C+UQbQzjv2MT4v9YIu3/Uirz/00x+v9LM/v/TC72/1Mm8P9iF+n/bBLrv2se'
      '8BAAAAAAAAAAAAAAAAByCuUQbA3jz1ki7v9OMvz/STb+/0U5//9DPf//QUH/'
      '/z9D//8+Rf//QET9/1I28/9hOPPPYU33EAAAAAAAAAAAbQ/mv1Ms9/9JNv7/'
      'RDv//0FB//89R///O0v//zhP//83Uv//NVX//zZd//85a///TWH3/1ti+K8A'
      'AAAAcwrmQFkj8v9FOf//QUH//z1I//8xY///XlfB/4dFjf+JQ4//UlHZ/zNj'
      '//8zdf//NIb//zeS//9Rfvr/Von8QGUY7Z9EPP//P0X//zpN//8sbf//d2KX'
      '/7ZBWP/ASlr/xEVj/8I2cP9iY83/M4j//zyM/v81qP//Q6P9/1Kd/Z9KNvu/'
      'PUf//zdR//8yWv//Ooni/7w+Yf/PUmH/21pm/+BVcv/cRH//wTeN/ymr//86'
      'n///QqX+/z28/v9PsP6/Sjn5/zdS//8wXf//Kmf//ymo9v+9VIX/51h2//Je'
      'ff/2V4j/7UqQ/9c3kf8swv//Nbn//0qm//88zv//TMT+vztN/c8wXf//I33/'
      '/xyr//8jtv//K8D//2Ov4f+zhrz/+FGc/+9IoP/ITKr/NtD//zvE//9HvP//'
      'RtD//0nV/r8wXf+vKmj//xyN//8dpf//IK3//x2t//8jtf//XaPr/9dUuf/g'
      'S7T/Xr/v/z3Y//8/yv//Rs3//0jY//9F3P+vKmj/YCRy//8cgP//FY3//xOd'
      '//8opPr/tVrE/+k+uP/oPLv/zk69/3Gh4v860///Qdf//0bZ//9I2///ReH/'
      'YAAAAAAefP/fFor//xqU/+8rmv//R5X2j942sI/AWcXfpHTQ/3yg4P8+2///'
      'QN7//0Lf//9G3f//S+L/30jj/xAAAAAAGIb/MBSZ/+8Xpf9gO57/jzu0/4AA'
      'AAAANc7/QDjT//9A3///Reb//0Xm//9D4v//SuL/j0/m/zAAAAAAAAAAAAAA'
      'AAAaqP8wHq7/IAAAAAAAAAAAAAAAAAAAAABB4f/vSOr//0rt//9I6f//ReX/'
      'YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'SOr/cEzv//9M8P//Sez/jwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAABN8f+PTfH/3wAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
   ) -join ''
   if ($Edition -in 1..3) {$IconBase64=@(
      'AAABAAEAECAAAAEAIAAoBQAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAUA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA2GgDYNJeBL/OWQb/'
      'zl4J/89eCP/UZQn/2GsKr+OEE2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADb'
      'cAIQ1WYEv81bBv/WZQT/22sD/+J0Af/jdgH/3XEC/9hrA//VaAb/4YERv+mV'
      'GhAAAAAAAAAAAAAAAADddAIQ02UEz9lqBP/ldwD/5XkA/+Z8AP/nfwD/6IEA'
      '/+iDAP/ohQD/54UB/9x3BP/jixPP7qckEAAAAAAAAAAA3HYDv+N8BP/megD/'
      '534A/+iCAP/ohQD/6YgA/+uRB//qjQD/65AA/+yTAf/tlgL/4ogH/+ylI68A'
      'AAAA4H0BQOKABv/mfgH/6IIA/+mGAP/unxr/xncd/6NVJv+oWCz/144h//Ks'
      'HP/xqBT/8KIF//ClCf/pnxv/9cE+QOePB5/ohgT/6IQA/+qJAP/wqCX/r25E'
      '/48tNP+SLjT/kDAw/40xK//OjCb/8q0S//S+MP/zsxP/76wb//XERJ/vog+/'
      '6IUA/+qMAP/skgD/5blj/48uM/+fMzr/pTc6/6c6Nv+iOjD/nkIq//jHIf/x'
      'tyX/8Lo3//W+KP/0wka/7qAM/+qMAP/skwD/7pkA//fbfv+qS0P/qTg5/75F'
      'Of/CTDL/u0su/6dAJ//93Dr/9scy/+utNf/60Ur/9clPv++iDd/skwD/9Lc3'
      '//3hd//83WL//uZ7/+zAev/dkmb/z1os/8pZJf/DYjL//+VK//jMTP/xtDj/'
      '+dFa//jTV7/ztSyv7poA//fJUv/61V3/+tZb//jLPP/5yzf/9b5O/+J2KP/V'
      'byj/89SL//7kc//3wz//98BA//nUX//84W6v+dFXYPGnDP/xqAD/87AA//W1'
      'Af/1vx//3How/99rGv/fdRD/2n4r/+yuTP/4yDj/+ctA//nJQP/73Gr//uuJ'
      'YAAAAAD4yUff868A//fFOO/1uC3/9MFKj9p/FoDhjBff6qAa//O4Jv/70zj/'
      '/NZA//vUQP/70kb//uyY3/7tkxAAAAAA/OJ+MPnMP+/95YJg+MVIj/zbb4AA'
      'AAAA/uqEQP3XLv/92Dj//+JA//7fQP/93ED//eR5j/7upDAAAAAAAAAAAAAA'
      'AAD+6pYw/uqXIAAAAAAAAAAAAAAAAAAAAAD/6Wrv/+RI///mUf//5Un//+NB'
      'YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      '//ChcP/qcP//6Wj//+hgjwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/8rGP/+2J3wAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
      ) -join ''
   }
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

# The bitness of the executable file
Function Get-Bitness {
   param(
      [string]$ExeFile
   )
   if (-not [IO.File]::Exists($ExeFile)) {return $false}
   try {
      $fs = [IO.File]::OpenRead($ExeFile)
      try {
         $br = New-Object IO.BinaryReader($fs)

         if ($br.ReadUInt16() -ne 0x5A4D) {return $false}

         $fs.Position = 0x3C
         $peOffset = $br.ReadInt32()
         if ($peOffset -le 0 -or ($peOffset + 6) -gt $fs.Length) {return $false}

         $fs.Position = $peOffset
         if ($br.ReadUInt32() -ne 0x00004550) {return $false}

         $fs.Position = $peOffset + 4
         switch ($br.ReadUInt16()) {
             0x8664 { return '64' }
             0x14C  { return '32' }
             default { return $false }
         }
      } finally {$fs.Dispose()}
   } catch {
       Write-Host "$_.Exception.Message" @red
       return $false
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
   $Script:TrayIcon.Text = "Checking updates..."

   $lang = if ($Language -ne 'ru') {'en-US'} else {'ru'}
   $arch = if ($Bitness -ne 'x86') {'64'} else {$null}

   $product = switch ($Edition) {
      1 {'beta-'}
      2 {'devedition-'}
      3 {'nightly-'; $repo = 'l10n-'}
      4 {'esr-'}
      default {''}
   }
   $url = 'https://download.mozilla.org/?product=firefox-'+$product+'latest-'+$repo+'ssl&os=win'+$arch+'&lang='+$lang

   Write-Host "Request:   $url"

   try {
      $response = Make-NetRequest -Url $url
      if (-not $response) {throw 'HTTP-response is NULL'}
      $rawlink = $response.RequestMessage.RequestUri.AbsoluteUri
      $Script:distrLink = $rawlink -replace '.+(?=/pub/)','https://ftp.mozilla.org'
      if (-not $distrLink) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   } finally {
      if ($response) {$response.Dispose()}
   }

   Write-Host "Redirect:  $distrLink"

   if ($Edition -eq 3) {
      $crcfile = $distrLink -replace '\.installer\.exe$','.checksums'
      try {
         $response = Make-NetRequest -Url $crcfile
         if ($response.Content.ReadAsStringAsync().Result -match "(\w{64}) sha256.+installer\.exe") {
            $script:sha256remote = $matches[1]
         } else {
            throw 'Error parsing crc-file'
         }
         if ($distrLink -match '.+/firefox-([\w\.]+?)\.\D+\..+') {$Script:latest = $matches[1]}
      } catch {
         Write-Host "$_.Exception.Message" @red
         Show-Balloon -Message "Error check CRC-file" -MessageType "Error"
         $Script:checkError = $true
         return $false
      } finally {
         if ($response) {$response.Dispose()}
      }
   } else {
      if ($distrLink -match '.+releases/(.+)/win.+') {$Script:latest = $matches[1]}
   }

   if (-not $latest) {
      Show-Balloon -Message "Error parsing version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   $Script:latestCompare = $latest + @(if ($Edition -eq 3) {" SHA256 $sha256remote"})
   Write-Host "Latest:    v$latestCompare"

   return $true
}

# Version comparison
Function Check-NewVersion {
   if (-not (Get-LatestVersion)) {return $false}

   Set-FileVar -Name "lastcheck" -Value $(Get-Date -Format 'ddMMyyyy')

   try {
      $Script:current = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\$ExeName").FileVersion
   } catch {
      $Script:current = $null
   }

   $currentCompare = $current + @(if ($Edition -eq 3) {" SHA256 $sha256local"})

   if ($latestCompare -eq $currentCompare) {
      Write-Host "Installed: v$currentCompare - no update required"
      return $false
   } elseif ($current -ne $null) {
      Write-Host "Installed: v$currentCompare - update is available"
      if ($latest -eq $current) {$crc = ' - SHA256 changed'}
   } else {
      Write-Host "New install"
   }

   if ([IO.File]::Exists("$AppPath\$ExeName")) {
      $script:instmode = 'update'
      if ($AskUpdate) {
         $query = "$BrowserName v$latest is new version$crc, update?"; $title = "Current v$current"
         if ([System.Windows.Forms.MessageBox]::Show($query,$title,4,32) -like 'Yes') {
            return $true
         } else {
            $Script:checkError = $true
            return $false
         }
      } else {
         Show-Balloon -Message "v$latest is new version$crc, start update..."
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\ff.exe" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      # portable.dll
      $dllbit = if ($Bitness -ne 'x86') {'64'} else {'32'}
      if (-not [IO.File]::Exists("$($AppPath)\portable$($dllbit).dll")) {
         if (-not [IO.File]::Exists("$DllPath")) {
            $DllPath = "$tmpdir\portable_bin.7z"
            $dllUrl = 'https://github.com/adonais/libportable/releases/latest/download/portable_bin.7z'
            if (-not (Download-File -Source $dllUrl -Dest $DllPath)) {throw}
            Write-Host "Download portable_bin.7z: OK" @green
         }
         $dllUnpack = $true
      }

      # sqlite
      if ($SqlVacuum -and -not [IO.File]::Exists($SqlPath)) {
         $sqlsite = "https://sqlite.org/download.html"
         try {
            $response = Make-NetRequest -Url $sqlsite
            if (-not $response) {throw 'HTTP-response is NULL'}
            $sqlhtml = $response.Content.ReadAsStringAsync().Result
            if ($sqlhtml -match 'product,[\d\.]+,(\S*s-win-x64\S*\.zip)') {
               $sqllink = "https://sqlite.org/$($matches[1])"
               Write-Host "Sqlite link: $sqllink" @darkcyan
            } else {
               throw 'Sqlite link not found on page'
            }
         } catch {
            Write-Host "$_.Exception.Message" @red
         } finally {
            if ($response) {$response.Dispose()}
         }
         if ($sqllink) {
            $sqldest = "$tmpdir\sql.zip"
            if (Download-File -Source $sqllink -Dest $sqldest) {
               Write-Host "Download sqlite: OK" @green
            } else {
               Write-Host "Error download sqlite" @red
               $sqldest = $null
            }
         }
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Unpacking
      &($7zpath) x -t7z -aoa "$tmpdir\ff.exe" "core\" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      if ($dllUnpack) {
         &($7zpath) e -t7z -aoa "$DllPath" $("portable"+$dllbit+".dll") -o"$tmpdir\core" | Out-Null
         if ($LASTEXITCODE -ne 0) {
            Show-Balloon -Message "Error unpack portable_bin.7z" -MessageType "Error"
            throw 'Error unpack portable_bin.7z'
         }
         Write-Host "Unpack portable_bin.7z: OK" @green
      }

      if ($sqldest) {
         try {
            Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::ExtractToDirectory($sqldest, $tmpdir)
            Move-Item -Path "$tmpdir\sqlite3.exe" -Destination $SqlPath -Force
            Write-Host "Unpack sqlite: OK" @green
         } catch {
            Write-Host "Error unpack sqlite" @red
         }
      }

      # List of files to save
      $nodel = @(
         (Split-Path $profilePath -Leaf)
         (Split-Path $ProxyPath -Leaf)
         'autoconfiglocal.js'
         'defaults'
         'distribution'
         'portable.ini'
         "portable$($dllbit).dll"
      )

      $SetupExclude | ForEach-Object {
         Get-Item -Path "$tmpdir\core\$_" -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      if (-not [IO.Directory]::Exists($AppPath)) {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      Copy-Item -Path "$tmpdir\core\*" -Destination $AppPath -Recurse -Force

      Get-ChildItem -Path $AppPath -Force -ea 0 | Where-Object {
         ($nodel -notcontains $_.Name) -and
         -not (Test-Path -LiteralPath (Join-Path "$tmpdir\core" $_.Name))
      } | Remove-Item -Recurse -Force -ea 0

      Write-Host "Update files in $($AppPath): OK" @green

      Get-Item -Path "$scriptPath\*_backup_*.zip" -ea 0 |
         Sort-Object LastWriteTime -Descending |
         Select-Object -skip 2 | ForEach-Object {
         $_.Delete()
      }

      if ($sha256remote) {
         Set-FileVar -Name "sha256local" -Value $sha256remote
      } else {
         if ($sha256local -and $Edition -ne 3) {
            Set-FileVar -Name "sha256local" -Value ""
         }
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
   $aclocalContent = @(
      '// Mozilla User Preferences'
      ''
      'defaultPref("accessibility.blockautorefresh", true);'
      'defaultPref("accessibility.handler.enabled", false);'
      'defaultPref("accessibility.typeaheadfind", true);'
      'defaultPref("accessibility.typeaheadfind.flashBar", 0);'
      'defaultPref("alerts.disableSlidingEffect", true);'
      'defaultPref("app.normandy.api_url", "");'
      'defaultPref("app.normandy.enabled", false);'
      'defaultPref("app.normandy.first_run", false);'
      'defaultPref("app.shield.optoutstudies.enabled", false);'
      'defaultPref("app.support.e10sAccessibilityUrl", "");'
      'defaultPref("app.update.auto", false);'
      'defaultPref("app.update.checkInstallTime", false);'
      'defaultPref("app.update.disable_button.showUpdateHistory", false);'
      'defaultPref("app.update.enabled", false);'
      'defaultPref("app.update.migrated.updateDir", true);'
      'defaultPref("app.update.service.enabled", false);'
      'defaultPref("app.update.url", "");'
      'defaultPref("app.update.url.details", "");'
      'defaultPref("app.update.url.manual", "");'
      'defaultPref("beacon.enabled", false);'
      'defaultPref("breakpad.reportURL", "");'
      'defaultPref("browser.aboutConfig.showWarning", false);'
      'defaultPref("browser.bookmarks.restore_default_bookmarks", false);'
      'defaultPref("browser.bookmarks.showRecentlyBookmarked", false);'
      'defaultPref("browser.cache.disk.capacity", 0);'
      'defaultPref("browser.cache.disk.enable", false);'
      'defaultPref("browser.cache.disk.smart_size.enabled", false);'
      'defaultPref("browser.cache.disk.smart_size.first_run", false);'
      'defaultPref("browser.cache.disk_cache_ssl", false);'
      'defaultPref("browser.cache.memory.capacity", -1);'
      'defaultPref("browser.cache.offline.enable", false);'
      'defaultPref("browser.cache.offline.insecure.enable", false);'
      'defaultPref("browser.cache.offline.storage.enable", false);'
      'defaultPref("browser.ctrlTab.recentlyUsedOrder", false);'
      'defaultPref("browser.customizemode.tip0.shown", true);'
      'defaultPref("browser.defaultbrowser.notificationbar", false);'
      'defaultPref("browser.display.windows.non_native_menus", 0);'
      'defaultPref("browser.download.animateNotifications", false);'
      'defaultPref("browser.download.autohideButton", true);'
      'defaultPref("browser.download.forbid_open_with", true);'
      'defaultPref("browser.download.hide_plugins_without_extensions", false);'
      'defaultPref("browser.download.importedFromSqlite", true);'
      'defaultPref("browser.download.manager.addToRecentDocs", false);'
      'defaultPref("browser.download.panel.shown", true);'
      'defaultPref("browser.download.useDownloadDir", false);'
      'defaultPref("browser.eme.ui.enabled", false);'
      'defaultPref("browser.feeds.showFirstRunUI", false);'
      'defaultPref("browser.fixup.alternate.enabled", false);'
      'defaultPref("browser.formautofill.enabled", false);'
      'defaultPref("browser.formfill.enable", false);'
      'defaultPref("browser.fullscreen.animate", false);'
      'defaultPref("browser.fullscreen.animateUp", 0);'
      'defaultPref("browser.history_swipe_animation.disabled", true);'
      'defaultPref("browser.in-content.dark-mode", false);'
      'defaultPref("browser.link.open_newwindow.disabled_in_fullscreen", true);'
      'defaultPref("browser.link.open_newwindow.override.external", 0);'
      'defaultPref("browser.link.open_newwindow.restriction", 0);'
      'defaultPref("browser.menu.showCharacterEncoding", "false");'
      'defaultPref("browser.messaging-system.whatsNewPanel.enabled", false);'
      'defaultPref("browser.newtab.preload", false);'
      'defaultPref("browser.newtabpage.activity-stream.discoverystream.enabled", false);'
      'defaultPref("browser.newtabpage.activity-stream.discoverystream.endpointSpocsClear", "");'
      'defaultPref("browser.newtabpage.activity-stream.discoverystream.endpoints", "");'
      'defaultPref("browser.newtabpage.activity-stream.enabled", false);'
      'defaultPref("browser.newtabpage.activity-stream.feeds.section.highlights", false);'
      'defaultPref("browser.newtabpage.activity-stream.feeds.snippets", false);'
      'defaultPref("browser.newtabpage.activity-stream.feeds.system.topsites", false);'
      'defaultPref("browser.newtabpage.activity-stream.feeds.telemetry", false);'
      'defaultPref("browser.newtabpage.activity-stream.feeds.topsites", false);'
      'defaultPref("browser.newtabpage.activity-stream.filterAdult", false);'
      'defaultPref("browser.newtabpage.activity-stream.fxaccounts.endpoint", "");'
      'defaultPref("browser.newtabpage.activity-stream.hideTopSitesTitle", true);'
      'defaultPref("browser.newtabpage.activity-stream.migrationExpired", true);'
      'defaultPref("browser.newtabpage.activity-stream.prerender", false);'
      'defaultPref("browser.newtabpage.activity-stream.section.highlights.includeBookmarks", false);'
      'defaultPref("browser.newtabpage.activity-stream.section.highlights.includeDownloads", false);'
      'defaultPref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);'
      'defaultPref("browser.newtabpage.activity-stream.section.highlights.includeVisited", false);'
      'defaultPref("browser.newtabpage.activity-stream.showSearch", true);'
      'defaultPref("browser.newtabpage.activity-stream.showSponsored", false);'
      'defaultPref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);'
      'defaultPref("browser.newtabpage.activity-stream.showTopSites", true);'
      'defaultPref("browser.newtabpage.activity-stream.telemetry", false);'
      'defaultPref("browser.newtabpage.activity-stream.telemetry.ping.endpoint", "");'
      'defaultPref("browser.newtabpage.activity-stream.telemetry.structuredIngestion", false);'
      'defaultPref("browser.newtabpage.activity-stream.telemetry.structuredIngestion.endpoint", "");'
      'defaultPref("browser.newtabpage.activity-stream.topSitesRows", 4);'
      'defaultPref("browser.newtabpage.directory.ping", "");'
      'defaultPref("browser.newtabpage.directory.source", "");'
      'defaultPref("browser.newtabpage.enabled", false);'
      'defaultPref("browser.newtabpage.pinned", "[]");'
      'defaultPref("browser.newtabpage.storageVersion", 1);'
      'defaultPref("browser.partnerlink.attributionURL", "");'
      'defaultPref("browser.ping-centre.production.endpoint", "");'
      'defaultPref("browser.ping-centre.staging.endpoint", "");'
      'defaultPref("browser.ping-centre.telemetry", false);'
      'defaultPref("browser.places.importBookmarksHTML", false);'
      'defaultPref("browser.places.smartBookmarksVersion", 7);'
      'defaultPref("browser.pocket.enabled", false);'
      'defaultPref("browser.privacySegmentation.createdShortcut", true);'
      'defaultPref("browser.privatebrowsing.autostart", false);'
      'defaultPref("browser.privatebrowsing.enable-new-indicator", false);'
      'defaultPref("browser.region.network.url", "");'
      'defaultPref("browser.region.update.enabled", false);'
      'defaultPref("browser.rights.3.shown", true);'
      'defaultPref("browser.safebrowsing.allowOverride", false);'
      'defaultPref("browser.safebrowsing.appRepURL", "");'
      'defaultPref("browser.safebrowsing.blockedURIs.enabled", false);'
      'defaultPref("browser.safebrowsing.downloads.enabled", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.block_dangerous", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.block_dangerous_host", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.block_uncommon", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.enabled", false);'
      'defaultPref("browser.safebrowsing.downloads.remote.url", "");'
      'defaultPref("browser.safebrowsing.enabled", false);'
      'defaultPref("browser.safebrowsing.gethashURL", "");'
      'defaultPref("browser.safebrowsing.malware.enabled", false);'
      'defaultPref("browser.safebrowsing.malware.reportURL", "");'
      'defaultPref("browser.safebrowsing.passwords.enabled", false);'
      'defaultPref("browser.safebrowsing.phishing.enabled", false);'
      'defaultPref("browser.safebrowsing.provider.google.advisoryName", "");'
      'defaultPref("browser.safebrowsing.provider.google.advisoryURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.appRepURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.gethashURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.reportMalwareMistakeURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.reportPhishMistakeURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.reportURL", "");'
      'defaultPref("browser.safebrowsing.provider.google.updateURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.advisoryName", "");'
      'defaultPref("browser.safebrowsing.provider.google4.advisoryURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.dataSharingURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.gethashURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.reportMalwareMistakeURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.reportPhishMistakeURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.reportURL", "");'
      'defaultPref("browser.safebrowsing.provider.google4.updateURL", "");'
      'defaultPref("browser.safebrowsing.provider.mozilla.gethashURL", "");'
      'defaultPref("browser.safebrowsing.provider.mozilla.lastupdatetime", "");'
      'defaultPref("browser.safebrowsing.provider.mozilla.nextupdatetime", "");'
      'defaultPref("browser.safebrowsing.provider.mozilla.updateURL", "");'
      'defaultPref("browser.safebrowsing.reportErrorURL", "");'
      'defaultPref("browser.safebrowsing.reportGenericURL", "");'
      'defaultPref("browser.safebrowsing.reportMalwareErrorURL", "");'
      'defaultPref("browser.safebrowsing.reportMalwareMistakeURL", "");'
      'defaultPref("browser.safebrowsing.reportMalwareURL", "");'
      'defaultPref("browser.safebrowsing.reportPhishMistakeURL", "");'
      'defaultPref("browser.safebrowsing.reportPhishURL", "");'
      'defaultPref("browser.safebrowsing.reportURL", "");'
      'defaultPref("browser.safebrowsing.updateURL", "");'
      'defaultPref("browser.search.geoip.url", "");'
      'defaultPref("browser.search.geoSpecificDefaults", false);'
      'defaultPref("browser.search.geoSpecificDefaults.url", "");'
      'defaultPref("browser.search.reset.enabled", false);'
      'defaultPref("browser.search.reset.whitelist", "");'
      'defaultPref("browser.search.serpEventTelemetryCategorization.enabled", false);'
      'defaultPref("browser.search.suggest.enabled", false);'
      'defaultPref("browser.search.suggest.enabled.private", false);'
      'defaultPref("browser.search.update", false);'
      'defaultPref("browser.search.update.log", false);'
      'defaultPref("browser.search.widget.inNavBar", true);'
      'defaultPref("browser.selfsupport.url", "");'
      'defaultPref("browser.sessionhistory.max_entries", 128);'
      'defaultPref("browser.sessionstore.max_tabs_undo", 32);'
      '// defaultPref("browser.sessionstore.restore_tabs_lazily", false);'
      '// defaultPref("browser.sessionstore.restore_on_demand", false);'
      'defaultPref("browser.sessionstore.warnOnQuit", true);'
      'defaultPref("browser.shell.checkDefaultBrowser", false);'
      'defaultPref("browser.shopping.experience2023.active", false);'
      'defaultPref("browser.shopping.experience2023.ads.enabled", false);'
      'defaultPref("browser.shopping.experience2023.ads.userEnabled", false);'
      'defaultPref("browser.shopping.experience2023.enabled", false);'
      'defaultPref("browser.shopping.experience2023.optedIn", 0);'
      'defaultPref("browser.shopping.experience2023.survey.enabled", false);'
      'defaultPref("browser.shopping.experience2023.survey.hasSeen", false);'
      'defaultPref("browser.shopping.experience2023.survey.pdpVisits", 0);'
      'defaultPref("browser.slowStartup.averageTime", 0);'
      'defaultPref("browser.slowStartup.notificationDisabled", true);'
      'defaultPref("browser.slowStartup.samples", 0);'
      'defaultPref("browser.startup.blankWindow", false);'
      'defaultPref("browser.startup.homepage", "about:newtab");'
      'defaultPref("browser.startup.homepage_override.mstone", "ignore");'
      'defaultPref("browser.startup.page", 3);'
      'defaultPref("browser.suppress_first_window_animation", false);'
      'defaultPref("browser.tabs.animate", false);'
      'defaultPref("browser.tabs.closeWindowWithLastTab", false);'
      'defaultPref("browser.tabs.crashReporting.sendReport", false);'
      'defaultPref("browser.tabs.firefox-view", false);'
      'defaultPref("browser.tabs.loadInBackground", false);'
      'defaultPref("browser.tabs.maxOpenBeforeWarn", 10);'
      'defaultPref("browser.tabs.tabMinWidth", 40);'
      'defaultPref("browser.taskbar.previews.enable", true);'
      'defaultPref("browser.theme.dark-private-windows", false);'
      'defaultPref("browser.topsites.contile.enabled", false);'
      'defaultPref("browser.toolbarbuttons.introduced.pocket-button", true);'
      'defaultPref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"save-to-pocket-button\",\"downloads-button\",\"fxa-toolbar-menu-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"developer-button\"],\"dirtyAreaCache\":[\"nav-bar\",\"PersonalToolbar\",\"TabsToolbar\",\"toolbar-menubar\"],\"currentVersion\":19,\"newElementCount\":3}");'
      'defaultPref("browser.uidensity", 1);'
      'defaultPref("browser.uitour.enabled", false);'
      'defaultPref("browser.urlbar.formatting.enabled", false);'
      'defaultPref("browser.urlbar.oneOffSearches", false);'
      'defaultPref("browser.urlbar.scotchBonnet.enableOverride", false);'
      'defaultPref("browser.urlbar.searchSuggestionsChoice", false);'
      'defaultPref("browser.urlbar.suggest.searches", false);'
      'defaultPref("browser.urlbar.suggest.topsites", false);'
      'defaultPref("browser.urlbar.trimURLs", false);'
      'defaultPref("browser.urlbar.update1", false);'
      'defaultPref("browser.urlbar.weather.featureGate", false);'
      'defaultPref("browser.vpn_promo.enabled", false);'
      'defaultPref("camera.control.face_detection.enabled", false);'
      'defaultPref("canvas.capturestream.enabled", false);'
      'defaultPref("captivedetect.canonicalURL", "");'
      'defaultPref("datareporting.healthreport.about.reportUrl", "");'
      'defaultPref("datareporting.healthreport.about.reportUrlUnified", "");'
      'defaultPref("datareporting.healthreport.documentServerURI", "");'
      'defaultPref("datareporting.healthreport.infoURL", "");'
      'defaultPref("datareporting.healthreport.service.enabled", false);'
      'defaultPref("datareporting.healthreport.service.firstRun", true);'
      'defaultPref("datareporting.healthreport.uploadEnabled", false);'
      'defaultPref("datareporting.policy.dataSubmissionEnabled", false);'
      'defaultPref("datareporting.policy.dataSubmissionEnabled.v2", false);'
      'defaultPref("datareporting.policy.firstRunURL", "");'
      'defaultPref("default-browser-agent.enabled", false);'
      'defaultPref("device.sensors.enabled", false);'
      'defaultPref("device.sensors.motion.enabled", false);'
      'defaultPref("device.sensors.orientation.enabled", false);'
      'defaultPref("devtools.enabled", true);'
      'defaultPref("devtools.onboarding.telemetry.logged", false);'
      'defaultPref("distribution.iniFile.exists.value", true);'
      'defaultPref("distribution.mozilla-EMEfree.bookmarksProcessed", true);'
      'defaultPref("dom.allow_scripts_to_close_windows", false);'
      'defaultPref("dom.battery.enabled", false);'
      '// defaultPref("dom.caches.enabled", false);'
      'defaultPref("dom.disable_beforeunload", true);'
      'defaultPref("dom.disable_window_flip", false);'
      'defaultPref("dom.disable_window_move_resize", true);'
      'defaultPref("dom.disable_window_open_feature.close", true);'
      'defaultPref("dom.disable_window_open_feature.location", false);'
      'defaultPref("dom.disable_window_open_feature.minimizable", true);'
      'defaultPref("dom.disable_window_open_feature.personalbar", true);'
      'defaultPref("dom.disable_window_open_feature.titlebar", true);'
      'defaultPref("dom.disable_window_status_change", false);'
      '// defaultPref("dom.enable_performance", false);'
      'defaultPref("dom.enable_performance_navigation_timing", false);'
      'defaultPref("dom.enable_performance_observer", false);'
      '// defaultPref("dom.enable_resource_timing", false);'
      '// defaultPref("dom.enable_user_timing", false);'
      'defaultPref("dom.event.clipboardevents.enabled", false);'
      'defaultPref("dom.gamepad.enabled", false);'
      'defaultPref("dom.gamepad.extensions.enabled", false);'
      'defaultPref("dom.gamepad.non_standard_events.enabled", false);'
      'defaultPref("dom.idle-observers-api.enabled", false);'
      'defaultPref("dom.indexedDB.logging.details", false);'
      'defaultPref("dom.indexedDB.logging.enabled", false);'
      'defaultPref("dom.ipc.plugins.flash.subprocess.crashreporter.enabled", false);'
      'defaultPref("dom.ipc.plugins.reportCrashURL", false);'
      'defaultPref("dom.keyboardevent.dispatch_during_composition", false);'
      'defaultPref("dom.mozApps.used", true);'
      'defaultPref("dom.netinfo.enabled", false);'
      'defaultPref("dom.network.enabled", false);'
      'defaultPref("dom.private-attribution.submission.enabled", false);'
      'defaultPref("dom.push.connection.enabled", false);'
      'defaultPref("dom.push.enabled", false);'
      'defaultPref("dom.push.serverURL", "");'
      'defaultPref("dom.quotaManager.backgroundTask.enabled", false);'
      '// defaultPref("dom.security.https_first", true);'
      'defaultPref("dom.security.https_only_mode", true);'
      'defaultPref("dom.security.https_only_mode_ever_enabled", true);'
      'defaultPref("dom.security.https_only_mode_ever_enabled_pbm", true);'
      'defaultPref("dom.serviceWorkers.enabled", false);'
      'defaultPref("dom.sms.enabled", false);'
      'defaultPref("dom.vibrator.enabled", false);'
      'defaultPref("dom.vr.enabled", false);'
      'defaultPref("dom.vr.oculus.enabled", false);'
      'defaultPref("dom.vr.oculus.invisible.enabled", false);'
      'defaultPref("dom.vr.poseprediction.enabled", false);'
      'defaultPref("dom.vr.require-gesture", false);'
      'defaultPref("dom.w3c_touch_events.enabled", 0);'
      'defaultPref("dom.webaudio.enabled", false);'
      'defaultPref("dom.webnotifications.enabled", false);'
      'defaultPref("dom.webnotifications.serviceworker.enabled", false);'
      'defaultPref("experiments.activeExperiment", false);'
      'defaultPref("experiments.enabled", false);'
      'defaultPref("experiments.manifest.uri", "");'
      'defaultPref("experiments.supported", false);'
      'defaultPref("extensions.abuseReport.enabled", false);'
      'defaultPref("extensions.blocklist.enabled", true);'
      'defaultPref("extensions.blocklist.pingCountTotal", 2);'
      'defaultPref("extensions.blocklist.pingCountVersion", 0);'
      'defaultPref("extensions.bootstrappedAddons", "{}");'
      'defaultPref("extensions.databaseSchema", 16);'
      'defaultPref("extensions.e10sBlockedByAddons", true);'
      'defaultPref("extensions.e10sBlocksEnabling", true);'
      'defaultPref("extensions.formautofill.addresses.enabled", false);'
      'defaultPref("extensions.formautofill.creditCards.enabled", false);'
      'defaultPref("extensions.formautofill.heuristics.enabled", false);'
      'defaultPref("extensions.getAddons.cache.enabled", false);'
      'defaultPref("extensions.getAddons.databaseSchema", 5);'
      'defaultPref("extensions.getAddons.showPane", false);'
      'defaultPref("extensions.htmlaboutaddons.discover.enabled", false);'
      'defaultPref("extensions.htmlaboutaddons.recommendations.enabled", false);'
      '// defaultPref("extensions.manifestV3.enabled", false);'
      'defaultPref("extensions.pendingOperations", false);'
      'defaultPref("extensions.pocket.api", "");'
      'defaultPref("extensions.pocket.enabled", false);'
      'defaultPref("extensions.pocket.oAuthConsumerKey", "");'
      'defaultPref("extensions.pocket.site", "");'
      'defaultPref("extensions.privatebrowsing.notification", true);'
      'defaultPref("extensions.ui.dictionary.hidden", true);'
      'defaultPref("extensions.ui.locale.hidden", true);'
      'defaultPref("extensions.unifiedExtensions.enabled", false);'
      'defaultPref("extensions.webcompat-reporter.enabled", false);'
      'defaultPref("extensions.webcompat-reporter.newIssueEndpoint", "");'
      'defaultPref("extensions.webservice.discoverURL", "");'
      'defaultPref("findbar.highlightAll", true);'
      'defaultPref("font.internaluseonly.changed", false);'
      'defaultPref("font.size.fixed.x-cyrillic", 13);'
      'defaultPref("font.size.monospace.x-cyrillic", 13);'
      'defaultPref("full-screen-api.warning.delay", 250);'
      'defaultPref("full-screen-api.warning.timeout", 1500);'
      'defaultPref("general.warnOnAboutConfig", false);'
      'defaultPref("geo.enabled", false);'
      'defaultPref("geo.provider.ms-windows-location", false);'
      'defaultPref("geo.wifi.logging.enabled", false);'
      'defaultPref("geo.wifi.uri", "");'
      'defaultPref("gfx.canvas.skiagl.dynamic-cache", false);'
      'defaultPref("gfx.work-around-driver-bugs", false);'
      'defaultPref("identity.fxaccounts.enabled", false);'
      'defaultPref("intl.charsetmenu.browser.cache", "UTF-8");'
      'defaultPref("javascript.options.shared_memory", true);'
      'defaultPref("keyword.enabled", false);'
      'defaultPref("layers.acceleration.force-enabled", true);'
      'defaultPref("layers.deaa.enabled", false);'
      'defaultPref("layers.geometry.opengl.enabled", false);'
      'defaultPref("layers.mlgpu.sanity-test-failed", false);'
      'defaultPref("lightweightThemes.update.enabled", false);'
      'defaultPref("media.autoplay.blocking_policy", 2);'
      'defaultPref("media.autoplay.default", 5);'
      'defaultPref("media.block-autoplay-until-in-foreground", true);'
      'defaultPref("media.block-play-until-visible", true);'
      'defaultPref("media.decoder-doctor.new-issue-endpoint", "");'
      'defaultPref("media.eme.apiVisible", false);'
      'defaultPref("media.eme.enabled", false);'
      'defaultPref("media.getusermedia.aec_enabled", false);'
      'defaultPref("media.getusermedia.noise_enabled", false);'
      'defaultPref("media.getusermedia.screensharing.allowed_domains", "");'
      'defaultPref("media.getusermedia.screensharing.enabled", false);'
      'defaultPref("media.gmp-eme-adobe.enabled", false);'
      'defaultPref("media.hardware-video-decoding.enabled", true);'
      'defaultPref("media.hardware-video-decoding.failed", false);'
      'defaultPref("media.hardware-video-decoding.force-enabled", true);'
      'defaultPref("media.navigator.enabled", false);'
      'defaultPref("media.navigator.permission.disabled", true);'
      'defaultPref("media.navigator.video.enabled", false);'
      'defaultPref("media.ondevicechange.enabled", false);'
      'defaultPref("media.peerconnection.enabled", false);'
      'defaultPref("media.peerconnection.ice.default_address_only", true);'
      'defaultPref("media.peerconnection.ice.no_host", true);'
      'defaultPref("media.peerconnection.ice.relay_only", true);'
      'defaultPref("media.peerconnection.ice.tcp", false);'
      'defaultPref("media.peerconnection.identity.enabled", false);'
      'defaultPref("media.peerconnection.identity.timeout", 1);'
      'defaultPref("media.peerconnection.turn.disable", true);'
      'defaultPref("media.peerconnection.use_document_iceservers", false);'
      'defaultPref("media.peerconnection.video.enabled", false);'
      'defaultPref("media.video_stats.enabled", false);'
      'defaultPref("media.videocontrols.picture-in-picture.improved-video-controls.enabled", true);'
      'defaultPref("media.webspeech.recognition.enable", false);'
      'defaultPref("media.webspeech.recognition.force_enable", false);'
      'defaultPref("media.webspeech.synth.enabled", false);'
      'defaultPref("media.wmf.deblacklisting-for-telemetry-in-gpu-process", false);'
      'defaultPref("mousewheel.default.delta_multiplier_y", 400);'
      '// defaultPref("mousewheel.min_line_scroll_amount", 5);'
      'defaultPref("network.allow-experiments", false);'
      'defaultPref("network.captive-portal-service.enabled", false);'
      'defaultPref("network.captive-portal-service.maxInterval", 0);'
      'defaultPref("network.cookie.cookieBehavior", 1);'
      '// defaultPref("network.cookie.lifetimePolicy", 2);'
      'defaultPref("network.cookie.prefsMigrated", true);'
      'defaultPref("network.cookie.thirdparty.sessionOnly", true);'
      '// defaultPref("network.dns.disableIPv6", true);'
      'defaultPref("network.dns.disablePrefetch", true);'
      'defaultPref("network.dns.disablePrefetchFromHTTPS", true);'
      'defaultPref("network.http.altsvc.enabled", false);'
      'defaultPref("network.http.altsvc.oe", false);'
      'defaultPref("network.http.speculative-parallel-limit", 0);'
      'defaultPref("network.dns.offline-localhost", true);'
      'defaultPref("network.predictor.enabled", false);'
      'defaultPref("network.predictor.enable-prefetch", false);'
      'defaultPref("network.prefetch-next", false);'
      'defaultPref("network.tcp.tcp_fastopen_enable", true);'
      'defaultPref("network.trr.mode", 1);'
      'defaultPref("nglayout.initialpaint.delay", 5);'
      'defaultPref("pdfjs.enabledCache.state", false);'
      'defaultPref("pdfjs.enableScripting", false);'
      'defaultPref("pdfjs.migrationVersion", 2);'
      'defaultPref("pdfjs.previousHandler.alwaysAskBeforeHandling", true);'
      'defaultPref("pdfjs.previousHandler.preferredAction", 4);'
      'defaultPref("plugin.disable_full_page_plugin_for_types", "application/pdf");'
      'defaultPref("plugin.importedState", true);'
      'defaultPref("pref.browser.homepage.disable_button.bookmark_page", false);'
      'defaultPref("pref.browser.homepage.disable_button.current_page", false);'
      'defaultPref("pref.browser.homepage.disable_button.restore_default", false);'
      'defaultPref("pref.downloads.disable_button.edit_actions", false);'
      'defaultPref("pref.general.disable_button.default_browser", false);'
      'defaultPref("pref.privacy.disable_button.cookie_exceptions", false);'
      'defaultPref("pref.privacy.disable_button.view_cookies", false);'
      'defaultPref("pref.privacy.disable_button.view_passwords", false);'
      'defaultPref("privacy.donottrackheader.enabled", true);'
      'defaultPref("privacy.firstparty.isolate", false);'
      'defaultPref("privacy.history.custom", true);'
      'defaultPref("privacy.reduceTimerPrecision", true);'
      'defaultPref("privacy.resistFingerprinting", false);'
      'defaultPref("privacy.sanitize.migrateFx3Prefs", true);'
      'defaultPref("privacy.socialtracking.block_cookies.enabled", true);'
      'defaultPref("privacy.trackingprotection.enabled", true);'
      'defaultPref("reader.parse-on-load.enabled", false);'
      'defaultPref("security.app_menu.recordEventTelemetry", false);'
      'defaultPref("security.certerrors.recordEventTelemetry", false);'
      'defaultPref("security.identityblock.show_extended_validation", true);'
      'defaultPref("security.identitypopup.recordEventTelemetry", false);'
      'defaultPref("security.insecure_connection_text.enabled", false);'
      'defaultPref("security.protectionspopup.recordEventTelemetry", false);'
      'defaultPref("security.secure_connection_icon_color_gray", false);'
      'defaultPref("security.ssl.errorReporting.enabled", false);'
      'defaultPref("security.ssl.errorReporting.url", "");'
      'defaultPref("services.sync.clients.lastSync", "0");'
      'defaultPref("services.sync.clients.lastSyncLocal", "0");'
      'defaultPref("services.sync.declinedEngines", "");'
      'defaultPref("services.sync.enabled", false);'
      'defaultPref("services.sync.globalScore", 0);'
      'defaultPref("services.sync.migrated", true);'
      'defaultPref("services.sync.nextSync", 0);'
      'defaultPref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored", false);'
      'defaultPref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites", false);'
      'defaultPref("services.sync.tabs.lastSync", "0");'
      'defaultPref("services.sync.tabs.lastSyncLocal", "0");'
      'defaultPref("signon.autofillForms", false);'
      'defaultPref("signon.firefoxRelay.feature", "disabled");'
      'defaultPref("signon.generation.enabled", false);'
      'defaultPref("signon.management.page.breach-alerts.enabled", false);'
      'defaultPref("signon.rememberSignons", false);'
      'defaultPref("toolkit.cosmeticAnimations.enabled", false);'
      'defaultPref("toolkit.coverage.endpoint.base", "");'
      'defaultPref("toolkit.crashreporter.infoURL", "");'
      'defaultPref("toolkit.datacollection.infoURL", "");'
      'defaultPref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
      'defaultPref("toolkit.shopping.ohttpConfigURL", "");'
      'defaultPref("toolkit.shopping.ohttpRelayURL", "");'
      'defaultPref("toolkit.telemetry.archive.enabled", false);'
      'defaultPref("toolkit.telemetry.bhrPing.enabled", false);'
      'defaultPref("toolkit.telemetry.cachedClientID", "");'
      'defaultPref("toolkit.telemetry.enabled", false);'
      'defaultPref("toolkit.telemetry.firstShutdownPing.enabled", false);'
      'defaultPref("toolkit.telemetry.hybridContent.enabled", false);'
      'defaultPref("toolkit.telemetry.newProfilePing.enabled", false);'
      'defaultPref("toolkit.telemetry.optoutSample", false);'
      'defaultPref("toolkit.telemetry.pioneer-new-studies-available", false);'
      'defaultPref("toolkit.telemetry.reportingpolicy.firstRun", false);'
      'defaultPref("toolkit.telemetry.server", "");'
      'defaultPref("toolkit.telemetry.shutdownPingSender.enabled", false);'
      'defaultPref("toolkit.telemetry.shutdownPingSender.enabledFirstSession", false);'
      'defaultPref("toolkit.telemetry.unified", false);'
      'defaultPref("toolkit.telemetry.updatePing.enabled", false);'
      'defaultPref("toolkit.telemetry.unifiedIsOptIn", false);'
      'defaultPref("toolkit.zoomManager.zoomValues", ".25,.3,.5,.67,.75,.8,.9,1,1.1,1.25,1.33,1.5,1.7,2,2.4,3,4,5");'
      'defaultPref("ui.prefersReducedMotion", 1);'
      'defaultPref("xpinstall.whitelist.add", "");'
      'defaultPref("xpinstall.whitelist.add.180", "");'
      'defaultPref("xul.panel-animations.enabled", false);'
      ''
      'defaultPref("ui.useOverlayScrollbars", 1);'
      'defaultPref("widget.gtk.overlay-scrollbars.enabled", true);'
      'defaultPref("widget.non-native-theme.scrollbar.style", 5);'
      'defaultPref("widget.windows.overlay-scrollbars.enabled", true);'
      '//  defaultPref("widget.non-native-theme.scrollbar.style", 5);  //  Default = 0 ; macOs = 1 ; GTK = 2 ; Android = 3 ; W10 = 4 ; W11 = 5'
   )
   try {
      $aclocal = Join-Path $AppPath "autoconfiglocal.js"
      if (-not [IO.File]::Exists($aclocal)) {
         [System.IO.File]::WriteAllLines($aclocal, $aclocalContent, (New-Object System.Text.UTF8Encoding $false))
         Write-Host " ---> $AppDir\autoconfiglocal.js"
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }

   $acContent = @(
      '// autoconfig.js file needs to start with a comment'
      'pref("general.config.filename", "autoconfiglocal.js");'
      'pref("general.config.sandbox_enabled", false);'
      'pref("general.config.obscure_value", 0);'
   )

   try {
      $ac = Join-Path "$AppPath\defaults\pref" "autoconfig.js"
      if (-not [IO.File]::Exists($ac)) {
         [IO.Directory]::CreateDirectory("$AppPath\defaults\pref") | Out-Null
         Write-Host " ---> $AppDir\defaults\pref"
         [System.IO.File]::WriteAllLines($ac, $acContent, (New-Object System.Text.UTF8Encoding $false))
         Write-Host " ---> $AppDir\defaults\pref\autoconfig.js"
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }

   $distrIniContent = @(
      '# Partner Distribution Configuration File'
      '# Author: Mozilla'
      '# Date: 2015-03-27'
      ''
      '[Global]'
      'id=mozilla-EMEfree'
      'version=1.0'
      'about=Mozilla Firefox EME-free'
      ''
      '[Preferences]'
      'media.eme.enabled=false'
      'app.partner.mozilla-EMEfree="mozilla-EMEfree"'
   )

   try {
      $distrIni = Join-Path "$AppPath\distribution" "distribution.ini"
      if (-not [IO.File]::Exists($distrIni)) {
         [IO.Directory]::CreateDirectory("$AppPath\distribution") | Out-Null
         Write-Host " ---> $AppDir\distribution"
         [System.IO.File]::WriteAllLines($distrIni, $distrIniContent, (New-Object System.Text.UTF8Encoding $false))
         Write-Host " ---> $AppDir\distribution\distribution.ini"
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }

   $polContent = '{"policies":{"DisableAppUpdate":true,"DisableTelemetry":true}}'

   try {
      $pol = Join-Path "$AppPath\distribution" "policies.json"
      if (-not [IO.File]::Exists($pol)) {
         [System.IO.File]::WriteAllLines($pol, $polContent, (New-Object System.Text.UTF8Encoding $false))
         Write-Host " ---> $AppDir\distribution\policies.json"
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }


   try {
      [IO.Directory]::CreateDirectory("$profilePath\chrome") | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }

   $userChromeContent = @(
      '/* Left menu */'
      '#PanelUI-button { -moz-box-ordinal-group:0 !important ; order:-1 !important ; margin-inline-start:0px !important ; margin-inline-end:0px !important ; border-inline-start:none !important ; border-inline-end:0px solid !important ; }'
      '.cui-widget-panel, #appMenu-popup { margin-left:1em !important; }'
      ''
      '/* Tab''s fonts */'
      '#urlbar { font-family:Tahoma !important ; font-size:8pt !important ; }'
      '#tabbrowser-tabs .tab-text{ font-family:Tahoma !important ; font-size:8pt !important ; font-weight:none !important ; }'
      ''
      '/* ======================== */'
      '/* keyfox-main\userChrome.css */'
      ''
      '/* Simplifying interface */'
      '#nav-bar { background:none !important ; box-shadow:none !important ;}'
      '#navigator-toolbox { border:none !important ;}'
      '.titlebar-spacer { display:none !important ;}'
      '#urlbar-background { border:none !important ;}'
      '/* #urlbar:not(:hover):not([breakout][breakout-extend]) > #urlbar-background { box-shadow:none !important ; background:none !important } */'
      ''
      '/* Element Hiding stuff */'
      '.urlbar-icon, #userContext-indicator, #userContext-label { fill:transparent !important ; background:transparent !important ; color:transparent !important ; }'
      '#urlbar:hover .urlbar-icon, #urlbar:active .urlbar-icon, #urlbar[focused] .urlbar-icon { fill:var(--toolbar-color) !important ;}'
      '/* ======================== */'
      ''
      '/* Tab''s corners */'
      '@-moz-document url("chrome://browser/content/browser.xhtml") { :root {'
      ' --tab-block-margin:0px !important ;'
      ' --tab-border-radius:0px !important ;'
      ' --toolbarbutton-outer-padding:1px !important ;'
      ' --toolbarbutton-inner-padding:4px !important ;'
      ' --toolbar-start-end-padding:1px !important ;'
      ' --bookmark-block-padding:1px !important ;'
      ' --urlbar-min-height:24px !important ;'
      ' --urlbar-icon-padding:3px !important ;'
      '} }'
      ''
      '/* Overlink */'
      '#statuspanel[type="overLink"] { opacity:90% !important ; }'
      '#statuspanel-label { color:black !important; }'
      '@media (-moz-windows-default-theme)             {  #statuspanel-label { color:black !important; }}'
      '@media (-moz-content-prefers-color-scheme:dark) {  #statuspanel-label { color:white !important; }}'
      ''
      '/* #tabbrowser-tabpanels { background-color:menu !important; } */'
      '#tabbrowser-tabpanels { background-color: white !important; }'
      ''
      '/* ======================== */'
      '/*  Alltabs button  */'
      '#TabsToolbar-customization-target {counter-reset: tabCount}.tabbrowser-tab {counter-increment: tabCount}'
      '#alltabs-button>.toolbarbutton-badge-stack>.toolbarbutton-icon {list-style-image: url("data:image/svg+xml,%3Csvg width=''40'' height=''30'' version=''1.1'' viewBox=''0 0 40 30'' xmlns=''http://www.w3.org/2000/svg''%3E%3Ctitle%3EVetro%3C/title%3E%3Cpath transform=''translate(49,-60)'' d=''m-29 78.888-7.0703-7.0703 0.70703-0.70703 6.3633 6.3633 6.3633-6.3633 0.70703 0.70703-6.3633 6.3633z'' fill=''currentColor'' style=''paint-order:stroke fill markers''/%3E%3C/svg%3E"); overflow: hidden!important; padding: 0!important; border: 0!important; width: 40px!important; height: calc(100% + 1px)!important; margin: 0 -2px 0 0!important; transform: translate(20%,15%); padding: 0 3px}'
      '#alltabs-button>.toolbarbutton-badge-stack {position: relative!important; border-radius: 0!important; padding: 0!important; border: 0!important; height: calc(100% + 1px)!important; width: 56px!important; margin: 0-2px 0 0!important}'
      '#alltabs-button>.toolbarbutton-badge-stack::before {content: counter(tabCount); filter:contrast(500%)grayscale(100%); color: currentColor !important; position: absolute; bottom: 25%; left: 50%; transform: translate(-50%,-30%); padding: 0 3px}'
      '/* ======================== */'
      ''
      '/* 117 */'
      'menupopup, .menupopup-arrowscrollbox { border-radius:0px !important; }'
      'menupopup > menuitem, menupopup > menu { padding-block:2px !important; }  /* Set spacing here 0-4px */'
      ':root { --arrowpanel-menuitem-padding: 0px 4px !important; } /* Options menu spacing */'
      ''
      '/* 119 */'
      '#private-browsing-indicator-with-label > label {display: none;}'
      ''
      '/* 133 */'
      '#TabsToolbar :is(#private-browsing-indicator-with-label,.private-browsing-indicator-with-label) > label { display: none !important; }'
   )

   $userContentContent = @(
      '@-moz-document domain("youtube.com") {:root {scrollbar-width: none !important; /* thin/auto/none */} }'
      '@-moz-document url("about:privatebrowsing") { .showPrivate { display: none !important; } html.private { --in-content-page-background: menu !important; } }'
      ':root {scrollbar-color: #ff9900 transparent !important; }'
      '@-moz-document domain("youtube.com") { ytd-thumbnail[size] a.ytd-thumbnail, ytd-thumbnail[size]:before, ytd-watch-flexy[default-layout] #ytd-player.ytd-watch-flexy, .player-container.ytd-reel-video-renderer, ytd-player.ytd-shorts, .ytp-tooltip.ytp-preview, .ytp-tooltip.ytp-preview .ytp-tooltip-bg { border-radius: 0 !important; } }'
   )

   try {
      Write-Host " ---> $($profilePath.Split('\')[-1])\chrome"

      $userChrome = Join-Path "$profilePath\chrome" "userChrome.css"
      [System.IO.File]::WriteAllLines($userChrome, $userChromeContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\chrome\userChrome.css"

      $userContent = Join-Path "$profilePath\chrome" "userContent.css"
      [System.IO.File]::WriteAllLines($userContent, $userContentContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\chrome\userContent.css"

      if (-not $errorProfile) {Write-Host "New profile: Done" @green}
   } catch {
      Write-Host "$_.Exception.Message" @red
   }

}

# Proxy settings
Function Get-Proxy {
   if (-not $UseProxy) {return $false}

   if (-not $ProxyArg) {$Script:ProxyArg = '-'}

   try {[datetime]::parseexact($lastcheck, 'ddMMyyyy', $null)} catch {$lastcheck='18032026'}
   $daysCheckProxy = (New-TimeSpan -Start $([datetime]::parseexact($lastcheck, 'ddMMyyyy', $null))).Days

   if ($RunMode -eq 1 -or $daysCheckProxy -lt [int]$CheckInterval+99) {
      if ([IO.File]::Exists($ProxyPath)) {
         return $true
      }
   }

   try {
      $response = Make-NetRequest -Url 'https://github.com/Alexey71/opera-proxy/releases/latest'
      $lastproxy = [version]($response.RequestMessage.RequestUri.AbsoluteUri -Split 'tag/v')[1]
      if (-not $lastproxy) {throw 'lastproxy is NULL'}
      $urlproxy = 'https://github.com/Alexey71/opera-proxy/releases/latest/download/opera-proxy.windows-amd64.exe'
      Write-Host "Proxy latest: $lastproxy"
   } catch {
      Write-Host "$_.Exception.Message" @red
      Write-Host "Error check proxy latest" @red
      if ([IO.File]::Exists($ProxyPath)) {return $true} else {return $false}
   } finally {
      if ($response) {$response.Dispose()}
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

# Setting up portable.ini
Function Check-IniFile {
   Write-Host "Check-IniFile..."

   $ini = Join-Path $AppPath 'portable.ini'
   $sect = '[General]'
   $keys = @{'Portable'=1;'PortableDataPath'=$profilePath}

   try {
      $lines = if ([IO.File]::Exists($ini)) {
         Get-Content -LiteralPath $ini -Encoding 'UTF8'
      }

      if ($lines -notcontains $sect) {
         $lines = @($sect)+@($lines)
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
         [IO.File]::WriteAllLines($ini,$lines,$(New-Object Text.UTF8Encoding($false)))
         Write-Host "File portable.ini tuned: OK" @green
         return $true
      }
   } catch {
      throw "$_.Exception.Message"
   }
}

# Removing junk after closing the browser
Function Delete-Traces {
   $list = @($DelDirs+$DelFiles | ForEach-Object {
      Get-Item -Path "$profilePath\$_" -ErrorAction SilentlyContinue
   })
   $listExclude = @($ExcludeDirs | ForEach-Object {
      (Get-Item -Path "$profilePath\$_" -ErrorAction SilentlyContinue).FullName
   })
   $list = $list | Where-Object {-not ($listExclude -contains $_.FullName)}
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
if ($UseProxy) {Write-Host  "Proxy:     $ProxyPath"   @darkcyan}
if ($SqlVacuum) {Write-Host "Sqlite:    $SqlPath"     @darkcyan}
Write-Host                  "Profile:   $profilePath" @darkcyan
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
if ($DllPath) {Write-Host   "Dll:       $DllPath"     @darkcyan}
Write-Host                  "Mutex:     $MutexName"   @darkcyan

try {

   try {[datetime]::parseexact($lastcheck, 'ddMMyyyy', $null)} catch {$lastcheck='18032026'}
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

   # The bitness of the executable file
   $archExe = Get-Bitness -ExeFile "$AppPath\$ExeName"
   if (-not $archExe) {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed $ExeName" -MessageType "Error"
      }
      throw "Missed $ExeName"
   }

   # Presence of portable(32/64).dll
   if (-not [IO.File]::Exists("$AppPath\portable$($archExe).dll")) {
      Show-Balloon -Message "Missed portable$($archExe).dll" -MessageType "Error"
      throw "Missed portable$($archExe).dll"
   }

   # Setting up portable.ini
   try {if (-not (Check-IniFile)) {Write-Host "Not changed portable.ini"}}
   catch {throw "Error tuned portable.ini: $_"}

   # Setting up dependentlibs.list
   $list = @(Get-Content -Path "$AppPath\dependentlibs.list" -ErrorAction SilentlyContinue)
   if (-not ($list -like "portable$($archExe).dll")) {
      (@("portable$($archExe).dll")+$list -join "`n")+"`n" | Set-Content -Path "$AppPath\dependentlibs.list" -NoNewLine
      Write-Host "Add portable$($archExe).dll to dependentlibs.list: OK" @green
   }

   # Empty Switches Filter
   if ($Switches.Count -eq 0) {$Switches = @('-')}

   # Creating a new profile
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

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
   try {[datetime]::parseexact($lastclean, 'ddMMyyyy', $null)} catch {$lastclean='18032026'}
   $sinceclean = (New-TimeSpan -Start $([datetime]::parseexact($lastclean, 'ddMMyyyy', $null))).Days


   if ($browserRunning -or $timedOut) {
      Write-Host "Browser still running - cleanup skipped" @yellow
   } elseif ($sinceclean -ge [int]$CleanInterval) {
      Write-Host "Start profile clean..."
      Delete-Traces
      Set-FileVar -Name "lastclean" -Value $(Get-Date -Format 'ddMMyyyy')
   }

   if ($SqlVacuum) {
      if ([IO.File]::Exists($SqlPath)) {
         Get-ChildItem -Path "$profilePath\*.sqlite" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $size = $_.Length
            &($SqlPath) $_ VACUUM
            $newsize = (Get-Item -Path $_).Length
            [PSCustomObject]@{
               'SQL-files VACUUM' = $_.Name
               'Before'           = $size
               'After'            = $newsize
            }
            $before += $size; $after += $newsize
         } | Out-Host
         $percent = (1 - $after / $before).ToString("P2")
         $before = ($before / 1MB).ToString("0.00")
         $after = ($after / 1MB).ToString("0.00")
         Write-Host "Vacuum result: before $before MB, after $after MB, reduced by $percent" @green
         Write-Host ""
      } else {
         Write-Host "Not found sqlite3.exe" @red
      }
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

   if ($Script:HttpClient) {
      try {$Script:HttpClient.Dispose()} catch {}
      $Script:HttpClient = $null
   }

   Close-TrayIcon
   Exit-SingleInstance
   if ($ShowConsole) {[void][Console]::ReadKey($true)}
}
