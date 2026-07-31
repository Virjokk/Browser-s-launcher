<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Firefox и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию браузера (Stable, Beta, Developer, Nightly, ESR), разрядность (x64/x86) и язык (en/ru).
:: Портабельность обеспечивается методом "трех файлов" (https://github.com/adonais/libportable).
:: Для проверки/скачивания обновлений и для браузера можно использовать opera-proxy (https://github.com/Alexey71/opera-proxy),
:: который будет скачан и запущен с заданными параметрами, при выходе новых версий будет автообновляться.
:: Если профиль существует и указан его относительный путь в $profileName, то браузер запустится с этим профилем.
:: Иначе создается новый с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=2&topic=5924#1).
:: Рядом со скриптом создаётся папка Core (имя настраиваемо), в которой будет расположена сборка.
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

$profileName = "..\Profile" # имя папки профиля относительно portable.dll
$CheckInterval = 3 # интервал проверки обновлений в днях, если 0, будет проверять при каждом запуске
$CleanInterval = 7 # интервал очистки профиля и реестра в днях, если 0, будет чистить при каждом завершении
$RunMode = 0 # 0 - обычный режим, 1 - только запуск, 2 - только проверка/установка обновлений
$CreateShortcut = $false # создать ярлык на рабочем столе
$AskUpdate = $true # перед обновлением спрашивать
$Backup = $false # при обновлении создавать в папке батника zip-бэкап профиля
$MakeStub = $false # создавать взамен удаляемых в профиле папок ($DelDirs) файлы-заглушки нулевого размера
$Edition = 0 # 0 - Stable, 1 - Beta, 2 - Developer, 3 - Nightly, 4 - ESR
$Bitness = "x64" # для 32bit-версии указать "x86"
$Language = "EN" # для русскоязычной версии указать RU
$AppDir = "Core" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$DllPath = "" # локальный путь к portable_bin.7z, если оставить пустым, будет скачан с github.com
$SqlVacuum = $false # использовать sqlite3.exe для сжатия sql-файлов в профиле
$SqlPath = "" # локальный путь к sqlite3.exe, если пусто (при $SqlVacuum = $true) - скачается с офсайта
$UseProxy = 0 # 0 - не включать, 1 - только для браузера, 2 - для браузера и для проверки/закачки обновлений
$ProxyPath = "" # путь к файлу опера прокси, если оставить пустым, будет скачан с github.com (при $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18083","-verbosity 30","-country AM" # параметры прокси
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # ключи запуска браузера
   "-no-remote"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
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

$ExcludeDirs = @( # папки, не подлежащие удалению
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
)

$DelFiles = @( # файлы профиля, удаляемые после закрытия браузера
   "*.log"
   "*-journal"
   "*-shm"
   "*.txt"
   "*-wal"
   "activity-stream*"
   "parent.lock"
)

$DelReg = @( # данные реестра, удаляемые после закрытия браузера
   "HKEY_CURRENT_USER\SOFTWARE\Mozilla\Firefox"
)

$NoStub = @( # папки, для которых файлы-заглушки не создаются
   "datareporting"
   "minidumps"
)

$SetupExclude = @( # папки и файлы, исключаемые из состава браузера при установке/обновлении
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

$Trash = @( # папки и файлы вне профиля, подлежащие удалению после закрытия браузера
   "$env:ProgramData\Mozilla*"
   "$env:AppData\Mozilla"
   "$env:LocalAppData\Mozilla"
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================

$lastcheck = "18032026"
$lastclean = "18032026"
$sha256local = ""

$scriptName = $MyInvocation.Line -replace "[^']+'([A-Za-z]:\\.+)'[^']+",'$1'
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
$Script:MutexName = "Global\FirefoxPortable$($scriptName -replace '[\\:]','_')"

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

# Разрядность исполняемого файла
Function Get-Bitness ([string]$ExeFile) {
   if (-not [IO.File]::Exists($ExeFile)) {return $false}
   try {
      [byte[]]$data = New-Object -TypeName System.Byte[] -ArgumentList 4096
      $stream = New-Object -TypeName System.IO.FileStream -ArgumentList ($ExeFile, 'Open', 'Read')
      $stream.Read($data, 0, 4096) | Out-Null

      [int32]$PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, 60)
      [int32]$mUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + 4)

      return $(if ($mUint -eq '0x8664') {'64'} else {'32'})
   } catch {
      Write-Host "$_.Exception.Message" @red
      return $false
   } finally {
      $stream.Close(); $stream.Dispose(); $stream = $null; $data = $null
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
      $rawlink = (Make-NetRequest -Url $url).RequestMessage.RequestUri.AbsoluteUri
      $Script:distrLink = $rawlink -replace '.+(?=/pub/)','https://ftp.mozilla.org'
      if (-not $distrLink) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   Write-Host "Redirect:  $distrLink"

   if ($Edition -eq 3) {
      $crcfile = $distrLink -replace '\.installer\.exe$','.checksums'
      try {
         if ((Make-NetRequest -Url $crcfile).Content.ReadAsStringAsync().Result -match "(\w{64}) sha256.+installer\.exe") {
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

# Сравнение версий
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
         if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.MessageBox').Type) {
            try {Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop}
            catch {$Script:checkError = $true; Write-Host "$_.Exception.Message" @red; return $false}
         }
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
      if ($SqlVacuum) {
         if (-not [IO.File]::Exists($SqlPath)) {
            $sqlsite = "https://sqlite.org/download.html"
            $sqlhtml = (Make-NetRequest -Url $sqlsite).Content.ReadAsStringAsync().Result

            if ($sqlhtml | Where-Object {$_ -match "product,[\d\.]+,(\S+s-win-x64\S+\.zip)"}) {
               $sqllink = "https://sqlite.org/$($matches[1])"
            }

            $sqldest = "$tmpdir\sql.zip"
            if (-not (Download-File -Source $sqllink -Dest $sqldest)) {
                Write-Host "Error download sqlite" @red
                $sqldest = $null
            } else {
                Write-Host "Download sqlite: OK" @green
            }
         }
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
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

      # Список файлов для сохранения
      $nodel = @(
         "$($profilePath.split('\')[-1])"
         "$((($profilePath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      $nodel += @(
         "$($ProxyPath.split('\')[-1])"
         "$((($ProxyPath -Split [regex]::Escape($AppPath),0,"SimpleMatch") -Split '\\')[1])"
      )

      $nodel += @(
         'autoconfiglocal.js'
         'defaults'
         'distribution'
         'portable.ini'
         "portable$($dllbit).dll"
      )

      if ([IO.Directory]::Exists($AppPath)) {
         Get-Item -Path "$AppPath\*" -Exclude $nodel -ea 0 | Remove-Item -Recurse -Force -ea 0
         Write-Host "Delete old files: OK" @green
      } else {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      $SetupExclude | ForEach-Object {
         $excludePath = "$tmpdir\core\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\core\*" -Destination $AppPath -Recurse -Force
      Write-Host "Copy new files to $($AppPath): OK" @green

      Get-Item -Path "$scriptPath\*.zip" -ea 0 | Sort-Object LastWriteTime -Descending | Select-Object -skip 2 | ForEach-Object {
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

# Новый профиль
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
      'defaultPref("browser.aboutHomeSnippets.updateUrl", "");'
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
      'defaultPref("browser.chrome.errorReporter.enabled", false);'
      'defaultPref("browser.chrome.errorReporter.infoURL", "");'
      'defaultPref("browser.chrome.errorReporter.submitUrl", "");'
      'defaultPref("browser.contentblocking.report.endpoint_url", "");'
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
      'defaultPref("browser.newtabpage.activity-stream.aboutHome.enabled", false);'
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
      'defaultPref("browser.newtabpage.columns", 3);'
      'defaultPref("browser.newtabpage.directory.ping", "");'
      'defaultPref("browser.newtabpage.directory.source", "");'
      'defaultPref("browser.newtabpage.enabled", false);'
      'defaultPref("browser.newtabpage.enhanced", false);'
      'defaultPref("browser.newtabpage.introShown", true);'
      'defaultPref("browser.newtabpage.pinned", "[]");'
      'defaultPref("browser.newtabpage.rows", 2);'
      'defaultPref("browser.newtabpage.storageVersion", 1);'
      'defaultPref("browser.onboarding.enabled", false);'
      'defaultPref("browser.onboarding.hidden", true);'
      'defaultPref("browser.pagethumbnails.capturing_disabled", true);'
      'defaultPref("browser.pagethumbnails.storage_version", 3);'
      'defaultPref("browser.partnerlink.attributionURL", "");'
      'defaultPref("browser.ping-centre.production.endpoint", "");'
      'defaultPref("browser.ping-centre.staging.endpoint", "");'
      'defaultPref("browser.ping-centre.telemetry", false);'
      'defaultPref("browser.places.importBookmarksHTML", false);'
      'defaultPref("browser.places.smartBookmarksVersion", 7);'
      'defaultPref("browser.pocket.enabled", false);'
      'defaultPref("browser.preferences.advanced.selectedTabIndex", 0);'
      'defaultPref("browser.preferences.defaultPerformanceSettings.enabled", false);'
      'defaultPref("browser.preferences.inContent", true);'
      'defaultPref("browser.privacySegmentation.createdShortcut", true);'
      'defaultPref("browser.privatebrowsing.autostart", false);'
      'defaultPref("browser.privatebrowsing.enable-new-indicator", false);'
      'defaultPref("browser.proton.enabled", false);'
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
      'defaultPref("browser.tabs.remote.autostart", false);'
      'defaultPref("browser.tabs.remote.autostart.2", false);'
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
      'defaultPref("dom.ipc.processCount", 1);'
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
      'defaultPref("extensions.blocklist.enabled", false);'
      'defaultPref("extensions.blocklist.pingCountTotal", 2);'
      'defaultPref("extensions.blocklist.pingCountVersion", 0);'
      'defaultPref("extensions.bootstrappedAddons", "{}");'
      'defaultPref("extensions.databaseSchema", 16);'
      'defaultPref("extensions.e10sBlockedByAddons", true);'
      'defaultPref("extensions.e10sBlocksEnabling", true);'
      'defaultPref("extensions.enabledAddons", "SimpleX%40White.Theme:3.0");'
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
      'defaultPref("general.skins.selectedSkin", "simplewhitex");'
      'defaultPref("general.smoothScroll", false);'
      'defaultPref("general.warnOnAboutConfig", false);'
      'defaultPref("geo.enabled", false);'
      'defaultPref("geo.provider.ms-windows-location", false);'
      'defaultPref("geo.wifi.logging.enabled", false);'
      'defaultPref("geo.wifi.uri", "");'
      'defaultPref("gfx.canvas.skiagl.dynamic-cache", false);'
      'defaultPref("gfx.direct3d.last_used_feature_level_idx", 0);'
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
      'defaultPref("loop.enabled", false);'
      'defaultPref("loop.feedback.formURL", "");'
      'defaultPref("loop.gettingStarted.url", "");'
      'defaultPref("media.autoplay.blocking_policy", 2);'
      'defaultPref("media.autoplay.default", 5);'
      'defaultPref("media.autoplay.enabled", false);'
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
      'defaultPref("network.security.esni.enabled", true);'
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
      'defaultPref("readinglist.scheduler.enabled", false);'
      'defaultPref("readinglist.server", "");'
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
      'defaultPref("social.directories", "");'
      'defaultPref("social.remote-install.enabled", false);'
      'defaultPref("social.share.activationPanelEnabled", false);'
      'defaultPref("social.shareDirectory", "");'
      'defaultPref("social.toast-notifications.enabled", false);'
      'defaultPref("social.whitelist", "");'
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

   $prefsContent = @(
      '// Mozilla User Preferences'
      ''
      '// DO NOT EDIT THIS FILE.'
      '//'
      '// If you make changes to this file while the application is running,'
      '// the changes will be overwritten when the application exits.'
      '//'
      '// To change a preference value, you can either:'
      '// - modify it via the UI (e.g. via about:config in the browser); or'
      '// - set it within a user.js file in your profile.'
      ''
      'user_pref("accessibility.blockautorefresh", true);'
      'user_pref("accessibility.handler.enabled", false);'
      'user_pref("accessibility.typeaheadfind", true);'
      'user_pref("accessibility.typeaheadfind.flashBar", 0);'
      'user_pref("alerts.disableSlidingEffect", true);'
      'user_pref("app.normandy.api_url", "");'
      'user_pref("app.normandy.enabled", false);'
      'user_pref("app.normandy.first_run", false);'
      'user_pref("app.shield.optoutstudies.enabled", false);'
      'user_pref("app.support.e10sAccessibilityUrl", "");'
      'user_pref("app.update.auto", false);'
      'user_pref("app.update.checkInstallTime", false);'
      'user_pref("app.update.disable_button.showUpdateHistory", false);'
      'user_pref("app.update.enabled", false);'
      'user_pref("app.update.migrated.updateDir", true);'
      'user_pref("app.update.service.enabled", false);'
      'user_pref("app.update.url", "");'
      'user_pref("app.update.url.details", "");'
      'user_pref("app.update.url.manual", "");'
      'user_pref("beacon.enabled", false);'
      'user_pref("breakpad.reportURL", "");'
      'user_pref("browser.aboutConfig.showWarning", false);'
      'user_pref("browser.aboutHomeSnippets.updateUrl", "");'
      'user_pref("browser.bookmarks.restore_default_bookmarks", false);'
      'user_pref("browser.bookmarks.showRecentlyBookmarked", false);'
      'user_pref("browser.cache.disk.capacity", 0);'
      'user_pref("browser.cache.disk.enable", false);'
      'user_pref("browser.cache.disk.smart_size.enabled", false);'
      'user_pref("browser.cache.disk.smart_size.first_run", false);'
      'user_pref("browser.cache.disk_cache_ssl", false);'
      'user_pref("browser.cache.memory.capacity", -1);'
      'user_pref("browser.cache.offline.enable", false);'
      'user_pref("browser.cache.offline.insecure.enable", false);'
      'user_pref("browser.cache.offline.storage.enable", false);'
      'user_pref("browser.chrome.errorReporter.enabled", false);'
      'user_pref("browser.chrome.errorReporter.infoURL", "");'
      'user_pref("browser.chrome.errorReporter.submitUrl", "");'
      'user_pref("browser.contentblocking.report.endpoint_url", "");'
      'user_pref("browser.ctrlTab.recentlyUsedOrder", false);'
      'user_pref("browser.customizemode.tip0.shown", true);'
      'user_pref("browser.defaultbrowser.notificationbar", false);'
      'user_pref("browser.display.windows.non_native_menus", 0);'
      'user_pref("browser.download.animateNotifications", false);'
      'user_pref("browser.download.autohideButton", true);'
      'user_pref("browser.download.forbid_open_with", true);'
      'user_pref("browser.download.hide_plugins_without_extensions", false);'
      'user_pref("browser.download.importedFromSqlite", true);'
      'user_pref("browser.download.manager.addToRecentDocs", false);'
      'user_pref("browser.download.panel.shown", true);'
      'user_pref("browser.download.useDownloadDir", false);'
      'user_pref("browser.eme.ui.enabled", false);'
      'user_pref("browser.feeds.showFirstRunUI", false);'
      'user_pref("browser.fixup.alternate.enabled", false);'
      'user_pref("browser.formautofill.enabled", false);'
      'user_pref("browser.formfill.enable", false);'
      'user_pref("browser.fullscreen.animate", false);'
      'user_pref("browser.fullscreen.animateUp", 0);'
      'user_pref("browser.history_swipe_animation.disabled", true);'
      'user_pref("browser.in-content.dark-mode", false);'
      'user_pref("browser.link.open_newwindow.disabled_in_fullscreen", true);'
      'user_pref("browser.link.open_newwindow.override.external", 0);'
      'user_pref("browser.link.open_newwindow.restriction", 0);'
      'user_pref("browser.menu.showCharacterEncoding", "false");'
      'user_pref("browser.messaging-system.whatsNewPanel.enabled", false);'
      'user_pref("browser.newtab.preload", false);'
      'user_pref("browser.newtabpage.activity-stream.aboutHome.enabled", false);'
      'user_pref("browser.newtabpage.activity-stream.discoverystream.enabled", false);'
      'user_pref("browser.newtabpage.activity-stream.discoverystream.endpointSpocsClear", "");'
      'user_pref("browser.newtabpage.activity-stream.discoverystream.endpoints", "");'
      'user_pref("browser.newtabpage.activity-stream.enabled", false);'
      'user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);'
      'user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);'
      'user_pref("browser.newtabpage.activity-stream.feeds.system.topsites", false);'
      'user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);'
      'user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);'
      'user_pref("browser.newtabpage.activity-stream.filterAdult", false);'
      'user_pref("browser.newtabpage.activity-stream.fxaccounts.endpoint", "");'
      'user_pref("browser.newtabpage.activity-stream.hideTopSitesTitle", true);'
      'user_pref("browser.newtabpage.activity-stream.migrationExpired", true);'
      'user_pref("browser.newtabpage.activity-stream.prerender", false);'
      'user_pref("browser.newtabpage.activity-stream.section.highlights.includeBookmarks", false);'
      'user_pref("browser.newtabpage.activity-stream.section.highlights.includeDownloads", false);'
      'user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);'
      'user_pref("browser.newtabpage.activity-stream.section.highlights.includeVisited", false);'
      'user_pref("browser.newtabpage.activity-stream.showSearch", true);'
      'user_pref("browser.newtabpage.activity-stream.showSponsored", false);'
      'user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);'
      'user_pref("browser.newtabpage.activity-stream.showTopSites", true);'
      'user_pref("browser.newtabpage.activity-stream.telemetry", false);'
      'user_pref("browser.newtabpage.activity-stream.telemetry.ping.endpoint", "");'
      'user_pref("browser.newtabpage.activity-stream.telemetry.structuredIngestion", false);'
      'user_pref("browser.newtabpage.activity-stream.telemetry.structuredIngestion.endpoint", "");'
      'user_pref("browser.newtabpage.activity-stream.topSitesRows", 4);'
      'user_pref("browser.newtabpage.columns", 3);'
      'user_pref("browser.newtabpage.directory.ping", "");'
      'user_pref("browser.newtabpage.directory.source", "");'
      'user_pref("browser.newtabpage.enabled", false);'
      'user_pref("browser.newtabpage.enhanced", false);'
      'user_pref("browser.newtabpage.introShown", true);'
      'user_pref("browser.newtabpage.pinned", "[]");'
      'user_pref("browser.newtabpage.rows", 2);'
      'user_pref("browser.newtabpage.storageVersion", 1);'
      'user_pref("browser.onboarding.enabled", false);'
      'user_pref("browser.onboarding.hidden", true);'
      'user_pref("browser.pagethumbnails.capturing_disabled", true);'
      'user_pref("browser.pagethumbnails.storage_version", 3);'
      'user_pref("browser.partnerlink.attributionURL", "");'
      'user_pref("browser.ping-centre.production.endpoint", "");'
      'user_pref("browser.ping-centre.staging.endpoint", "");'
      'user_pref("browser.ping-centre.telemetry", false);'
      'user_pref("browser.places.importBookmarksHTML", false);'
      'user_pref("browser.places.smartBookmarksVersion", 7);'
      'user_pref("browser.pocket.enabled", false);'
      'user_pref("browser.preferences.advanced.selectedTabIndex", 0);'
      'user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);'
      'user_pref("browser.preferences.inContent", true);'
      'user_pref("browser.privacySegmentation.createdShortcut", true);'
      'user_pref("browser.privatebrowsing.autostart", false);'
      'user_pref("browser.privatebrowsing.enable-new-indicator", false);'
      'user_pref("browser.profiles.enabled", false);'
      'user_pref("browser.proton.enabled", false);'
      'user_pref("browser.region.network.url", "");'
      'user_pref("browser.region.update.enabled", false);'
      'user_pref("browser.rights.3.shown", true);'
      'user_pref("browser.safebrowsing.allowOverride", false);'
      'user_pref("browser.safebrowsing.appRepURL", "");'
      'user_pref("browser.safebrowsing.blockedURIs.enabled", false);'
      'user_pref("browser.safebrowsing.downloads.enabled", false);'
      'user_pref("browser.safebrowsing.downloads.remote.block_dangerous", false);'
      'user_pref("browser.safebrowsing.downloads.remote.block_dangerous_host", false);'
      'user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);'
      'user_pref("browser.safebrowsing.downloads.remote.block_uncommon", false);'
      'user_pref("browser.safebrowsing.downloads.remote.enabled", false);'
      'user_pref("browser.safebrowsing.downloads.remote.url", "");'
      'user_pref("browser.safebrowsing.enabled", false);'
      'user_pref("browser.safebrowsing.gethashURL", "");'
      'user_pref("browser.safebrowsing.malware.enabled", false);'
      'user_pref("browser.safebrowsing.malware.reportURL", "");'
      'user_pref("browser.safebrowsing.passwords.enabled", false);'
      'user_pref("browser.safebrowsing.phishing.enabled", false);'
      'user_pref("browser.safebrowsing.provider.google.advisoryName", "");'
      'user_pref("browser.safebrowsing.provider.google.advisoryURL", "");'
      'user_pref("browser.safebrowsing.provider.google.appRepURL", "");'
      'user_pref("browser.safebrowsing.provider.google.gethashURL", "");'
      'user_pref("browser.safebrowsing.provider.google.reportMalwareMistakeURL", "");'
      'user_pref("browser.safebrowsing.provider.google.reportPhishMistakeURL", "");'
      'user_pref("browser.safebrowsing.provider.google.reportURL", "");'
      'user_pref("browser.safebrowsing.provider.google.updateURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.advisoryName", "");'
      'user_pref("browser.safebrowsing.provider.google4.advisoryURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.dataSharingURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.gethashURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.gethashURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.reportMalwareMistakeURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.reportPhishMistakeURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.reportURL", "");'
      'user_pref("browser.safebrowsing.provider.google4.updateURL", "");'
      'user_pref("browser.safebrowsing.provider.mozilla.gethashURL", "");'
      'user_pref("browser.safebrowsing.provider.mozilla.lastupdatetime", "");'
      'user_pref("browser.safebrowsing.provider.mozilla.nextupdatetime", "");'
      'user_pref("browser.safebrowsing.provider.mozilla.updateURL", "");'
      'user_pref("browser.safebrowsing.reportErrorURL", "");'
      'user_pref("browser.safebrowsing.reportGenericURL", "");'
      'user_pref("browser.safebrowsing.reportMalwareErrorURL", "");'
      'user_pref("browser.safebrowsing.reportMalwareMistakeURL", "");'
      'user_pref("browser.safebrowsing.reportMalwareURL", "");'
      'user_pref("browser.safebrowsing.reportPhishMistakeURL", "");'
      'user_pref("browser.safebrowsing.reportPhishURL", "");'
      'user_pref("browser.safebrowsing.reportURL", "");'
      'user_pref("browser.safebrowsing.updateURL", "");'
      'user_pref("browser.search.geoip.url", "");'
      'user_pref("browser.search.geoSpecificDefaults", false);'
      'user_pref("browser.search.geoSpecificDefaults.url", "");'
      'user_pref("browser.search.reset.enabled", false);'
      'user_pref("browser.search.reset.whitelist", "");'
      'user_pref("browser.search.serpEventTelemetryCategorization.enabled", false);'
      'user_pref("browser.search.suggest.enabled", false);'
      'user_pref("browser.search.suggest.enabled.private", false);'
      'user_pref("browser.search.update", false);'
      'user_pref("browser.search.update.log", false);'
      'user_pref("browser.search.widget.inNavBar", true);'
      'user_pref("browser.selfsupport.url", "");'
      'user_pref("browser.sessionhistory.max_entries", 128);'
      'user_pref("browser.sessionstore.max_tabs_undo", 32);'
      '// user_pref("browser.sessionstore.restore_tabs_lazily", false);'
      '// user_pref("browser.sessionstore.restore_on_demand", false);'
      'user_pref("browser.sessionstore.warnOnQuit", true);'
      'user_pref("browser.shell.checkDefaultBrowser", false);'
      'user_pref("browser.shopping.experience2023.active", false);'
      'user_pref("browser.shopping.experience2023.ads.enabled", false);'
      'user_pref("browser.shopping.experience2023.ads.userEnabled", false);'
      'user_pref("browser.shopping.experience2023.enabled", false);'
      'user_pref("browser.shopping.experience2023.optedIn", 0);'
      'user_pref("browser.shopping.experience2023.survey.enabled", false);'
      'user_pref("browser.shopping.experience2023.survey.hasSeen", false);'
      'user_pref("browser.shopping.experience2023.survey.pdpVisits", 0);'
      'user_pref("browser.slowStartup.averageTime", 0);'
      'user_pref("browser.slowStartup.notificationDisabled", true);'
      'user_pref("browser.slowStartup.samples", 0);'
      'user_pref("browser.startup.blankWindow", false);'
      'user_pref("browser.startup.homepage", "about:newtab");'
      'user_pref("browser.startup.homepage_override.mstone", "ignore");'
      'user_pref("browser.startup.page", 3);'
      'user_pref("browser.suppress_first_window_animation", false);'
      'user_pref("browser.tabs.animate", false);'
      'user_pref("browser.tabs.closeWindowWithLastTab", false);'
      'user_pref("browser.tabs.crashReporting.sendReport", false);'
      'user_pref("browser.tabs.firefox-view", false);'
      'user_pref("browser.tabs.loadInBackground", false);'
      'user_pref("browser.tabs.maxOpenBeforeWarn", 10);'
      'user_pref("browser.tabs.remote.autostart", false);'
      'user_pref("browser.tabs.remote.autostart.2", false);'
      'user_pref("browser.tabs.tabMinWidth", 40);'
      'user_pref("browser.taskbar.previews.enable", true);'
      'user_pref("browser.theme.dark-private-windows", false);'
      'user_pref("browser.topsites.contile.enabled", false);'
      'user_pref("browser.toolbarbuttons.introduced.pocket-button", true);'
      'user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"save-to-pocket-button\",\"downloads-button\",\"fxa-toolbar-menu-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"developer-button\"],\"dirtyAreaCache\":[\"nav-bar\",\"PersonalToolbar\",\"TabsToolbar\",\"toolbar-menubar\"],\"currentVersion\":19,\"newElementCount\":3}");'
      'user_pref("browser.uidensity", 1);'
      'user_pref("browser.uitour.enabled", false);'
      'user_pref("browser.urlbar.formatting.enabled", false);'
      'user_pref("browser.urlbar.oneOffSearches", false);'
      'user_pref("browser.urlbar.scotchBonnet.enableOverride", false);'
      'user_pref("browser.urlbar.searchSuggestionsChoice", false);'
      'user_pref("browser.urlbar.suggest.searches", false);'
      'user_pref("browser.urlbar.suggest.topsites", false);'
      'user_pref("browser.urlbar.trimURLs", false);'
      'user_pref("browser.urlbar.update1", false);'
      'user_pref("browser.urlbar.weather.featureGate", false);'
      'user_pref("browser.vpn_promo.enabled", false);'
      'user_pref("camera.control.face_detection.enabled", false);'
      'user_pref("canvas.capturestream.enabled", false);'
      'user_pref("captivedetect.canonicalURL", "");'
      'user_pref("datareporting.healthreport.about.reportUrl", "");'
      'user_pref("datareporting.healthreport.about.reportUrlUnified", "");'
      'user_pref("datareporting.healthreport.documentServerURI", "");'
      'user_pref("datareporting.healthreport.infoURL", "");'
      'user_pref("datareporting.healthreport.service.enabled", false);'
      'user_pref("datareporting.healthreport.service.firstRun", true);'
      'user_pref("datareporting.healthreport.uploadEnabled", false);'
      'user_pref("datareporting.policy.dataSubmissionEnabled", false);'
      'user_pref("datareporting.policy.dataSubmissionEnabled.v2", false);'
      'user_pref("datareporting.policy.firstRunURL", "");'
      'user_pref("default-browser-agent.enabled", false);'
      'user_pref("device.sensors.enabled", false);'
      'user_pref("device.sensors.motion.enabled", false);'
      'user_pref("device.sensors.orientation.enabled", false);'
      'user_pref("devtools.enabled", true);'
      'user_pref("devtools.onboarding.telemetry.logged", false);'
      'user_pref("distribution.iniFile.exists.value", true);'
      'user_pref("distribution.mozilla-EMEfree.bookmarksProcessed", true);'
      'user_pref("dom.allow_scripts_to_close_windows", false);'
      'user_pref("dom.battery.enabled", false);'
      '// user_pref("dom.caches.enabled", false);'
      'user_pref("dom.disable_beforeunload", true);'
      'user_pref("dom.disable_window_flip", false);'
      'user_pref("dom.disable_window_move_resize", true);'
      'user_pref("dom.disable_window_open_feature.close", true);'
      'user_pref("dom.disable_window_open_feature.location", false);'
      'user_pref("dom.disable_window_open_feature.minimizable", true);'
      'user_pref("dom.disable_window_open_feature.personalbar", true);'
      'user_pref("dom.disable_window_open_feature.titlebar", true);'
      'user_pref("dom.disable_window_status_change", false);'
      '// user_pref("dom.enable_performance", false);'
      'user_pref("dom.enable_performance_navigation_timing", false);'
      'user_pref("dom.enable_performance_observer", false);'
      '// user_pref("dom.enable_resource_timing", false);'
      '// user_pref("dom.enable_user_timing", false);'
      'user_pref("dom.event.clipboardevents.enabled", false);'
      'user_pref("dom.gamepad.enabled", false);'
      'user_pref("dom.gamepad.extensions.enabled", false);'
      'user_pref("dom.gamepad.non_standard_events.enabled", false);'
      'user_pref("dom.idle-observers-api.enabled", false);'
      'user_pref("dom.indexedDB.logging.details", false);'
      'user_pref("dom.indexedDB.logging.enabled", false);'
      'user_pref("dom.ipc.plugins.flash.subprocess.crashreporter.enabled", false);'
      'user_pref("dom.ipc.plugins.reportCrashURL", false);'
      'user_pref("dom.ipc.processCount", 1);'
      'user_pref("dom.keyboardevent.dispatch_during_composition", false);'
      'user_pref("dom.mozApps.used", true);'
      'user_pref("dom.netinfo.enabled", false);'
      'user_pref("dom.network.enabled", false);'
      'user_pref("dom.private-attribution.submission.enabled", false);'
      'user_pref("dom.push.connection.enabled", false);'
      'user_pref("dom.push.enabled", false);'
      'user_pref("dom.push.serverURL", "");'
      'user_pref("dom.quotaManager.backgroundTask.enabled", false);'
      '// user_pref("dom.security.https_first", true);'
      'user_pref("dom.security.https_only_mode", true);'
      'user_pref("dom.security.https_only_mode_ever_enabled", true);'
      'user_pref("dom.security.https_only_mode_ever_enabled_pbm", true);'
      'user_pref("dom.serviceWorkers.enabled", false);'
      'user_pref("dom.sms.enabled", false);'
      'user_pref("dom.vibrator.enabled", false);'
      'user_pref("dom.vr.enabled", false);'
      'user_pref("dom.vr.oculus.enabled", false);'
      'user_pref("dom.vr.oculus.invisible.enabled", false);'
      'user_pref("dom.vr.poseprediction.enabled", false);'
      'user_pref("dom.vr.require-gesture", false);'
      'user_pref("dom.w3c_touch_events.enabled", 0);'
      'user_pref("dom.webaudio.enabled", false);'
      'user_pref("dom.webnotifications.enabled", false);'
      'user_pref("dom.webnotifications.serviceworker.enabled", false);'
      'user_pref("experiments.activeExperiment", false);'
      'user_pref("experiments.enabled", false);'
      'user_pref("experiments.manifest.uri", "");'
      'user_pref("experiments.supported", false);'
      'user_pref("extensions.abuseReport.enabled", false);'
      'user_pref("extensions.blocklist.enabled", false);'
      'user_pref("extensions.blocklist.pingCountTotal", 2);'
      'user_pref("extensions.blocklist.pingCountVersion", 0);'
      'user_pref("extensions.bootstrappedAddons", "{}");'
      'user_pref("extensions.databaseSchema", 16);'
      'user_pref("extensions.e10sBlockedByAddons", true);'
      'user_pref("extensions.e10sBlocksEnabling", true);'
      'user_pref("extensions.enabledAddons", "SimpleX%40White.Theme:3.0");'
      'user_pref("extensions.formautofill.addresses.enabled", false);'
      'user_pref("extensions.formautofill.creditCards.enabled", false);'
      'user_pref("extensions.formautofill.heuristics.enabled", false);'
      'user_pref("extensions.getAddons.cache.enabled", false);'
      'user_pref("extensions.getAddons.databaseSchema", 5);'
      'user_pref("extensions.getAddons.showPane", false);'
      'user_pref("extensions.htmlaboutaddons.discover.enabled", false);'
      'user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);'
      '// user_pref("extensions.manifestV3.enabled", false);'
      'user_pref("extensions.pendingOperations", false);'
      'user_pref("extensions.pocket.api", "");'
      'user_pref("extensions.pocket.enabled", false);'
      'user_pref("extensions.pocket.oAuthConsumerKey", "");'
      'user_pref("extensions.pocket.site", "");'
      'user_pref("extensions.privatebrowsing.notification", true);'
      'user_pref("extensions.ui.dictionary.hidden", true);'
      'user_pref("extensions.ui.locale.hidden", true);'
      'user_pref("extensions.unifiedExtensions.enabled", false);'
      'user_pref("extensions.webcompat-reporter.enabled", false);'
      'user_pref("extensions.webcompat-reporter.newIssueEndpoint", "");'
      'user_pref("extensions.webservice.discoverURL", "");'
      'user_pref("findbar.highlightAll", true);'
      'user_pref("font.internaluseonly.changed", false);'
      'user_pref("font.size.fixed.x-cyrillic", 13);'
      'user_pref("font.size.monospace.x-cyrillic", 13);'
      'user_pref("full-screen-api.warning.delay", 250);'
      'user_pref("full-screen-api.warning.timeout", 1500);'
      'user_pref("general.skins.selectedSkin", "simplewhitex");'
      'user_pref("general.smoothScroll", false);'
      'user_pref("general.warnOnAboutConfig", false);'
      'user_pref("geo.enabled", false);'
      'user_pref("geo.provider.ms-windows-location", false);'
      'user_pref("geo.wifi.logging.enabled", false);'
      'user_pref("geo.wifi.uri", "");'
      'user_pref("gfx.canvas.skiagl.dynamic-cache", false);'
      'user_pref("gfx.direct3d.last_used_feature_level_idx", 0);'
      'user_pref("gfx.work-around-driver-bugs", false);'
      'user_pref("identity.fxaccounts.enabled", false);'
      'user_pref("intl.charsetmenu.browser.cache", "UTF-8");'
      'user_pref("javascript.options.shared_memory", true);'
      'user_pref("keyword.enabled", false);'
      'user_pref("layers.acceleration.force-enabled", true);'
      'user_pref("layers.deaa.enabled", false);'
      'user_pref("layers.geometry.opengl.enabled", false);'
      'user_pref("layers.mlgpu.sanity-test-failed", false);'
      'user_pref("lightweightThemes.update.enabled", false);'
      'user_pref("loop.enabled", false);'
      'user_pref("loop.feedback.formURL", "");'
      'user_pref("loop.gettingStarted.url", "");'
      'user_pref("media.autoplay.blocking_policy", 2);'
      'user_pref("media.autoplay.default", 5);'
      'user_pref("media.autoplay.enabled", false);'
      'user_pref("media.block-autoplay-until-in-foreground", true);'
      'user_pref("media.block-play-until-visible", true);'
      'user_pref("media.decoder-doctor.new-issue-endpoint", "");'
      'user_pref("media.eme.apiVisible", false);'
      'user_pref("media.eme.enabled", false);'
      'user_pref("media.getusermedia.aec_enabled", false);'
      'user_pref("media.getusermedia.noise_enabled", false);'
      'user_pref("media.getusermedia.screensharing.allowed_domains", "");'
      'user_pref("media.getusermedia.screensharing.enabled", false);'
      'user_pref("media.gmp-eme-adobe.enabled", false);'
      'user_pref("media.hardware-video-decoding.enabled", true);'
      'user_pref("media.hardware-video-decoding.failed", false);'
      'user_pref("media.hardware-video-decoding.force-enabled", true);'
      'user_pref("media.navigator.enabled", false);'
      'user_pref("media.navigator.permission.disabled", true);'
      'user_pref("media.navigator.video.enabled", false);'
      'user_pref("media.ondevicechange.enabled", false);'
      'user_pref("media.peerconnection.enabled", false);'
      'user_pref("media.peerconnection.ice.default_address_only", true);'
      'user_pref("media.peerconnection.ice.no_host", true);'
      'user_pref("media.peerconnection.ice.relay_only", true);'
      'user_pref("media.peerconnection.ice.tcp", false);'
      'user_pref("media.peerconnection.identity.enabled", false);'
      'user_pref("media.peerconnection.identity.timeout", 1);'
      'user_pref("media.peerconnection.turn.disable", true);'
      'user_pref("media.peerconnection.use_document_iceservers", false);'
      'user_pref("media.peerconnection.video.enabled", false);'
      'user_pref("media.video_stats.enabled", false);'
      'user_pref("media.videocontrols.picture-in-picture.improved-video-controls.enabled", true);'
      'user_pref("media.webspeech.recognition.enable", false);'
      'user_pref("media.webspeech.recognition.force_enable", false);'
      'user_pref("media.webspeech.synth.enabled", false);'
      'user_pref("media.wmf.deblacklisting-for-telemetry-in-gpu-process", false);'
      'user_pref("mousewheel.default.delta_multiplier_y", 400);'
      '// user_pref("mousewheel.min_line_scroll_amount", 5);'
      'user_pref("network.allow-experiments", false);'
      'user_pref("network.captive-portal-service.enabled", false);'
      'user_pref("network.captive-portal-service.maxInterval", 0);'
      'user_pref("network.cookie.cookieBehavior", 1);'
      'user_pref("network.cookie.lifetimePolicy", 2);'
      'user_pref("network.cookie.prefsMigrated", true);'
      'user_pref("network.cookie.thirdparty.sessionOnly", true);'
      '// user_pref("network.dns.disableIPv6", true);'
      'user_pref("network.dns.disablePrefetch", true);'
      'user_pref("network.dns.disablePrefetchFromHTTPS", true);'
      'user_pref("network.http.altsvc.enabled", false);'
      'user_pref("network.http.altsvc.oe", false);'
      'user_pref("network.http.speculative-parallel-limit", 0);'
      'user_pref("network.dns.offline-localhost", true);'
      'user_pref("network.predictor.enabled", false);'
      'user_pref("network.predictor.enable-prefetch", false);'
      'user_pref("network.prefetch-next", false);'
      'user_pref("network.security.esni.enabled", true);'
      'user_pref("network.tcp.tcp_fastopen_enable", true);'
      'user_pref("network.trr.mode", 1);'
      'user_pref("nglayout.initialpaint.delay", 5);'
      'user_pref("pdfjs.enabledCache.state", false);'
      'user_pref("pdfjs.enableScripting", false);'
      'user_pref("pdfjs.migrationVersion", 2);'
      'user_pref("pdfjs.previousHandler.alwaysAskBeforeHandling", true);'
      'user_pref("pdfjs.previousHandler.preferredAction", 4);'
      'user_pref("plugin.disable_full_page_plugin_for_types", "application/pdf");'
      'user_pref("plugin.importedState", true);'
      'user_pref("pref.browser.homepage.disable_button.bookmark_page", false);'
      'user_pref("pref.browser.homepage.disable_button.current_page", false);'
      'user_pref("pref.browser.homepage.disable_button.restore_default", false);'
      'user_pref("pref.downloads.disable_button.edit_actions", false);'
      'user_pref("pref.general.disable_button.default_browser", false);'
      'user_pref("pref.privacy.disable_button.cookie_exceptions", false);'
      'user_pref("pref.privacy.disable_button.view_cookies", false);'
      'user_pref("pref.privacy.disable_button.view_passwords", false);'
      'user_pref("privacy.donottrackheader.enabled", true);'
      'user_pref("privacy.firstparty.isolate", false);'
      'user_pref("privacy.history.custom", true);'
      'user_pref("privacy.reduceTimerPrecision", true);'
      'user_pref("privacy.resistFingerprinting", false);'
      'user_pref("privacy.sanitize.migrateFx3Prefs", true);'
      'user_pref("privacy.socialtracking.block_cookies.enabled", true);'
      'user_pref("privacy.trackingprotection.enabled", true);'
      'user_pref("reader.parse-on-load.enabled", false);'
      'user_pref("readinglist.scheduler.enabled", false);'
      'user_pref("readinglist.server", "");'
      'user_pref("security.app_menu.recordEventTelemetry", false);'
      'user_pref("security.certerrors.recordEventTelemetry", false);'
      'user_pref("security.identityblock.show_extended_validation", true);'
      'user_pref("security.identitypopup.recordEventTelemetry", false);'
      'user_pref("security.insecure_connection_text.enabled", false);'
      'user_pref("security.protectionspopup.recordEventTelemetry", false);'
      'user_pref("security.secure_connection_icon_color_gray", false);'
      'user_pref("security.ssl.errorReporting.enabled", false);'
      'user_pref("security.ssl.errorReporting.url", "");'
      'user_pref("services.sync.clients.lastSync", "0");'
      'user_pref("services.sync.clients.lastSyncLocal", "0");'
      'user_pref("services.sync.declinedEngines", "");'
      'user_pref("services.sync.enabled", false);'
      'user_pref("services.sync.globalScore", 0);'
      'user_pref("services.sync.migrated", true);'
      'user_pref("services.sync.nextSync", 0);'
      'user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored", false);'
      'user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites", false);'
      'user_pref("services.sync.tabs.lastSync", "0");'
      'user_pref("services.sync.tabs.lastSyncLocal", "0");'
      'user_pref("signon.autofillForms", false);'
      'user_pref("signon.firefoxRelay.feature", "disabled");'
      'user_pref("signon.generation.enabled", false);'
      'user_pref("signon.management.page.breach-alerts.enabled", false);'
      'user_pref("signon.rememberSignons", false);'
      'user_pref("social.directories", "");'
      'user_pref("social.remote-install.enabled", false);'
      'user_pref("social.share.activationPanelEnabled", false);'
      'user_pref("social.shareDirectory", "");'
      'user_pref("social.toast-notifications.enabled", false);'
      'user_pref("social.whitelist", "");'
      'user_pref("toolkit.cosmeticAnimations.enabled", false);'
      'user_pref("toolkit.coverage.endpoint.base", "");'
      'user_pref("toolkit.crashreporter.infoURL", "");'
      'user_pref("toolkit.datacollection.infoURL", "");'
      'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
      'user_pref("toolkit.shopping.ohttpConfigURL", "");'
      'user_pref("toolkit.shopping.ohttpRelayURL", "");'
      'user_pref("toolkit.telemetry.archive.enabled", false);'
      'user_pref("toolkit.telemetry.bhrPing.enabled", false);'
      'user_pref("toolkit.telemetry.cachedClientID", "");'
      'user_pref("toolkit.telemetry.enabled", false);'
      'user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);'
      'user_pref("toolkit.telemetry.hybridContent.enabled", false);'
      'user_pref("toolkit.telemetry.newProfilePing.enabled", false);'
      'user_pref("toolkit.telemetry.optoutSample", false);'
      'user_pref("toolkit.telemetry.pioneer-new-studies-available", false);'
      'user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);'
      'user_pref("toolkit.telemetry.server", "");'
      'user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);'
      'user_pref("toolkit.telemetry.shutdownPingSender.enabledFirstSession", false);'
      'user_pref("toolkit.telemetry.unified", false);'
      'user_pref("toolkit.telemetry.updatePing.enabled", false);'
      'user_pref("toolkit.telemetry.unifiedIsOptIn", false);'
      'user_pref("toolkit.zoomManager.zoomValues", ".25,.3,.5,.67,.75,.8,.9,1,1.1,1.25,1.33,1.5,1.7,2,2.4,3,4,5");'
      'user_pref("ui.prefersReducedMotion", 1);'
      'user_pref("xpinstall.whitelist.add", "");'
      'user_pref("xpinstall.whitelist.add.180", "");'
      'user_pref("xul.panel-animations.enabled", false);'
      ''
      'user_pref("ui.useOverlayScrollbars", 1);'
      'user_pref("widget.gtk.overlay-scrollbars.enabled", true);'
      'user_pref("widget.non-native-theme.scrollbar.style", 5);'
      'user_pref("widget.windows.overlay-scrollbars.enabled", true);'
      '//  user_pref("widget.non-native-theme.scrollbar.style", 5);  //  Default = 0 ; macOs = 1 ; GTK = 2 ; Android = 3 ; W10 = 4 ; W11 = 5'
   )

   try {
      [IO.Directory]::CreateDirectory("$profilePath\chrome") | Out-Null
      Write-Host " ---> $($profilePath.Split('\')[-1])"

      $prefs = Join-Path $profilePath "prefs.js"
      [System.IO.File]::WriteAllLines($prefs, $prefsContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\prefs.js"
   } catch {
      Write-Host "$_.Exception.Message" @red
      $errorProfile = $true
   }

   $sstoreContent = '{"windows":[],"selectedWindow":0,"_closedWindows":[],"session":{},"scratchpads":[],"global":{}}'

   try {
      $sstore = Join-Path $profilePath "sessionstore.js"
      [System.IO.File]::WriteAllLines($sstore, $sstoreContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\sessionstore.js"
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
      $htmlProxy = $proxyResponse.Content.ReadAsStringAsync().Result
      if (-not $htmlProxy) {throw 'htmlProxy is NULL'}
      $lastproxy = $null
      $lastproxy = [version](
         (Get-HtmlLinks -Html $htmlProxy) -like "*/tag/*" -replace ".+/tag/v*" | Select-Object -First 1
      )
      if (-not $lastproxy) {throw 'lastproxy is NULL'}
      $urlproxy = 'https://github.com/Alexey71/opera-proxy/releases/download/v'+"$lastproxy"+'/opera-proxy.windows-amd64.exe'
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

# Настройка portable.ini
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

# Удаление хлама после закрытия браузера
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
if ($SqlVacuum) {Write-Host "Sqlite:    $SqlPath"     @darkcyan}
Write-Host                  "Profile:   $profilePath" @darkcyan
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

   # Разрядность исполняемого файла браузера
   $archExe = Get-Bitness -ExeFile "$AppPath\$ExeName"
   if (-not $archExe) {
      if ($RunMode -eq 1) {
         Show-Balloon -Message "Missed $ExeName" -MessageType "Error"
      }
      throw "Missed $ExeName"
   }

   # Наличие portable(32/64).dll
   if (-not [IO.File]::Exists("$AppPath\portable$($archExe).dll")) {
      Show-Balloon -Message "Missed portable$($archExe).dll" -MessageType "Error"
      throw "Missed portable$($archExe).dll"
   }

   # Настройка portable.ini
   try {if (-not (Check-IniFile)) {Write-Host "Not changed portable.ini"}}
   catch {throw "Error tuned portable.ini: $_"}

   # Настройка dependentlibs.list
   $list = @(Get-Content -Path "$AppPath\dependentlibs.list" -ErrorAction SilentlyContinue)
   if (-not ($list -like "portable$($archExe).dll")) {
      (@("portable$($archExe).dll")+$list -join "`n")+"`n" | Set-Content -Path "$AppPath\dependentlibs.list" -NoNewLine
      Write-Host "Add portable$($archExe).dll to dependentlibs.list: OK" @green
   }

   # Фильтр пустого Switches
   if ($Switches.Count -eq 0) {$Switches = @('-')}

   # Создание нового профиля
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

   # Запуск прокси
   $addr_port = $ProxyArg | ?{$_ -match '-bind-address (\d+\.\d+\.\d+\.\d+):(\d+)'} | %{@{$matches[1]=$matches[2]}}
   if (Get-Proxy -and $addr_port.Count -ne 0) {
       @(
         'user_pref("network.proxy.http", "'+$($addr_port.Keys)+'");'
         'user_pref("network.proxy.http_port", '+$($addr_port.Values)+');'
         'user_pref("network.proxy.ssl", "'+$($addr_port.Keys)+'");'
         'user_pref("network.proxy.ssl_port", '+$($addr_port.Values)+');'
         'user_pref("network.proxy.type", 1);'
      ) | Add-Content -LiteralPath "$profilePath\prefs.js" -ea 0 -Force
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

   # После завершения убрать данные прокси из настроек
   try {
      if ($addr_port.Count -ne 0) {
         $revert = Get-Content -LiteralPath "$profilePath\prefs.js" -ea 0 | Where-Object {$_ -notlike "*network.proxy*"}
         Set-Content -LiteralPath "$profilePath\prefs.js" -Value $revert -ea 0 -Force
         Write-Host "Remove proxy settings: OK" @green
      }
   } catch {
      Write-Host "$_.Exception.Message" @red
   }

   # Очистка профиля
   if (-not $lastclean) {$lastclean='18032026'}
   
   $sinceclean = (New-TimeSpan -Start $([datetime]::parseexact($lastclean, 'ddMMyyyy', $null))).Days

   if ($sinceclean -ge [int]$CleanInterval) {
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
