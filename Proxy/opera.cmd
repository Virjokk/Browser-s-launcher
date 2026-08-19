<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Opera и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления при их выходе качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Можно выбрать редакцию (Stable, Beta, Developer, GX, Air) и разрядность (x64/x86), указав нужное значение в $Edition и $Bitness.
:: Портабельность обеспечивает version.dll от ca-x (https://github.com/ca-x/vivaldi_plus/) или
:: от Bush2021 (https://github.com/Bush2021/chrome_plus) по выбору, настраиваемому в переменной $VersionDll.
:: Конфиги version.dll настраиваются здесь же, в переменных $ConfigData,$ConfigCache в части имени и расположения папок профиля
:: и кэша, поэтому прописывать их напрямую в chrome++.ini/config.ini смысла нет.
:: Для работы version.dll делается инжект в файл opera.exe с помощью setdll (https://github.com/Bush2021/setdll).
:: Для проверки/скачивания обновлений и для браузера можно использовать opera-proxy (https://github.com/Alexey71/opera-proxy),
:: который будет скачан и запущен с заданными параметрами, при выходе новых версий будет автообновляться.
:: При установке/обновлении может применяться патч x_BORLAND_x (http://forum.ru-board.com/topic.cgi?forum=5&topic=51121&start=2780#4),
:: с которым можно использовать свой 0_zero_patch.ini, положив его рядом с батником. Разрешить патчинг - $CleanPatch = $true.
:: Если папка профиля существует и указан путь к ней в $ConfigData, то браузер запустится с этим профилем.
:: Если нет, то создается новый с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=2&topic=5915&start=100#10).
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
$ConfigData = "%app%\..\Profile\data" # путь к профилю, который будет добавлен в chrome++.ini/config.ini
$ConfigCache = "%app%\..\Cache" # путь к кэшу, который будет добавлен в chrome++.ini/config.ini
$RunMode = 0 # 0 - обычный режим, 1 - только запуск, 2 - только проверка/установка обновлений
$CreateShortcut = $false # создать ярлык на рабочем столе
$AskUpdate = $true # перед обновлением спрашивать
$Backup = $false # при обновлении создавать в папке батника zip-бэкап профиля
$MakeStub = $false # создавать взамен удаляемых в профиле папок ($DelDirs) файлы-заглушки нулевого размера
$CleanPatch = $false # при установке/обновлении применять к opera_browser.dll патч от x_BORLAND_x
$Edition = 0 # 0 - Stable, 1 - Beta, 2 - Developer, 3 - GX, 4 - Air (x64 only)
$Bitness = "x64" # для 32bit-версии указать "x86"
$VersionDll = 0 # 0 - библиотека dll от Bush2021, 1 - от ca-x (czyt.tech)
$FreezVer = "" # номер конкретной версии, которая не будет обновляться, напр., 95.0.4635.90 - последняя Stable для win 7,8
$AppDir = "App" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$DllPath = "" # локальный путь к windows_x86/x64.zip, если оставить пустым, будет скачан с github.com
$SetDllPath = "" # локальный путь к setdll.7z, если оставить пустым, будет скачан с github.com
$UseProxy = 0 # 0 - не включать, 1 - только для браузера, 2 - для браузера и для проверки/закачки обновлений
$ProxyPath = "" # путь к файлу опера прокси, если оставить пустым, будет скачан с github.com (при $UseProxy <> 0)
$ProxyArg = "-override-proxy-address 77.111.247.79","-api-proxy `"http://s6402013510115:s1609900520681@202.28.17.8:8080`"" # параметры прокси
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # ключи запуска браузера
   "--no-default-browser-check"
#   "--disable-gpu-program-cache"
#   "--disable-gpu-shader-disk-cache"
#   "--disk-cache-size=1"
   "--show-component-extension-options"
   "--proxy-server=$(($ProxyArg -Split " ")[1])"
#   "--disable-background-networking" # раскомментировать этот и следующий ключи для запрета автообновления расширений
#   "--disable-component-update"
   "--disable-breakpad"
   "--disable-crash-reporter"
   "--allow-legacy-mv2-extensions"
   "--enable-features=PasswordImport"
#   "--disable-features=PrintCompositorLPAC"
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
)

$DelDirs = @( # папки профиля, удаляемые после закрытия браузера
   "ActorSafetyLists"
   "adblocker_data"
   "AmountExtractionHeuristicRegexes"
   "Cache"
   "CertificateRevocation"
   "component_crx_cache"
   "CookieReadinessList"
   "Crash Reports"
   "DawnCache"
   "DawnGraphiteCache"
   "DawnWebGPUCache"
   "dictionaries"
   "extensions_crx_cache"
   "GPUCache"
   "GPUPersistentCache"
   "GraphiteDawnCache"
   "GrShaderCache"
   "hyphen-data"
   "MediaFoundationWidevineCdm"
   "MEIPreload"
   "OpenCookieDatabase"
   "Opera*"
   "PKIMetadata"
   "ProbabilisticRevealTokenRegistry"
   "Safe Browsing"
   "SafetyTips"
   "ShaderCache"
   "themes*"
   "WidevineCdm"
   "Default\adblocker_data"
   "Default\AmountExtractionHeuristicRegexes"
   "Default\AutofillStrikeDatabase"
   "Default\blob_storage"
   "Default\BudgetDatabase"
   "Default\Cache"
   "Default\CertificateRevocation"
   "Default\ClientCertificates"
   "Default\Crash Reports"
   "Default\DawnGraphiteCache"
   "Default\DawnWebGPUCache"
   "Default\dictionaries"
   "Default\GCM Store"
   "Default\GPUCache"
   "Default\GraphiteDawnCache"
   "Default\GrShaderCache"
   "Default\hyphen-data"
   "Default\Jump List Icons*"
   "Default\MediaFoundationWidevineCdm"
   "Default\MEIPreload"
   "Default\Opera*"
   "Default\PersistentOriginTrials"
   "Default\PKIMetadata"
   "Default\Platform Notifications"
   "Default\SafetyTips"
   "Default\Safe Browsing Network"
   "Default\Service Worker\Cache*"
   "Default\ShaderCache"
   "Default\Shared*"
   "Default\Site Characteristics Database"
   "Default\StatsSessions"
   "Default\Sync App Settings"
   "Default\VideoDecodeStats"
   "Default\wallpapers_cache*"
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
   "adblocker_rules.json"
   "au_global_storage*"
   "browser.js"
   "default_partner_content.json"
   "Opera-spare.pma"
   "PartnerRules"
   "partner_speeddials.json"
   "siteprefs.json"
   "Variations"
   "VariationsSafeSeedV2"
   "VariationsSeedV2"
   "Default\*.bak"
   "Default\*.tmp"
   "Default\*_file"
   "Default\au_global_storage*"
   "Default\BookmarkMergedSurfaceOrdering"
   "Default\BookmarksExtras"
   "Default\BrowserMetrics*"
   "Default\daily_wallpapers.json"
   "Default\DIPS*"
   "Default\InterestGroups"
   "Default\MediaDeviceSalts"
   "Default\Network\SCT Auditing Pending Reports"
   "Default\Network\Reporting and NEL*"
   "Default\Opera Custom Icon.ico"
   "Default\PartnerRules"
   "Default\PreferredApps"
   "Default\PrivateAggregation"
   "Default\README"
   "Default\Reporting and NEL"
   "Default\rhs.dat"
   "Default\SCT Auditing Pending Reports"
   "Default\SharedStorage*"
   "Default\spotlight_campaigns.json"
   "Default\ssdfp*"
   "Default\suggestions_cache.json"
   "Default\Translate Ranker Model"
#  Работа браузера во многом ломается, раскомментируйте, если приватность важнее потери данных
#   "*-journal"
#   "Last *"
#   "Default\*.db"
#   "Default\*.ldb"
#   "Default\*-journal"
#   "Default\Affiliation Database*"
#   "Default\Device Bound Sessions"
#   "Default\Extension State\*.log"
#   "Default\Extension State\*.ldb"
#   "Default\File System\Origins\*.log"
#   "Default\Last Session*"
#   "Default\Last Tabs*"
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
#   "Default\WebStorage\QuotaManager*"
)

$DelReg = @( # данные реестра, удаляемые после закрытия браузера
   "HKEY_CURRENT_USER\SOFTWARE\Opera Software"
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

$BlackList = @( # список блокировки встроенных расширений для нового профиля, 1 - блокировать, 0 - оставить
   "aelmefcddnelhophneodelaokjogeemi 1" # Twitch
   "ahfgeienlihckogmohjhadlkjgocpleb 1" # Chrome webstore
   "bcibcaaakpeekhbnddgnajbmjdcemfkf 0" # Opera addons
   "bennllbledkboeijomefbhpidmhfkoih 1" # Web Feed Popup
   "bgpmiljelfnilfcfmoppijdkmccbccel 1" # Stormcrow
   "blhcicojjhpbkbjkcfmbpjjjndljmfon 1" # opera-startpage-special
   "bmomlmlebemnegohbcdkbimolmpfbfkh 1" # Instagram Notifications
   "cbnpimmlikdmfccbjhbjlmonkehnlofh 1" # User CSS
   "cgloclgndbkhmjcaddholfcgghcgmmig 1" # Opera welcome page
   "cofphmcjpepfemkcobighilnnmnpodbg 1" # GX Cleaner sidebar panel
   "dbekdmnaopdgflfbkodfbackiiggdlhb 1" # Take a Break
   "dhenbdnfbgdadlbojchhimlmjlpcfpee 1" # Auth Helper
   "dlkeifdhkecgglmjpdeiccjpcmhagffp 1" # Air Intro
   "ebongfbmlegepmkkdjlnlmdcmckedlal 1" # Opera Touch Background
   "efpeldimhbhjejgcdcbhmjllaafhjmge 1" # VKontakte Notifications
   "ehlmjgafbankbokkgbjnalkgahahjgbd 1" # Opera-intro
   "ekhkckippcmagmjmbjncnlgiohlgaloc 1" # GXC Page
   "elkloalhpglgboehkapabfhjpmkmeook 1" # Opera Tutorials Page
   "enegjkbbakeegngfapepobipndnebkdk 1" # Rich Hints Agent
   "enmlgamfkfdemjmlfjeeipglcfpomikn 1" # News feed handler
   "ffeocbomcpokpmjkkloomhnflpjmkjpi 0" # Default mod
   "gemikcofekbgchaopjcbkbejolnkehgk 1" # Eye Support Overlay
   "gojhcdgcpbpfigcaejpfhfegekdgiblk 1" # Opera Wallet
   "hhckidpbkbmoeejbddojbdgidalionif 0" # Video handler
   "hlgnlpcakcbhfheemdcodfddnojhimjn 1" # Lights
   "igpdmclhhlcpoindmhkhillbfhdgoegm 1" # Aria
   "jaocpokicpmlhbchlodlkiochdkmophj 1" # Aliexpress Obsever
   "jbbopffnmpigiiejdknggggagconaelh 1" # Aurora
   "jifbgnmbgbdiedhdecealmlgmekpagde 1" # Opera AI
   "kbmoiomgmchbpihhdpabemajcbjpcijk 1" # Amazon Assistant Promotion
   "knohfebhibeknbfioecpdmdkjkjdnjnl 0" # Bookmarks
   "kobomdddpdjfpdpkfieihgdcefokgcnd 1" # GX Pages
   "lcmpcbiknifdfieonipkoebfppegdmpp 1" # Cashback Page
   "llpiooofdeacaeccmkfmcolhpggemicb 1" # Opera Pinboard Portal
   "mbcghjbibnjcclnoddklipnkmggfinfb 1" # Opera GX Nitro
   "mchcgpoacfgcfeidgjhokjgiblhhpcgn 1" # Zen Media Cache
   "mfglbjdihkhhnimlecioccjbjiepicip 1" # Opera Sync Auth Flow
   "mhjfbmdgcfjbbpaeojofohoefgiehjai 0" # Chromium PDF Viewer
   "mjahececmjlmafhbafbbopnfgkigfdgc 1" # gx.store
   "mlgoafdnenppocminhopgjkicnieaodp 1" # Opera Air Boosts
   "ndbnfbenjdkkckmlklmjpipaokfccegf 1" # Midsommar
   "nkeimhogjdpnpccoofpliimaahmaaome 1" # Google Hangouts
   "nmeeibajhbcldcphgjpmailfheoikbjn 1" # Help Opera Page
   "obhaigpnhcioanniiaepcgkdilopflbb 0" # Background worker
   "ocpleophfhddnogoadhmhpbjanddmnnj 1" # GX Corner Page
   "odndjkngipngdmdlfodecoelobjbidna 1" # Opera In-App Notification Portal
   "ompjkhnkeoicimmaehlcmgmpghobbjoj 1" # Cashback Assistant
   "onigllbobbpllnfcjanphobocbkcdghh 1" # Discord Notifications
   "pebomakhlodngdfjibemmpmbjgkcmboh 1" # Opera vpn pro page
)

$SetupExclude = @( # папки и файлы, исключаемые из состава браузера при установке/обновлении
   "Assets"
   "MEIPreload"
   "assistant_package"
   "CChromaEditorLibrary64.dll"
   "CUESDK.x64_2017.dll"
   "dxcompiler.dll"
   "dxil.dll"
   "files_list"
   "headless*"
   "installer*"
   "launcher.*"
   "mojo_core.dll"
   "notification_helper.exe"
   "opera*.sig"
   "opera_autoupdate.*"
   "opera_crashreporter.exe"
   "opera_gx_splash.exe"
   "opera.visualelementsmanifest.xml"
   "Resources.pri"
   "root_files_list"
   "win8_importing.dll"
   "win10_share_handler.dll"
   "localization\*FEMININE.pak"
   "localization\*MASCULINE.pak"
   "localization\*NEUTER.pak"
   "localization\af.pak"
   "localization\am.pak"
   "localization\ar.pak"
   "localization\as.pak"
   "localization\az.pak"
   "localization\be.pak"
   "localization\bg.pak"
   "localization\bn.pak"
   "localization\bs.pak"
   "localization\ca.pak"
   "localization\cs.pak"
   "localization\cy.pak"
   "localization\da.pak"
   "localization\de.pak"
   "localization\el.pak"
   "localization\en-GB.pak"
   "localization\en-VO.pak"
   "localization\es-419.pak"
   "localization\es.pak"
   "localization\et.pak"
   "localization\eu.pak"
   "localization\fa.pak"
   "localization\fi.pak"
   "localization\fil.pak"
   "localization\fr-CA.pak"
   "localization\fr.pak"
   "localization\gl.pak"
   "localization\gu.pak"
   "localization\he.pak"
   "localization\hi.pak"
   "localization\hr.pak"
   "localization\hu.pak"
   "localization\hy.pak"
   "localization\id.pak"
   "localization\is.pak"
   "localization\it.pak"
   "localization\ja.pak"
   "localization\ka.pak"
   "localization\kk.pak"
   "localization\km.pak"
   "localization\kn.pak"
   "localization\ko.pak"
   "localization\ky.pak"
   "localization\lo.pak"
   "localization\lt.pak"
   "localization\lv.pak"
   "localization\mk.pak"
   "localization\ml.pak"
   "localization\mn.pak"
   "localization\mr.pak"
   "localization\ms.pak"
   "localization\my.pak"
   "localization\nb.pak"
   "localization\ne.pak"
   "localization\nl.pak"
   "localization\or.pak"
   "localization\pa.pak"
   "localization\pl.pak"
   "localization\pt-BR.pak"
   "localization\pt-PT.pak"
   "localization\ro.pak"
   "localization\si.pak"
   "localization\sk.pak"
   "localization\sl.pak"
   "localization\sq.pak"
   "localization\sr-Latn.pak"
   "localization\sr.pak"
   "localization\sv.pak"
   "localization\sw.pak"
   "localization\ta.pak"
   "localization\te.pak"
   "localization\th.pak"
   "localization\tr.pak"
   "localization\uk.pak"
   "localization\ur.pak"
   "localization\uz.pak"
   "localization\vi.pak"
   "localization\zh-CN.pak"
   "localization\zh-HK.pak"
   "localization\zh-TW.pak"
   "localization\zu.pak"
)

$Trash = @( # папки и файлы вне профиля, удаляемые после закрытия браузера
   "$env:AppData\Opera Software"
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

if ($Bitness -ne 'x86' -or $Edition -eq 4) {$Bitness = 'x64'}

$BrowserName = $(switch ($Edition) {
   1 {"Opera Beta"}
   2 {"Opera Developer"}
   3 {"Opera GX"}
   4 {"Opera Air"}
   default {"Opera"}
})+" $Bitness"

$ExeName = "opera.exe"

if (-not $ProxyPath) {$ProxyPath = "$scriptPath\opera-proxy.windows-amd64.exe"}

if (-not $ConfigData) {$ConfigData = "%app%\..\Profile\data"}
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
$Script:MutexName = "Global\OperaPortable$($scriptName -replace '[\\:]','_')"

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
             'AAABAAEAGDAQAAEABADoAQAAFgAAACgAAAAYAAAAMAAAAAEABAAAAAAAgAEA'
             'AAAAAAAAAAAAEAAAAAAAAAAAAAAAgAAAAACAAACAgAAAAACAAIAAgAAAgIAA'
             'gICAAMDAwAD/AAAAAP8AAP//AAAAAP8A/wD/AAD//wD///8AAAAAAAAAAAAA'
             'AAAAAAAAAERMxEQAAAAAAAAATEREREzEAAAAAAAERERMzMzMwAAAAADEREzA'
             'DMzMzAAAAAxERMAAAAzMzMAAAExETAAAAADMzMwAAMzMxAAAAADMzMwABMzM'
             'wAAAAAAMzMzADMzMwAAAAAAMzMzADMzMwAAAAAAMzMzADMzMwAAAAAAMzMzA'
             'DMzMwAAAAAAMzMzADMzMwAAAAAAMzMzADMzMwAAAAAAMzMzADMzMwAAAAAAM'
             'zMzAAMzMzAAAAADMzMwAAMzMzAAAAADMRMwAAAzMzMAAAARETMAAAADMzMzA'
             'DMRETAAAAAAMzMzMxERMwAAAAAAAzMzMzMzMAAAAAAAAAMzMzMwAAAAAAAAA'
             'AAAAAAAAAAAA////AP8A/wD8AD8A+AAfAPAYDwDgfgcAwP8DAMD/AwCB/4EA'
             'gf+BAIH/gQCB/4EAgf+BAIH/gQCB/4EAgf+BAMD/AwDA/wMA4H4HAPAYDwD4'
             'AB8A/AA/AP8A/wD///8A'
      ) -join ''
   if ($Edition -eq 1) {$iconBase64 = @(
             'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAQAQA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAA////Dv///4/////T////6f////H////z'
             '////9P////T////z////8f///+n////T/f39kP///w4AAAAA////Ev///9X/'
             '//////////////+mpqb/UlJS/x4eHv8mJib/bW1t/7q6uv//////////////'
             '///+/v7W////Ev///5f//////////8/Pz/8iIiL/AAAA/wAAAP9OTk7/tLS0'
             '/2lpaf84ODj/S0tL/9PT0////////////////5f////g/////8/Pz/8AAAD/'
             'AAAA/wAAAP+jo6P///////////+ampr/AAAA/wAAAP8BAQH/z8/P////////'
             '///g////9f////8YGBj/AAAA/wAAAP+AgID//////////////////////6en'
             'p/8AAAD/AAAA/xgYGP//////////9f////yfn5//AAAA/wAAAP8UFBT/////'
             '///////+/v7//v7+////////////Ly8v/wAAAP8AAAD/n5+f//////z/////'
             'S0tL/wAAAP8AAAD/YGBg/////////////////////////////////4eHh/8A'
             'AAD/AAAA/0tLS////////////ykpKf8AAAD/AAAA/4uLi///////////////'
             '//////////////////+vr6//AAAA/wAAAP8pKSn///////////8oKCj/AAAA'
             '/wAAAP+MjIz/////////////////////////////////sLCw/wAAAP8AAAD/'
             'KCgo////////////SEhI/wAAAP8AAAD/ZGRk////////////////////////'
             '/////////4qKiv8AAAD/AAAA/0hISP///////////Jqamv8AAAD/AAAA/xgY'
             'GP////////////7+/v////////////////80NDT/AAAA/wAAAP+ampr/////'
             '/P////b/////ExMT/wAAAP8AAAD/jIyM//////////////////////+vr6//'
             'AAAA/wAAAP8TExP///////////b+/v7j/////8jIyP8AAAD/AAAA/wAAAP+y'
             'srL///////////+jo6P/AAAA/wAAAP8AAAD/x8fH///////+/v7j/f39n///'
             '////////xcXF/xoaGv8AAAD/AAAA/2FhYf/FxcX/a2tr/zY2Nv9ERET/ycnJ'
             '////////////////nv///xj+/v7g////////////////mJiY/0NDQ/8QEBD/'
             'HBwc/2RkZP+wsLD//////////////////v7+4P///xgAAAAA////F/39/aL+'
             '/v7j////9v////z///////////z8/P///////////P////b+/v7j////ov//'
             '/xcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
      ) -join ''
   }
   if ($Edition -eq 2) {$iconBase64 = @(
             'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAAWQkZJ1cKGcNUChfxVAoW+lQLFP5UCxP/'
             'UwsR/1MLEf9UCxP/VAsU/lQKFvpUChfxUwoYw1EJGCgAAAAAagogLW4MI/tk'
             'CyD/WAsc/3NSVv/Gvr//6ufo//7+/v/+/f3/6ebm/8S8vf9yUVX/Vgoc/1YK'
             'Hf9VCh37UgkbLoAMKMyADSr/bwwm/62eoP/6+vr///////38/P/Kw8T/i3V4'
             '/7+2t//Tzc7/5eDh/6OTlf9WCiH/VQoh/1IIHsyZDjH2kg4x/7ieof//////'
             '//////v7+/+Xh4r/VAkj/1QJI/+ai47/9fT1////////////qp2g/1MJJP9T'
             'CSL2rRA3/qtUYf/7+fr///////////+yp6r/Uwkk/1MJJP9TCST/Uwkk/5eH'
             'iv////////////r6+v9xUln/VAkk/rwROv/dv8L////////////w7u//Uwkk'
             '/1MJJP9TCST/Uwkk/1MJJP9TCST/39vc////////////xb6//1MJJP/JEjz/'
             '9ejq////////////y8TF/1MJJP9TCST/Uwkk/1MJJP9TCST/Uwkk/7asrv//'
             '/////////+vo6f9TCST/0xI+/////////////////7SqrP9TCST/Uwkk/1MJ'
             'JP9TCST/Uwkk/1MJJP+ZiIz/////////////////Uwkk/9MTPv//////////'
             '//////+zqqz/Uwkk/1MJJP9TCST/Uwkk/1MJJP9TCST/mIeK////////////'
             '/////1MJJP/KEjz/9err////////////ycLD/1MJJP9TCST/Uwkk/1MJJP9T'
             'CST/Uwkk/7Wsrv///////////+zq6v9TCST/vRE6/9/BxP///////////+/s'
             '7f9TCST/Uwkk/1MJJP9TCST/Uwkk/1MJJP/e2tr////////////IwMH/Wgkj'
             '/7EWN/+tWGT//Pv7////////////rKGj/1MJJP9TCST/Uwkk/1MJJP+TgIT/'
             '///////////7+/v/gVhe/2kMJP+sODH3lA4x/7yipf////////////v6+/+T'
             'g4b/Uwkk/1MJJP+TgYX/9PLz////////////tqKk/3ENJP+HHyX3rl0r0YcN'
             'L/9zCyv/saOl//v7+///////+/v7/8K6vP9/Zmv/xLy9/9nS0//k3t//spmc'
             '/3sPJf9/ECX/oD0k0bmCJDeJPyr9aAoo/1UJJP96X2X/y8TF//Du7///////'
             '/////+fi4//Hurz/i2Bl/3oPJP+FESX/lzIl/bZfITgAAAAAso0fOJdzIdF6'
             'VyH3XCck/lMJJP9TCST/Uwkk/1MJJP9ZCSP/Ywsj/3QjJP+TUSP3qmgh0b16'
             'HzcAAAAAgAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAAgAEAAA=='
      ) -join ''
   }
   if ($Edition -eq 3) {$iconBase64 = @(
             'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQA'
             'ABMLAAATCwAAAAAAAAAAAAAAAAAAAAAAAE4e+gBOHvoETh76PU4e+o5OHvqt'
             'Th76rU4e+rhOHvrFTh76lk4e+jlOHvsDTh76AAAAAAAAAAAAUSD8AE4e+gBO'
             'HvoSTh76e04e+ptOHvpTTh76MU4e+m5OHvqmTh76vE4e+sxOHvrOTh76fk4e'
             '+hBOHvoAUB79AE4e+gBOHvoSTh76kk4e+nNOHvoMTh76Hk4e+pZOHvp+Th76'
             'Lk4e+hhOHvoRTh76LE4e+oVOHvqQTh76EU4e+gBPH/sDTh76e04e+nNPHvsC'
             'Th76E04e+ppOHvpYTh76Ak4e+gBOHvojTh76XE4e+g5OHvoDTh76dU4e+nlP'
             'H/sCTh76PU4e+ptOHvoOTh76AE4e+m5OHvp1UB/7AU4e+gBOHvoATR36AE4e'
             '+lxOHvp1UCD9AE4e+g9OHvqbTh76Ok4e+o1OHvpVTh76AE4e+hNOHvqeTh76'
             'Hk4e+gAAAAAAAAAAAE4e+gBOHvoRTh76oU4e+ihOHvoATh76WE4e+opOHvqu'
             'Th76I04e+gBOHvo2Th76jk8e+wJPHvoAAAAAAAAAAABPH/sATh76AE4e+oFO'
             'HvpdTh76AE4e+iVOHvqtTh76sE4e+hFOHvoATh76TE4e+ntOHvoAUB/7AAAA'
             'AAAAAAAAAAAAAE4e+gBOHvpmTh76ek4e+gBOHvoSTh76sE4e+rBOHvoRTh76'
             'AE4e+kxOHvp7Th76AE8g+wAAAAAAAAAAAAAAAABOHvoATh76ZU4e+npOHvoA'
             'Th76Ek4e+rBOHvquTh76JE4e+gBOHvo2Th76jk8e+wJOHvoAAAAAAAAAAABP'
             'H/sATh76AE4e+n9OHvpfTh76AE4e+iVOHvqtTh76jE4e+lZOHvoATh76E04e'
             '+p5OHvofTh76AAAAAAAAAAAATh76AE4e+g9OHvqhTh76K04e+gBOHvpYTh76'
             'iU4e+jtOHvqbTh76D04e+gBOHvptTh76dk8f+wFOHvoATh76AE4e+gBOHvpY'
             'Th76eU8f+wFOHvoQTh76nE4e+jpPH/sCTh76eU4e+nZOH/oDTh76Ek4e+ppO'
             'HvpaTh76Ak4e+gBOHvoiTh76YE4e+hFOHvoDTh76dk4e+nhPH/sCTh76AE4e'
             '+hBOHvqPTh76dk4e+g1OHvodTh76lU4e+n9OHvowTh76G04e+hNOHvotTh76'
             'hk4e+o9OHvoQTh76AFAe/ABOHvoATh76EE4e+nhOHvqcTh76VU4e+jJOHvpu'
             'Th76pk4e+r1OHvrOTh76zk4e+nxOHvoQTh76AFIi+gAAAAAAAAAAAE4e+gBO'
             'HvoDTh76Ok4e+otOHvqtTh76rU4e+rdOHvrDTh76k04e+jdOHvoDTh76AAAA'
             'AAAAAAAA4AcAAMADAACAAQAAAIAAABHIAAAjxAAAI+QAACfkAAAn5AAAI+QA'
             'ACPEAAARwAAAAIAAAIABAADAAwAA4AcAAA=='
      ) -join ''
   }
   if ($Edition -eq 4) {$iconBase64 = @(
             'AAABAAEAECAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASFgoIElYKaBGVSnP'
             'Q1En/0JQJ/9BTybfQkwlkEBQKEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABA'
             'YAAIUWEwkEtaK/9IVin/RFIo/0BMJv87RCX/NTsj/zM5Iv8zPCD/Nz4ikFBQ'
             'IBAAAAAAAAAAAAAAAABwgEAQXHA2z1BhLv9MXCz/R1Yp/0BLJt83PSdwMDIl'
             'YDE0JL8xMyP/LzEi/yssH/87Pi/P////CAAAAAAAAAAAZ389j1ZpMf9RYi7/'
             'S1sr/0hYJp8AAAAAAAAAAAAAAAAAAAAAODgmfzc4Jf80NSP/LzEg/ywuHpAA'
             'AAAAeI9EQGR5Ov9YajL/UmMv/09hL+dQYDAQAAAAAAAAAAAAAAAAAAAAAAAA'
             'AABERS/HOzwn/zY4JP8xMiH/MDAgIHuWR49leTr/Wm0z/1RlMP9SZDCAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAAAAAAVVlASEFDKv88PSb/OTol/zU1Ip99l0jf'
             'ZXs7/1xvNf9XaDL/WmowMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///whI'
             'SS3/Q0Qq/z4/J/85OSLPgp1K/2l/PP9hdDj/W240/1BwMBAAAAAAAAAAAAAA'
             'AAAAAAAAAAAAAAAAAAAAAAAATk8v30hILP9FRin/PD0k/4ilTv9uhT//ZHk6'
             '/19yNv9ggEAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFNTMd9NTi7/'
             'SEkr/0BBJv+QsFPPdo9E/2mAPf9idzn/ZXo6MAAAAAAAAAAAAAAAAAAAAAAA'
             'AAAAAAAAAGBgMBBXWDP/UVIv/0xNLP9DRSffosVdn4CbSf9wh0D/aH08/2Z7'
             'OXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABcYDRAWloz/1VVMP9OTy3/SUkp'
             'kKfPYCCTs1T/eJFF/26FP/9qgT7f////CAAAAAAAAAAAAAAAAAAAAAAAAAAA'
             'Y2M3v1xcNP9XVzD/TU0r/0xMLEAAAAAAp8djiIejTf92j0T/b4ZA/26DPqAA'
             'AAAAAAAAAAAAAAAAAAAAaGg6gGNkN/9eXjT/VVYv/1BQLY8AAAAAAAAAAN/f'
             '3wigvmm3hKBM/3mTRv9yiUL/bYM7v2twO3Bzc0VobGw/p2ZmOP9iYjb/WVkx'
             '/1pgM89QUDAQAAAAAAAAAAAAAAAA////CJm5V4+Jp1D/fZhJ/3aQRP9zikL/'
             'bns+/2pzO/9ncDr/ZnI5/2Z3NY9AQEAIAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
             'AAAAqr+FMI+tVI+Ipk/fgZ1L/36YSf97lUbPe5VHn3iPSCAAAAAAAAAAAAAA'
             'AAAAAAAA8A8AAMADAACAAQAAg8EAAAPgAAAH4AAAB+AAAAfwAAAH8AAAB+AA'
             'AAfgAAAD4AAAg8EAAIABAADAAwAA8A8AAA=='
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

   if ($FreezVer) {
      $baseurl = switch ($Edition) {
         1 {'https://ftp.opera.com/pub/opera-beta/'; $product = 'beta_'}
         2 {'https://ftp.opera.com/pub/opera-developer/'; $product = 'Developer_'}
         3 {'https://ftp.opera.com/pub/opera_gx/'; $product = 'GX_'}
         4 {'https://ftp.opera.com/pub/opera_air/'; $product = 'Air_'}
         default {'https://ftp.opera.com/pub/opera/desktop/'}
      }
      if ($Bitness -ne 'x86') {$arch = '_x64'} else {$arch = $null}
      $url = $baseurl+$FreezVer+'/win/Opera_'+$product+$FreezVer+'_Setup'+$arch+'.exe'
      $msglink = "Link:      $url"
   } else {
      $product = ($BrowserName -Split " $Bitness")[0]
      $arch = if ($Bitness -eq 'x64') {'x64'} else {'i386'}
      $url = "https://www.opera.com/download/get/?partner=www&opsys=Windows&product=$($product)&arch=$($arch)&nothanks=yes"
      $msglink = "Request:   $url"
   }

   Write-Host "$msglink"

   try {
      $rawLink = (Make-NetRequest -Url $url).RequestMessage.RequestUri.AbsoluteUri
      $Script:distrLink = $rawlink -replace '.+(?=/pub/)','https://ftp.opera.com'
      if (-not $distrLink) {throw 'distrLink is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error check version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   if (-not $FreezVer) {Write-Host "Redirect:  $distrLink"}

   try {
      if ($distrLink -match '.+/(\d+\.\d+\.\d+\.\d+)/win.+') {
         $Script:latest = [version]$matches[1]
      }
      if (-not $latest) {throw 'latest is NULL'}
   } catch {
      Write-Host "$_.Exception.Message" @red
      Show-Balloon -Message "Error parsing version" -MessageType "Error"
      $Script:checkError = $true
      return $false
   }

   if ($FreezVer) {
      Write-Host "FreezVer:  v$latest"
   } else {
      Write-Host "Latest:    v$latest"
   }

   return $true
}

# Сравнение версий
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\op.exe" -Text $Latest -Pbar $true)) {throw}
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
      &($7zpath) e -t# -aoa "$tmpdir\op.exe" "2.7z" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack installer" -MessageType "Error"
         throw 'Error unpack installer'
      }
      Write-Host "Unpack installer: OK" @green

      &($7zpath) x -t7z -aoa "$tmpdir\2.7z" -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack 2.7z" -MessageType "Error"
         throw 'Error unpack 2.7z'
      }
      Write-Host "Unpack 2.7z: OK" @green

      &($7zpath) e -t7z -aoa "$SetDllPath" $("setdll-"+$Bitness+".exe") -o"$tmpdir" | Out-Null
      if ($LASTEXITCODE -ne 0) {
         Show-Balloon -Message "Error unpack setdll.7z" -MessageType "Error"
         throw 'Error unpack setdll.7z'
      }
      Write-Host "Unpack setdll.7z: OK" @green

      if ($VersionDll -eq 0) {
         &($7zpath) e -t7z -aoa "$DllPath" $("version-"+$Bitness+".dll") -o"$tmpdir" | Out-Null
         if ($LASTEXITCODE -ne 0) {
            Show-Balloon -Message "Error unpack setdll.7z" -MessageType "Error"
            throw 'Error unpack setdll.7z'
         }
         Write-Host "Unpack setdll.7z: OK" @green
         Move-Item -Path "$tmpdir\$("version-"+$Bitness+".dll")" -Destination "$tmpdir\version.dll" -Force -ea 0
      } else {
         try {
            Add-Type -Assembly System.IO.Compression.FileSystem -ErrorAction Stop
            [System.IO.Compression.ZipFile]::ExtractToDirectory($DllPath, "$tmpdir")
            Write-Host "Unpack windows_$Bitness.zip: OK" @green
         } catch {
            Show-Balloon -Message "Error unpack windows_$Bitness.zip" -MessageType "Error"
            throw $_
         }
      }

      # Инжект
      $setdll = $tmpdir+'\setdll-'+$Bitness+'.exe'
      $setdllarg = '/d:version.dll',$ExeName
      Start-Process -FilePath $setdll -ArgumentList $setdllarg -NoNewWindow -WorkingDirectory $tmpdir -Wait -ErrorAction Stop
      if ([IO.File]::Exists("$tmpdir\$ExeName#")) {
         Show-Balloon -Message "Error inject version.dll" -MessageType "Error"
         throw 'Error inject version.dll'
      }
      Write-Host "Inject version.dll: OK" @green

      # Распаковка и применение патча, хранящегося в BASE64
      if ($CleanPatch) {
         Write-Host "Patching opera_browser.dll..."
         $patch = @(
            'N3q8ryccAASZuGJYzVoAAAAAAAAkAAAAAAAAAES13qMAEDiOygk5/4gHP0TVZIva/RQUnvuLtQOf/QFZfXuybjgdevbKrGPODukUUSHTGX+dtLD'
            'WPIAPrYX3gPhU48UijLSIvHVUo2cguSGxRDKRgiyDuzDWl2BzVmrK/wDq5zKnaKpWRM3Q2HhoqtvPkSiOGucyxP2OlwO41wBZ3vVYLSJP9LssGS'
            'Or6hm4V7F97ORQ85Feem2Umu5hHhSwGfxiHqf+LqZvqJnB2G1Lq9R0n4fZRzbuODSU/aQchGtpLZWsrLb4VP0kEROPFk18NTL40Ch+p+v3nLLr8'
            'fx984nfBo5RJA+pP3jZc2jSzJzJCf4QiErlP/LVLKV/l2tYBHOc/YlpIiiuhHk7bDRfKJaZHmGVCfTee+pEBGmbV3zVREwvxCQJhBPiH4H2J63l'
            'YS9GgiJ0jRI3eKyshdh//AXE3oC+bYH5iPkIjQqllm2B5QcRefHPatYZXo0uaannMYLllAsIt4NLg2M3IiTNuS4nUkW+V644wrJi7ifx4qbt7/J'
            'hEGRo11koNzOtjFpHi+1qg6fbEgVtlMY2WMJtArmuXzCOlMxpHL0n+Z3EGNSvybQECXjCCWawU/zKZyvjyGVefQQ+XTpnI53AmkRst5+82rZqCu'
            'PWXjpNcGjkfpeTldcBR+6buNw34uuG5UMSXgSKxNMYBePvSP3oqmJVQEQRCq8JhJ6dQcU+XanoNK7Z0licHkQiqgTo2G0zfGbFDJogfgObSCFtn'
            'taIuRRknJ3gMLr3QvyJSSv9uWA0vUjxXZx5FmNsz/b8sZ//z0aWPV0uot2GEMO02ABq502qxSWexUU4toTEXeu8sQgMrWXHoiq6lHNjE3MiC8xk'
            'ZF/nZ/EYyb7jKO/Vip69kERUV4sUUJrJFFp1H4fztqDAnv6yJwJ5oE+d9Sq24UW450akR8BXOU6N3Gi4FFW/KRkYwhgw7nTVf3/idTul2sxPHSS'
            'lbGj5Gck40DSlqnqHFaM0VChubZuWwXPwVVP9rKEiCvVxsC3n1s6KpGy/LOk2skjcII/R1RxYEytQNhOqoAWOQI58YsBR+QIrMEOOSpIRotHADx'
            'rZvcQPR6O90FgpyXgn1yP9H9TjZ4/Igya1UtqQNLvaOuOMyFhGvR2PcMb51W6AAxWk0Is0kC/05ryGZibzDFRiWTXTQxREQ3ujhVqSWd8oE5liH'
            'mbCHJb1DzMGuFBscBRICDuLGN0fRD1KxDFjKSvXZGKPzCxl7cnCjE7qGliIoNj1z1yYKeWGgxgGe9ze35Bx9VSQ7JHuj4zsxcBM8IGSehBBlIuh'
            '3XIaQ/dx7e9Z3ir+y5nYNnx9DkhsZlng+XLshdhWpTtU+RnObDZF6hKtyQSAzOEcrd2U68B4TAP83xQnggOH87dtFahtcO4BEvP3Tnp86NXggXV'
            'vbJib/TkE0v7Mf1SXiHZHWbd7KUmJ0uT0SWjpqnK9+islVnjsrFpvOo58W6GPXYWWq1Vf8F5AiLNbnVvd6RJ0PSnwuRd15ewjdzQu6tQkhWd92E'
            'c4r5HO4MeNEkxGHrO8K7SAk1wm1/hoSkQ+vXlhK8GJQOOfEKH/2qEK+9FomtPfGA0PmZXnbtUYJpFK4n484lMGGGL0L2K9zknTALBkfo9r2fvBH'
            'TiO8BPRdiYWuwbEQ0K8g2eaD3162k3vfV6teDHvVm3be9RIp4XwwevkJgsugMl4ah3JyBe47kOMBywj7A8LsHdEuNIHeigz9k/8+6nYF+YLGnn2'
            'OO3S42QpQ9P6iBagV022x0RiQ/dOiVbz9ObgBFJ7kcjZ/Ijvk+33r6VP+kHLhvIBSoFDUMeI39JOvoAHPDWU/bRwude6PUG8kg7RtEUV+OjFi2A'
            'zMgPPCvYvEYOAWPDDLmPOHz5S73qJDNStAbU1kY2hrynvZanFMAcvSKMVwuClPbTTHC2GsDhx0kH5dQy5q0z6CXCicRwb5D0GWoAo/KSpOl/uKX'
            'DgLw1HEcAAAfcySuu88OMHv0oxEG5gZihg4jHr8Ko7y4iwF5RKHlfgPGo3gBoKPUNo9kNtqe44x5RUOVafpKNAVqzTFno4Ma60MM5I2ELHPgm/N'
            '0QaTJOm/QvWWJtdPwfM54lZTdFoM0e5bBVG/wT4lDmDo3QqF/Yete8rCMK0sflO1oQ0faRzK+sHPHQ3QO6V8UuKBqMi/lo1K7xGtlAYgTkz9Guy'
            'AFN7afoNRVnbPXBHSeLjFU3iZbQ6Ew1f+SvH3U2nRhSku2vTc/8WTaPut6qME3nO+5ZkYhFMztnRZRTRSIWnRUh+jYYFhPuC63mglZMGFSxdy2u'
            'IATnMx+z1WwNT7Mv3d3VuZ7rqRWguSKqxcB+WNSMXIv9D16EHlXv5yqE6QLDqfiJHLI14gIRcJkPlLY8zeJypkuNtcz1ymKOzGZIlUWx2x9oIXO'
            'vRxN4bGPORlEDmpxA1SULm3EF18mD2dmN8nmz1HcROL07Bck5DTUXIuMEEC9x6AtdZw5m1gFjeZ0VrSwxWdVCQ7IcC9qGsT7fOyZJlZcXPBw4t/'
            'tSlu2DJLlDPJGjbaO0Ug0VKcKBEVDQdRvUaUN1xzxyaCDib6ahKIYWbg3LNb0VEIIL01beFGHOTIlUUGeysZE/PFGhW8Wt3yQAWRubrUzUvQpSD'
            'hfgCiiO3/ZKSYZid6B/LMRzIDJ+qzYILpXFirOVvDyEGQkrwr3gT/TnmQmS6Nm2eScRHE5blWm8jysbYCsQAWkfCrh44FMSOjRhLmyBWjkKSOA1'
            'v0jVr03bnhCYrucxShzrOedqGqLRB8YW1EUnVaTh780K24j99vrliCTbXcN1riCZ3e5+Qu+VeTBzJuLqLRkssZjhlJ23df1IvXywsNto/keRCCH'
            'mSqzsQtkPS+M4ZhcGBEUWx5BBlh+FwODerBZhZ4j7hgk4bFl8YXOT8q9DfB3RX1mhIxC8g47Hc1AzcTiLUw/VyG6T6xUEZcv4Ah5wAdxQs5dd/7'
            'YM92tOyXTPE+WURm1xmCXH9tm71KEsTc4zs3ibPpv0iqlW8V2+Um0A/xD9QUFnjWyqvSLSMFGxhSvAoLAtS4GEIYOzmR4u7d9fG7UVGrzwWjdwX'
            '1a9ZNAMDJxx1ZSBDdSwWOTkYNpIhYxUkLfC6sKEw4PfprSo986nYpGhE1ONHEcA6n1rHAa6u1/EU62zBA984nHYXZ3T+PS5Ow+k0cExW8NsAwmD'
            'lEFtWFjZs+ioJSMVWncx1jz4QBM+0kIqB50f9kPfWcimI76IT0r9AwzfhhslsYEs8LNrS0b7PHi4wPpZU4sVsh4BqnYRiTLxIqnM0E7kD9D1KWh'
            'djPU0hvWIJpB5GwfAR3hRyltqTCny+yf1FBZpMFDavTAtqg3Os118XLxPfSjAZt1zo8GTXkToEME3lYmlNe3hZJDYvyiAbQuhafK72wg8vsUleW'
            'y5B8BoG8gGIXxI5yAci0/6saW27SiQqXNYVL+0KgSbAwcLIbvG4khQd9PniLLSRryXRD8vqAbb8Ui1Ns2gFwuAdhTXJi34aNMEqdBfDxZO4dUSA'
            '/rj6FZbw9UZbxFFwc9LyV9+pISWMZ00U3U983wbO1XwR+3+tcu78bRVZlZmvt+xI5EkBLUas++QEe+Nsc/2kOkwg6BY8UmXsShptmIqKIgfXZWX'
            'yWIYoCc3TdPUmwgshSVATIs4qhAutm+73LoSWlb6tAUYxmNtrotomZXLl8kIDFBj3UeWPRB7BF5B9/ni9AX+fA2PgYryiouo20xwSbtkzSjdNVz'
            'wfOhFaI7swiGS1q31n0DoF+L6isdb/7O7DB+lDlceJvhBxiJmUiG2uYwl+yYPxrlkedPDB2YsxRBZ+/uQ4qOJkMQVmXiQSrRyXn8iBYbckas0i4'
            'drEHeeeIL6PBbz5Pl4lUoSbJ55XP7wDA3rho1RGXttj5XUjdB8fvIMc2L65uEjmtRtgq53Bc77y0BhSelHl5UlCtboPnp8QKd1/TjVyUMmYXHpX'
            'wmU8KtV3Po+2YO+F1wrQz7UWBW1B0EmpGmQJRySADOY8xriCJmH3aoeeJfsMligY9Vy6tFysJuO6pUyyAcixU1O55NWRi8am1hxvTdu6sw0dMSq'
            'eiqJlPXWPifjRlZhxi9Nuc37gNeC9EI129Xv8Yn9VTe94LQ0P7qDwEdWiAVI0Kc34uFYs1F0PnJYOwEpoOcekS8dHGgyUHMC87dsVlG2D9IOQje'
            'Y3GKpwWz+2Z0CQWeuQkchmax4WS65EZTBPSFMhY+wVVzpL61SfOvbU/SOKN/JkeESp1P9aEJPvAJT/jr1QZpimyKk3z884X3nuivW4DMRrUq2yB'
            'OHUc4Hr28iNjVgyvv/7/XovTqZwNJFJ/VtAbMRWdS6beMGUunfZJjtr6svc6Wsqb27oP1VhVowNS8YJjKpwyIFizbXfbOqqSvVHKBnG9YYE9Jdx'
            'D8TGKvoAlhOBr4LSgqeQxxOSKaY3CaENRlFB6dbBZS6hBOyco9tI83WqvMhRQQmAlMo0mVFO8D/kiloQycCitRHGrfXuWL8NIjc2Bs+QE1vss/W'
            'yhpYatcTMmp7gUImK9bp2VQXf+yXXpz7eojXUDKNBo/ucxrbG7+iOig85N4pQbqvi6w8E7Nrc/wJrIWA+rFUS6HaNV5r86Lc64r8hZ/8cccZaim'
            'kO/exrL00Q/KOPXEcREhyp2mXNOD9pqbFOpuvMVGhEGengP38wBRaSz1LmeRgdnHBzOKQlImO7chbsWK+GpaZnE8dn3CH4EQqJkOkTWKRd23Vik'
            'ByysekzLqF1qian7YHDUhu09nmsyFP8dh/nFC8W32ipnMVcuz3G/WRJ604V4rqLbSY/bmSA8xWJosv0HflNuix/nRznGaDtZYuvsY33oUIG9QPo'
            'zyKV2YG/hjWgYkUT5k3BxJHFf1RzSFl+KI9YihTfkBJ6ocxiscJj2PfHt7KIy54hbduRMbpDlUdEOZ82Ndoguw1A0E2tZfSHfyJYwNFnDSEg+/n'
            'FW0kg6ISKkA9oY3JjJMdi8LSPeJw7TskTp4lTmjkS0EvsMhtz3YJdf8/0Ix6PUrlfPSaGX8DL/fdbkCb0zaOB1ZvdzeWMMzyrD46y2fLZmMbWHZ'
            'NeLOUo7sbLdb7DGpnoXAS+ItOUdo/PtOcWyZzMLOOoXA5XTe6Cvi7+cKOTfZ3VhT36UOm8ddQNLivtr2dy00Yet270FUT/omBO22YcVvEJ1Hu1H'
            '6s07DsCRq/t620gJ9mVfxK/e5Vg6/Ba3lxEErSK/1B648zAOVr8AsLnyFmjMS/GsV7c93NXHhBQK024MJy8nIb4XtMBEB5IbipQI8/YlkcK7dg8'
            'OVyqAZT92732UoHdRIQxXMIGZ5GLqDEjZd9V6tRAB8MgP+1PvwRd3sm42ydQTPB+R7FOcXyfseSBQ19gFnGXY9JberlUlI+KXYLZkiJE5kIcmn0'
            'ng6h8iASGNEzvN5Q0e/uuHXNHbbcvDfY7XABEILWfTkkG3cKqWX0YD95AVK0VkvJODqbyV/g9vsBrIdG5j4AEZiYeMI26gIg2uXCB5O10Li+MWU'
            'KYF2NOXykACpLmkohttTWsioBmSjfipDeNmOdE3CLx0zkTriutbf6N7MkMcMTk1NLoFLD54jEq+PG9tFL8Ox5ckAY+xlRZnYLNQKEQpe2Hi39mv'
            '2I9NHBsneNS2JfkOktzEUKAXgyVi2nn0vtvgC2TAVl0QnhviePHa++ZbMorfjHx291pDQ0/wZ2xpB1D9LSSJQY+K/8Skip+KZtphslMSzWN+lxz'
            'lyyBP6CQFekkALtCBmGwHY5GlU85VKVG//3u+bf4pDSA8wQjraTbP+yYOz9qvevI34kirgXiJmGdFP6Wm2YwY3SW19r4KOOwbssrIuZoMfHLbPq'
            'lMutCeRyBYEBIZLJ8QGWbjeWmwmtVUihYsC9yYu107Bhg3/KA3FNmQ44bDb8YYmZ7AdwY8fli2/Cw2AjdvxoYGAkPeeOz6HTEVVYl1r4nTmVnmq'
            '/eskpgQ0nmgD+YzCawNVyqFI0GRfZoVF1eRva31kF4ZXlSkh81vfLWI+KfHWMnHCJtC6TNqUwDNaL5ROqMjc2zpaegs0afXKzsZRT8/CMsYVbfL'
            '9GXvKEzSKrAAM3AnqzK70a1stEf6l79/tKVzqe2JgwMizVCf7/L55mjbAQj4cU6HjK0RO9qyJVu11087pgqRQ+HaekFVMcOpcqmDUj4gDU1sl2c'
            'Fcs7XvMJoagIdB8BsVJVhbvZcuJa8YAFh6shU9eAfnqWT7rqXDy1121tm1AGGNIoalvoboeDUcegBwm8NAO9crbw9rcFCoinKYMsNzYqtf5xQxV'
            'Xbn46gScz229DJCuCn7YaMPQoG9jKbMI/zussHGL0W47GYoCglybNBcmOep2aPdsbUuLibx6rGxs71373n4A7X1BOLqnmhI6tWJK5GnsDHfA80K'
            'E2TL+TOB3Dhxjdtmae6pNbCV7LvQFNj3t99wFTOybqaqctSHbwATfdR6yjCQ0Dhdf7BbPITymtJ++FT9AQG4JoeBls9Y8k0MBX52keDmTqPjJal'
            'GCmRmVW/2dz7KuNr/Qj95xowpHb6X4IovT+d1ClUD6edoAb9dt92KLUuJDk3up8pi+acPHePqkqS2IRG1MCc5o5igAJHi4kOxEPYNqL8kuFFWBd'
            'zPoPCl966yZEvv25xPrS7FRPd/MZIP8yTQzlpvSd00HTz/mAKD1DaPm7eOWo+ZQ3iX6c7r5ha/SvvUDOmveKltgTDcq/T1gFqOrD+YWb4BV1VV0'
            'lXxadA2+/dI88l9tNH/NsmbAEhL4ws7oCntdAF2Cec76/duN6MIn4EmvfaxntENta+wWbSp1cDgHveYYh4lQq+LRE78QDitgcaCPj0QuZ3Xwopy'
            'thlu3Q/zmsDgoT7J6KFzeLeerO/eY6M/uV2gCAukoNXAeUZKobdnWlfaF1d31KB1GTUARZTclMjvScxoAf7GmFa6Ibf8RLkLhhKglTLPSStRaZc'
            'p7MYVT1S4NxIjhfZw1MMYXpSpzoZO27eOb3krCfXdZpnAfd1PyitMOcY+/lUeL/jYbev7+CieoVmyVLEjpAhGrhQ7u7zoEAjfEKBJW4v9u8K01M'
            '8hswzfCv8cxCUGfdNCmYMDH522s8fNaE8PeRsP8VqOqZ6Afi2Vh9q4X1Hh9tjM5mS1xAauUMZHmqvIN7FhpYE9dk82McNo6WAfqO0V3MIKy3Zf5'
            'QF3Vt7rHWJRKY6fMzI6aLjxRPNbXaRBrA8rolVfL83sDXlSyqM0DJezU+QGSV62Xy7ZVI8Ljd/C+Opa59WpVDRj6OiPxcfIR7m66UbyO6+3vL+D'
            '0gOY47RDmNegbjg2+/DMZF7pFFcC6dRIMQb4qqhCd5YB+B4ptAxTMduzY67XZbxY1uHJmb9ZcWq+R8Ef/lT/VL8dNLYi0VndbO0J3B7YAxKSuZw'
            'xUGIcAmnXQ4f7etzZPd1rPPMzWJvd34NhXsnkCJFyHWUmFc8UVIn9KqCLLvDYYdmaveddkVktmeDUqItKfYFSBUCCnRnQpiL3bD1yWk7m25bHAd'
            '3+KPvHxEj0By/xLrdEzEpRngoc2dNB33mbhr6NbHl7TRg/8XskJXaPJEWJRJ3rBfp2Oz9VwDCtiGK2fmaKvwlQjFIQTAUlHq6UmA/naNZE4Gp0+'
            '2vMZks9Zsi0yLgdJPaZscfSAcVf4mZiPPuUMug+NRgfNjSpRTL6eWjQ6LiXe0gjAjodUCp0yz8XtVxE6ixWnT8itqtun8kmbm2h32Aex8dhUnhQ'
            'O6uHySfHCESe/v8Cz8ozXZHEKqU2nCzGb1eelg16QCULfrJN/fzjuJ9A0Xhk5QT1lk2UV+BA3wwk+OyPd5pFEB98VvpvW/KqkutlbB0sHModmXG'
            'szq8lPTS2BFaRdDiAk2IMAMtQ6qChVF8gJHsZ2iDc2WVk746NY6Lj+Bi5BPohG6yhYqa3l+K0MXiO1GbDZjhaoa+nYHXLiKzbbidjQqabh67EoH'
            '1Oeaps5v+XOAFzVoIwk8aofRn7EppEalsFqL0wiRUxa0wAqjbDGET9hJbdbVskAuxCn8tWMstdNHNzp2O6ZJs3sDtoSOIN1WcUtN43gy2ofjMHc'
            'Y7BWVsGAbhxAGgcXz6Yw1urwnyi36xMBM4u2l1cuVG7vrnuPLlf1zh3t26a/a0CVHl/bgDlI1tpjAx1NMr/lOGXoWtW83lX0NFqhtDt14SJO9AT'
            '7SEEU/w6tTPT3XNjQwSSXAi7wIEPmpJuHhnrO7dbkC0E5yGWuWKC/0uPZv6iqXUbofm7uxZ8Sbn5m5l5FyKhbjk9+ahVCuJ5chIAgYQu5AysLax'
            'HH9aGW5Jx+K9Q9RthQHEx6Yu+jbre/i1SZmtRJmii6fivf4GvtBXH+sRWE/NE1PC/kx3iIIeSK1g0b3MSEPjyco6NkHW58nQ1lMYotpVKPfIc45'
            'yTBZiDus+tinZBt+UdXmh1SflGkHD0fBzy3V1E2hXiaXJ3PZdzIeljF17lpmXs7cR28g+YoT/1jlh484Z/hw0NbgCbHZbE5rUm3+K2YD0quPa+2'
            '6RWo96Nx0xkFbSpseJ7r996Fjvx7wE4mscSMw0NrnLWVDOUnJQC63xShFoQy2/Jo4VVWeB+9qZYea3QmABNy15ytSU4YcYHo2JJCySJ8A+zWitL'
            'FyKAY4arH2AVgwXagsclOoocI2DdunnUetbAB/zrEq/77wTAbW7nnkfSz97WlcjXdg9atyJaTOITRCxVdvTWU2Bb8BGLE51GXaDyalKzDBtxVAU'
            'CWCn83e+h3ofeTX1CyKkJv2iWPU1f21WnY7poAaTVosYv6ZnO2PTypSo06k7nM5CcADOrMrFhZB716BbpMk/dAaUuvG0ZnbLMSraSsFQ4x0XYce'
            'Bsho4zHaKwzpdoSDrhBFaUzEo9+KVfuORl0GDLPnna+SH9OuMy2oxuUTrTmku5R2j9sUZA6+2x92EMPim2wRO05OU9IzeY6eajq0KfNJDwMtS+l'
            '5E13ePtUnD/3H8P6ycagbL3JsUZjvb6oawpxJlD9/ln/kaNFeB6nzIGAwE72GEvcncWZx0T+gBegr4AwXZ+fh3rYrDOEympEj2Jyc5wH8RybDtz'
            '34mzlRuCBBmLEVFUyh2cCPGDbl/SwXaRJhnWDPoEJp3me1bv2BbKGaXAOuZPP5+Q0qk2u9198soY1iZ3nJsd5jcMfO+OgqkwX5DOKxtbFC2W3HZ'
            '3LtuCYhIl1JaumbQVoCMs7Tm74VT0wnw2rxBYE2i8DqrQcwYqPMt+BNsJpoZuOceOnlSTAggCILvv4YebdizDaQy6dDyUbK4QAuDVcQgMU7kB19'
            'HqEhizTtcE6CRuKNC/+cHNYELXK39pmNmnYItPJvA2KA1LOqvR/XUS5poi4b9HjAEDxK3JBALi3tbsyb8uxRBM4gh9R9IxGXAPkrypmdqKrRdCj'
            'YTXzFoi1v51Vvz2gT/SoCNaHOG6WM3N5vPTpPoysuVzlbUJ4JPJW/2dupahOL6Z6iKRM3iBbnapSemdIXwvArJTVRsy8eiUv0JnIIuuvpJGNEJn'
            'VcMPWNSBrSCwKtT3aDLVdVuaRlElZzp2HOtN5HouRHFdQS6T1ioylxVRegOdTE0LNeriUb6G3P/4hIe6RbCfx5vc+MvrIGPySLTXJmLVAdbxpfG'
            'VJXvNuqQwZ+/t08dv6S4f1IQyzP+oYAnh1s8XRb/nm07ldXCgfFCkQQ8bySpE6YYgDHnDz1qoFgLg8Ll+Cl+aYA6OLJMbupoc2KsptLIq83rqBg'
            'ZvyAH0GRG6N5/7eZgxPPTtwdqbZlb8GvhCnzWEbn/NuSfu557L3GTDMM97Tejs8mL73kSgAteb6hCYHcOit7NdQubi9Qz4b/QPlkv7ZeMJYmf0I'
            'zYEmrYTEtShEmKHjlJ/zSc7VFeVt7vWmnCnF96okj9ClpsHmI9OluhjoJs9AxA31p8KFKx0ExnIf6BgKL7uukBE5iYeZc6wFCPLgpxeFIPmasDl'
            'dkxDOSP8lx0WBuNaK7fJcd9U/TrXSMrLyG0gucdsWQUcOBbYpv578jCyDye00FxR9b6tVjoFm/FYA/sdJ4T079PXxmUtmp/D86ItZO1E9on8uCW'
            'rBTwedrnZsJZojluf5jcP66qyeVy5H+B14m1e76jqMfamFUtxFYJwiVZDDnrsHhZ5zrkyzh9c1Rk4UotKgHTna3/7YinLZ5QiZpkjLuU+9C8lu/'
            'iHTEKbL4zpMUBAf4aHdyVMdLqhBLHGWhzbx9wLu769hAU4gyZwIQmH1SoEAwV4cHN8m89+Kn99Z5VIN1WSeTFtgCOlYiipImb4C6CA+0BIKcGF4'
            'XPoOS8HP51BkyBNr0nmtX90MWRXChgwBUhhIxF/tYi/2i5lQB5Lgfv4qyX+j9VSztAEwi6KBS1O+/zCP4yZY/GQe38mGS9FV9Zz6Gi+5OjqqTp3'
            'rPG418F2zy6uJYIsnyD3IcwOXD/0eM64zZsupQl5sy5lhGK9Vr4zxY1/FlFQqFrWrQzWIoCORVAIOcdMqE+IzJztMlzz0Lg4mUJpeO/Js808/Vh'
            '2Ya/t6BStzHGuHM5xQq1RK+CsNw257s1vdiRX669r/u+BI2ckwmaQC2V5NYULVm+bpf1dl8WOhTN7rPH+gZClZ/FS4Jzse56b6kt7Yty+w1+shL'
            'gdd3xYvL5y75KjQEbiRYoAUzQjiPsm1v2EFcG+pvPWYNSDnC2e8I6g34d7ZDPWEajEJDMYRxYr5MnxYnVkQ5AROAfrtD9siRQ76UvLOD+qsm7qG'
            'pIOSwpf4X6WA+/U2PcwKOlBeE1ab83t7ouZ94ve3ibtWdJQk+u/9Sn02/28r8qiXHvRGw2yVDonA9F37i1IRrVOuegj9KGMlvRMLU2Q3yfbnUJZ'
            'BLDJLlG1OsqEAZdDlKPjmQ8piHY9j661Z5Do5ldHhDrUPgMixyqwdf2l/lS2q4NZKVdlfG/30aT1Cm2+66+XNjYuSJbefKHVXNiWEBi6nh3IlA8'
            '4WrFmcChvJewrSsArcVS2sEewvLzACr3a80sPcTFd7qipDJS8YDZtZNoROTh4XG7+Z1dgZzlrui6AH4CcGK0WmNtGqAfsfXl9/z5DWd9xgz637s'
            'wMw3qha1W3ROJ1EF3M7+wgvkqEwt2ysnjkko2iR9bFwyMtAHQCfKkk4UcScerAUYRDeBQDJH1Fnoy+fbU8LKcDStmOKUwng5Qqs+/8hpgqGS2WC'
            'icGoELK5QL3rH6VeK9OznbEwTjvRlXqcy1nj82ON1BAi8GAbuWLWqtUsQDxOICNb5IQdls5sZm8I5tWMwjVbQx3EBMGn9Avoh/0RL10Dj7lGaK0'
            'XR/wb0hfkGQ7bj47eYFRXbj0cUQxQH91OG0QyneDPJx2J8r7PZJgLdheF65oE//LRBn2ti1pLIYMvYf1VqO6X6PwQDhPEpjChIhlELnN2f+io5W'
            '0/N1qulMgJkZ0h/SS7Sfp+qZs14itR7XF3lY3lzrHyUpveeHfNwulpHQFbph4DJVhw9Njjj5EBVvwGkRiwHbwJkDGd6Spx3CZcdwdk4YjN1ftDI'
            'AVI1VKZ6RVOWYkzGJux/KVvFYRCa26ZptcGrRKQqC0c2N1uFZxjw20ESxB9KLnRBeNz5P0SdSOWtIJeSaMMJ/TRdPW7u1CVNO2NciSqbRZ55wh4'
            'BMgpd6f8uwo07nwzchUo11QtmxiKdDoqqaCR7UeVs3xTT8jSIgPdkEa9Bg1wT6MJuWME+ytG9ovBllHb68CPtCfXZACmiJqE1O/HM+RqPUX7Mil'
            'KU+faJo4w8PAIOul0f6ltphA4f5Miq/PZdp7TbIi/iNpz+TWRDoRPTuXgE6CtQkLekt0pHWJPJ+X7BEIRp0Zr+JEwxufxi7JHFbqRPTAh8GOmMj'
            'l5VNgbBN59chPronQz0eS6iQkV4w37+BdG/KlIVoIxdEBFn7NuTEWvY1534HA5GX7KzHQYV9D34tAEm3Fza/xDbT3SdpjciSKrynw4q1KADxCkP'
            'fAQASaX1Cmkewunpa44AqLIoJ1OStYI2aQtNZLqb6Fa/5Ix3HcvANbqu5x+JEw+kRNnvf10A2qClHVSx39MKDayXBY3F3ms/NpRGcJ1hFEdPd2n'
            'ZCTRLuN7iqiqiDlgkBT7kJ2JNrLAMCzMz1VbCi+bPGGBugrQpDOc9zsK3QFNs3Ay0JJpOZv/vABk+OY0chFcXfD8FaqOC5Bo9zrZyAMYY3+I8QX'
            'UlpPc+lL5JyHsqvGTAeRbBd8juAwRgYxkN4GlsyUu74bgWULNitqOXHR/TM5bTCksU1tjisOZmTs3Siy5moy9jR8d7Fj4s2r87BztL8pGNkKJLj'
            'J8PoOHLCFSTzfaEsgermjk2dNmCfEJf7tf4x39SVeWy6JapYw4tJcGQ/KEO7j2wCsA48wYj9ARQwWOuOw9Mxy0pFwIkS3WNDMvPXvwPmMaU7mhw'
            '/Yg5HgQiOuZm5G/JwBuI9WzjlOvNF5oHxDIdWX0IKyTPHY1NIWOFXlar8i1d2Iy9KPzWG+uxVdmm5Cbq+r8UXj1OmXmB06o7dR4sQGIBh9rG7qG'
            'TPNej/TsE5cSyI0TPJDBlgkL1opsAfm28uDYp4AxJE/Vz45+VgxlW3FLq8TdN0cp4Uwu6r150ZUlGW60mnpQLOKCt/BX3rYHF7fIhT3d4kBVJJo'
            'Tbf1cA5JzhBZK0q9eJ85VnQXJJGecsn7EC5gOMqdEY8SG8Xp6CdQ0gEWB7a7zGNvLAw9s1CQ9q9GAUyDxkiNqSkTWuZB8HhBwdM314nanwg4yrj'
            '2W3JENspyNskqT+LoI2uAYTuu6fiRcPXf+fy172Nfp9oNBpuJ1gYUxRpTh+TG8DggXBTv6gtIcLDgKwkex+BesR3a786opL8D+W3YMSrLb6X491'
            'nrJRoVB/jdtwxuAM62fy1344t2XkxEfBr5vJJhXkflVrqpuqNWNez4UACLhrUOo03euuu8vjctiSP6YV5PhOrnnGKLYv4OUwTb9tYsM05dEqToU'
            'cUqZochRWGRI7f/bf6tn6xp/uy3uXhN+j1v1J2I3kxuASHw4RWWjykgn2tVPN0dKnDVT1PiCwwrEymm1QJs5IB4yKZYiSjZqWZkuxnXXI/EV80t'
            '8HB/n7pn/Q1U3+lY68zyF2v1edyr331MDpe9xiC4oHM8uCmAy1es4tp/HhAgTbbS5GkwkCJp643lFF2QLWK/ZWj61LnQpFed+j68D3VEJWUCh0Z'
            'EbEbgbxDbNK8k+95yGxFyI9regbaquC00z106s+/zE1p+XVkWA3liJnbjFoB0AbfFtMceQCEnKFEoA2pvs3od+HRciZqNS/LbJr4xQU9zwSBbx7'
            'Ef78WIcvc9/QABol3pP0JlFAwSFGDMUxFLwEXG0/jzn2d/1Z2+/i4SOBPBqE9vQ78FaEN2aO1M4gORg32PvJMBTSrffYWBWGK3DZNYXbPnQOGjE'
            'hvNRVQpiMm+agq5XFwK0OeK1LzrPD8bAcBA6c8Wg0q9FbCnO3NQngmO3ARE3aS1yvuRu0u/fv1RCckXTkH8el+RvZYofFS6lGWCG+dUokeUnbCa'
            'TrhcpP+QCDS1WNUIyykZCbeGsK20oq5Bz3ZN8ZsG5UXhQfcRpCTq2XM1536mLWg3a8wNTJnC3oxoIakhFBEy3XPZHuCOhz/I/d0X6/LqG8dLaAA'
            '22f0vd+6ooJRWqJFS+QNdeuG/oWdYw3cjF/RqEq/I3QggZfAFlG3yqvrx13Mj+WUtgfrOryGhkLSHDubsnqjk+Vbax4TNMMs9MEzypVGs9fUWb5'
            'bhx5oT0OW/271dEi76r9VDAgROZML4fCFB0aqzFA2oV5GdBkVdbaXoVkpxBN0jL4Yvm34pGJTwCktxE25Jw4+Eho+p52OcXYPi/6VHbL6T4DsVP'
            '/7F7JbNUqyNXGyVRwJMBkjpepPfor/6xOneudHoVlhEkCFlZUNtrf3v98h6plkJorQ5yzIiv+HPcrHQcyKk2Bg451xmBzSKuY6XCO88ak3Sngii'
            'dMtFLtYc4VRgDjGrxGWAfCtxiDKuFtwhl0Sdr7vseJpJn4Uh3s0Cc9QV3Q9WS1GeZPhmC8ZF7bSkjoWVHQI3ouTTGrhtjGvh6kXgEqNbNzjBmhF'
            'Pqzw2rPIa7oTDRAuZx/suKx/IZS850TSiCpWU8ok/BWo7/jEXbmc1qGYiUqWmX7VtnpUtdGdsfvBtuWnBllJui5hCwkQuuOZmA9+KAg4JO24PmR'
            'MvNpO0ll5SfLc3Jad16TQTXimVpQq9yJIdGtgwdwJ8rgqRa64qGTaZ+ZQqgOO1D38wE6eW3MOmnFxmZfLJH9AD3/u4/shXmAGwks0w9Fh5J+Wej'
            'xW8PwcmrSUHJpWqGqNsfR/9ES5sT0dTMZ1Df/N/6grAavJkhg4cEH5VSMCmqRYCr5wEfSW9sOjafPIK8WfzLM4EONxSlMftWuIvMl1Zhn6bgnxi'
            'VCbq3RqxBXPHxURA7HrUDpTMchuKQxsohaX/COZix1jI7VHIqu1XluNa9GwBK/CCpknEkk/otXoDd/LnK3rZZ7Y6mnkBpXRPzB4DtItF97UWsSe'
            'Idoq7crGtTmfOCxKtU/ElX2DHnxU71wsqK+0ywQJiG6Hm+Pg0RNSgcZElEzG96vASg/wGLX4/6cvyQ7rZIUNdvFw6neo5bbLWoKt46/jTP3kQUx'
            'L50fZtlLOyBTYux909zC63dApbWlVRrNcUmvRbLxvJ7FYUmrEBA7uhki+q7psMQ6UeHarTmGp3+JI7cvX8Se044i1GXZO9BdxDzSQsF59AE/QQF'
            'lgOs0FDU/Yi0/o3UxUPVv2wQZqyNCDBNaxchiH52JrPzv00HHmORr2bbH7Xqp7GL1VSNDc5QjkUwynTmYXgY5QlrMRa6OJ0YC7dlsJSY9lVGuUq'
            'KeKYdGhO2GsN1Xy2dP2GiE7lETYVE6x0yz7FwComrAIGe61FYdqZGYJh7KPRVgHcfPubHYf/TlD4tGfZBRlXjOvlHKCd5eKv0Iaq7L6e2+SOVoQ'
            'iFVLi1HgRyydv1YlLvDUvH2zPaGKEBoyEUAIylICbpw7C8UCjJ+n3zOvab1ABqHEfujcdildPstlDqzK+YY2v/YsLFLOsCqOX4kJpKzOn3YJEEY'
            'XrbyM0B0OI5nghVcMIHKjFDNHv+IMb6fgDhV5g7XlYzFyXxS9L6e7nR20jNvZviyM3F2f5xZYyr5AtAeFGwwtKW98AeW0sNbdTS0qVbKDPCJtLq'
            'AV3ljpDyF8DuzdDclC00yYn29Rd30pWqZts1uytiGKCgYr/0bBsTBmSZsYyy3gu+1qbyCpZNQldcO00mbDARSrYGu+VP154Mvv/LLJ6V+tJ5lV1'
            'N150Lohvg8D7S6eesG962fwS62Zxp/MR0gQATWWLsQ85mgAgxxeBBtgsx9ddG/DAE2baW2v+RhjGezQpS7RLx/oQf/Bsj9hMNVZ9iFy/tTxGk38'
            '6DLM+9hS7nB+B96ydkzjNyeSPZ4eKjsfQWPZNfb+4xwW+ftCAzc6ExB+6xfgEtZeeQ7djzouTzCA1i8Mh0iEoNZzHO30xUxymC76JsLQj/mGENc'
            'lY96zgjgpCHNY6eLxcTrkKCbGh+rm/QoWXeAu9unbW0ClZTkWnbf+8hkp5/mBEpttfw9eAWJQQBpYr1JVI14v3CCFozZ4bnlpNNYMEKEfa3R9tM'
            'FS2LJwuVccAJvajZPOrsr/zosyXbGY6UG1fRL2SR4+fz2xUAq0BlGp/kAT3kS6d1wZUPiLr9TKzTI/z3jTrdHa2mufcFAMk16bc0K8029zhc5V5'
            'n8xG4e5pJwKgJv3rBVr5hk+OvqBu3tcExmFdNQ4/OW7mpCfK3JtY74fnsBCEGC4CKASQn5Cy82uUcGsPzNs3+kpu6RV3+gG3Wz+aJT8CMxVbLx3'
            'sdIdU2BVz++i7dTPKKwQCpccbmu2eKfSH7nb1GVqVrpMMBA3E7ySewHYVNee33Dn9lSeBYp50mPO6WRqpTutxTX7EAC2ljrWYeQATUzh6HZPgb+'
            'E2pdm84Fy/uJAQcVxhM8MWHe5tJYsVroO9LNQH5F8nU+svPRg3L7J2vgaRpYc1jQHNqa/0yZCGB6p6Niv/IgGfkhzLVqIptvERBdQdX6rRxZ06W'
            'X6UQ2fnCsh0dw/W+YIIf4Y8Ery7obdyVpiN3mHUNH+b/ZgEQkYziNH7PHpINDLqmZL+GTOjPcvWqfI/TT+8DPCAkwbPIfdaHYSl9RUxIuT+BjNG'
            'NPvAWU+8u1oYB/hVOkDyu8ttv1vx0yuQZFA/iwaZjK0KhmF9oPkX3aHZyzTNzXtvuS3lL199x7r2J4acqkWDRgzxjJdZ1TA3uCOliCQpfX0Hg2z'
            'wCH7lZ25lYH+kE/lDfMZa1zSCJwpMVEcqJdW9dB6SlUyACsdqC+j1G0RqmLAHQFfu76NvcltgjIMEy8ieelR8TvZmTjyzHlaG848KzI7C+LFCcL'
            'q5ySOVWDf2y0g9wrIuDiwX0YFY81izoeGxNa9k9RKIGuVViGLhPjzLogstKv3Npm9toancWTvFTF/fPmqtXzaTsSJS0OuHhXCRumxeDR3cDJOTR'
            'ja0Tk1HeTUvkS8KcuinTKHXeFMdZViupaIFhbQl8bhV2bOOJfVOQ8PANMtVwJZeKKi3DdX7u6zMA/Ckf8juQYGpWjTGT9iFSCRXunOjP4dwAjgu'
            'fDwOue/GRbs4krMeVL9SB/4k9j30dtxUueC6qVd0gnF2aeu0DAo2mfUNlwUSYCiqeJy2/2yike6r8/XC8f+CIM+vnr2cOm8JcuzsFCmO9H+plLx'
            'D5SUSXs9BBpHAlhjEyGXNFmOpI7q88PuVxhMtWGMXDuOdnw0QfrMTnfcYtNNvUvkB+Bjpy8McNX4sth7ayQ3DMeJ74D432zqOCn614iXJqvRQrh'
            'QujfRVje/9X/zOoxhxKFRs7noMFzJ/mwI1ldjFX/JbUny4GMh7o+wa87BLlUnXe61w3M8sgVs6DVXYwP4GbsX0mUJv3bPPxPHmiGqMpaEwEiqlW'
            'q34zJI0HWtm6ZuUWIxjb90A+wuCbOBA3jJdAyovSUuRXi62Mb05g70LPqJpndVa9bCjJUJAF4MQh9BxQOSO4UMy1pLF3eb4C89VfSc9Tt2mYhJM'
            '2NHDOwTYkfyDB8dHxas8a/fXkhispDFvvHUeky+4KyKnR+q57gNbW/HJtvGSZf1akAWjn9skyONHrQG97yNoE0FkXvsFQ8rTa5PoG55PT4AjAED'
            'RgDpeoP8rFAV45tWvIyCbCFhxREf0OCrwhxznTEosZSOF0jecVY8RWAMr6olPybVv3a6a8IVIXHaSE+8f6zyHsoimqPD75WAwab2mBzD4NofwQm'
            'z3/Uh7pAkr7DJCohYXVSPs99dQURzPaZGW9HZj4MesZfbR0LamHdqMtqbtbb+uonYNTHUHpzOeT/fi8P0zp1wVqF58VkAcH43sVqW783UKciUw/'
            '+QxQG0sU3HybcJs0l3viTm0Eeiu6nUUxaNwru6FFqw39pTEEIHMPjg6R1X9Lz9kAAvrKJ/NxWv2aWk/Fz0MTs6YGIMrt5rQvn9WmrLqdIukui2+'
            '4LmWt2xiG6s4J5IwLsmpK2hI5AqJjVJE6UMPEsM2X8FnTL7uRW50igl4kpMDUWq3p5lFzzXHOdw24RDr6zp1+AegxYEHgt4V53gCtd2GZ5oTJOG'
            'FKqbrYcrbm4MXcWtKN9I/G/9YreOWvodASAcy0prrF1rin4jUZjaBZZZ0wm6xgTumModNxJ9jvZifjppxrmZ1Xp0AQtVISeaNZLX1a6n4Lq8nZy'
            'sf3ud78+RnERdgJA3+4NQs41O3gYdz3CzgLvs4YZ+KIr0cmtMYP6SsCRpW+piRgldI7vj4VvW00gC0Wfm3rs61wwS1lbZ7Pnru1DJtvivYpzV09'
            'MJ/3Ytcv9aAuA7jjEqjI0TXlQ3mt0AdkgqfBbKRLtKI14GtDqhCug6mmvLWaRyQAZhi3DcoUBGGrCDvECBn+UJuZLwdO3wf7Ne4cxcPAGj890wV'
            't+s8yduRDHM6IYE2BB4oYR7naA9OuGpPrs7DbQiNslU6QP4ah449op19WxhgPWkRwoMA/noGzz69ULmoHhBBKQTsmWv7rM2k30MKjUSn4c/qU5V'
            'm6KUgwgiLakUN0r3f7+jED5enMTqVHMRpxfTGOBRaqpGVP/Y+Ot9yJA1RzR8Pmerk7xIt83YxN9fO0H1CF7Ta1iTfClXA1/CWc6+r+XhfoQV152'
            'i46QITlihTyz1LQX5oZ7PSxNOz4QwQtrHgqtXz2GW8fDScZlHeUSuBymzcVl9oKk8Hz1c7CDpsdhEakmk3WO7KPqmSlLORObGv9QRU2uNDUJlXP'
            'BrSkj+FL8kltW4c2vZOApN9FfPg104OgGRBAXNhHSeo/hUxb1ro4utvSh1lOyYzF6dV4MBByMASxnxI12iVEAuGdezHygPyok8BHMwn7Pu3m/CA'
            'AGwDi9Dmy/jN85YdQ4H5zcsJ2ze7gpPDTgs1Uk9DBKy0HQU1O/83HhUbS/+lPKnBcWnseOOlNa0gaMVF7CfXr5Bh06pDA73daw2zKYpWWHVf0wW'
            'GKFTBvjtyrwefaTJr7iN2nIJQ4tCvcN3sDJkjWPKR+MAmANZSJRrhpwslO3aXTOXBKeX7G7mxQ1DZc4exNNBSyiQKK9yXhXGtG/NtvyoUtbVbis'
            'cMSTHCvnhzuPNYRx4euvOAErf96cBcqQHtbG5AE7oIIw21g3zmBKDJJEJvLtGmFOkA91P5jhfh63/zygmqo0twA4if/juHXb1vBjGprkx76Qh0a'
            '94an8Xl2HkBeUe/l0Jl3imMQQxCLmR0nlRX+zS8c/dkfEYwYyN/KAkfETlM/iaVUWrzi2V2hg0shqpVlcmVqHRKB53TBKoCSZPCVDSzm95rx8ic'
            'uUN128JFAbMcWe/PW0CNFuJOyPSDCiQ2SqMLtpnaO5ZNpC4CVZMNUvbLefiagzu/7pAenGzGndyhs8udFoCq8xpuf/kcFSaDli7aExTPWkrBzBh'
            'cWNvhx+jW2uOn9GJH/k6z20VtCLL0ThGB5smQFi3qAnv1NJEtW0m6De2M6MBWmq5HvnisfE3toRUyamdAvnjDcbgXicHKIlN0lhh05qH+6jEShv'
            '8oOpK6NJGoGPk//7Z+sGn5sPijzS6KzP5h0lPh0mJdFPWlZFIavlvG3JGYmH5vCZo8CgHrVg/9cZIq9Rt/ubBXba1MNVnMqllPFWVbR2YTaOI7Z'
            'uPtC7T1QTrZhlzEHLURn4I9WQClfGV8d+ittlbtaNddE5P4977/ospOICeFCF3mGg7+9I+pYOMQT1B6mgY/dZ4piCmfVU0FhFH6oNGhXTNEFUT/'
            'gsCeLHQWfzOOr9CkgWDFqoDMiH1zLYi7IQJD5quY9I3E+/G5d9eSMOICDC0VZPn975SHOe1Ld7FD2GEXCpKSw3zdkwJUhhR2NM+mQhlBPLiT4Mx'
            '5tT3AW88itVQU+/uWHJ8p5aKo62falqfAFqUncLNEvhNXfIJMOabDzY7+O99suvaCuJrzHtJP4zAY4R2ekJRTvYObjMrH6hrFwmoYF31DsMLhhm'
            '5kuEC8L6b3Wt5LLlZNS1Xze9B5plkY4nwEwWvKXEM6HUK7VS5Pwnk4sRV/zv8uEsvtllfQsJow7hfcH0SCav0OzLSJjDBVHlYWraAP6Sg3Wb+3v'
            'qbz7vGZCbhcXOhtNIf58EfZB7Qwc08A3gnEfMcP6Vj2oMLoJGIqI+UgL3066k+f88WnOJezMy/KWj6SMCnQZvQpUkZ2g6Q6FB6ho8R5izA4E/ja'
            'D+664cPnirz5SD2xHaZedsAWBcVWbiORn9oRidIJlO7lsX2fJ9LPQHSggKCwkHP12r8nP+xjq5X50W4T+5SeFnXCsLgjyNp1LBa+KRWMWG6F7jt'
            '60zuRkV6mTqET60By6YwzN3ALZz0jLXljsLqjQ+1/w2gzA59qY2ObM0tbdNaOpbq1p0HR+VX/X5TW1+roippcKKCxNCAQYHfaDBLNo7JIQJ4yS6'
            'H29Jbd0Zz39evHGsi3FHnhiHFuytztyTP2ByOMEMBzzQqkGlQ9KUozTOGCwDZI9BqBSF+4wpkCyC0/rU6QySH5O1qL543GqMZLgJLqUAsrV/j85'
            'exJ3/2mQmaRg+bjlQq76Mjq+PS17hE+i+8/CHkV+QXN6trs4AWlWXfT5HQroMAgaL75pkE5D8mQDVmiA+nuVIGjdNVarLosu8QurFrxNF9C8Le4'
            'QWs7bPee7RP3ZbSSEbHBpNG/BDSRXs3Qw5A6p8wl2CLz7uKz4teK1gpxDQNVPCWam4tHl09n+j3zeXTDCYlyvbXNPhKCkhficXkWB5V9kELAeJR'
            'xxyHBssjKvIAUqFC8+trO/h1rdGNx6XZNdNMLUw4J7HjVFUmohqI+qgv4r6osl8SJGnbXzQ6aZuyZq9u8tCuVh2ohM63CtiL6wF8Pj3YrDypyJn'
            'ZPJqC2vEhdVjz/M1F9DQSn86X9pPzC7KSnmXLmJerIdVPQAS6kXkOoyf3iLsIYRrIYAPukEi2Qrfz6+pK07qdJKDnFRX4FsOp1FrzPlANNrfrvN'
            'rdIOyGNI09BjycsyIXuW6z6HmBLgT5GXJ5VWBubWxkjssKoY+BSN0UmnHow8gq1k3xzJ+kNiK2mYAgbqD87vT+PJReK/W0/lSs6SnJmxejE/5wc'
            'HdudVXJoV9idWu0i3qp/aLlV6AM+ssDgEhXXzchD7dudMddF/JBdfjNEpgjrh4MF1v8I1JwqAjlPhLZB4Gub3YUJ1B05lhxMou0IcFEL2O/3A/g'
            'IJ4Gkpm2V/TYE4m3BdJFCvRtrp4ggx3GSAvIVZmnY7+50pkg8na3Lr6r214cJXijlETfeGU7TXfxxGnW3YYK9ACGalI8eEw/uPe1oK5rv4IW2zj'
            'zkIInT7ff3vFoLB4p0rhnpBQlkf0GtHXGQpUo2T808rxtMX7ImS5yGfmIncMb56Pg9t6xgh+mJ7S00alj+KPB8GZeJPnFYmA8KTRZCYRf9NwY9v'
            'X62ip5P1TjXussrB7rN+ZU0Hy54bSzvlRlQYJOGXdD4y5cSxT0cpYvojBf6iLppYe+dc8qL8Kb7Sw4Zd7E9DLzc6NwRjaxCItHHx2QFIb/sMs9g'
            'YAp4Wpi17cUMYvcVFgJzrx+lSeRleGCkw8JbnV2pTFqCfvrgvuOog52vXQI5aDiuudxH0LHG7OdBfHED0z10ZZNpDZqBRUrL+xPIwfToxSjgkvD'
            'ZcLvsnMdb/Ks1BJACaWjnAAF/fsBbvq9P+UAS9E73zm9QkZRAIp/1PN1tEU/p5hnIIV9gl6rGu07VQQnibKcc/FRyvI6yJF/kH6s1mPcgQJgG86'
            'bF7FVAXcqCcRClyfj1G5vGXwJGEMQhwoLWMJsE0Cas342plymSK1RejQhtjjV82Jni5qL7GPMZr7TNwCO7bMgWYJsH6+smLmqqyQ1NLAHHKoV63'
            'weLYIpNNiKDm3bPkP2nCkK86MIr+jPW1inci6zglbDVOiMUh/OFnoQZ+QkDLH/1NaTLfzN/IFjsmFnGVMHiKkN12DpxTaKNmjtZR2YyFKQ3E3zF'
            'WLikkj5lVYK7c9I/9FyMBUdVc9cgZzSMFbJdzt9carK8lUiMXLcUq2Ew+mjeB+WYbblsxBv0L+F50gjJTf92u94OlA0hAcvuVRoqhxjLor6TEeU'
            'ItrTMtf1dMJj1ZYwKan8AirwJcDrapOdb2lwLLX4m6HBy+0eZJ9a1XknVeH4hiS3FF9pdeVGVELeH8i5JH2ejzoC8L+q2DinzNtOrT1IKJkWPif'
            '2AAKy3oYhERawnOYblJCWhHPPYfCNzT2bs68BH2xIQcQo3GqUtboZf8fEZIwKsCjYqo5M+5T0+pJBgYpdlse4y4Dr94TKXve6rVaxF0XDVNwBww'
            'Cwyuy9AU9GYc0xZFP5UvmvapJnXRM3SbAqGq/v+eQEOSAkbIKbNRruwmU4yQ0Lxp0QK7gPzXOV+BawNOOktihm1HOWT3JBv2pJMWzl1V7wIlUsy'
            '1I3oAuc2MDz8ljIRqQcQijDbRJNagXqw7UzBaqN4yZZ1ZEIT9gjINOV1uIrgXEfLryO5RelZKahiphHWYNmz3eK9g0SZCUKGwj6aLNaCL7vSwiY'
            '84Z6iZv+/hr5RyQlHBPDns3DhPatyVQZ6aJiVajtj6fWzBFp50V4Qee0Zpf3UI6GQtZURjV1wI5LKCKZC4Uh6XFG1wgMARMfAcd4yM+fdwhtelF'
            'IQTphFcVt4/X8BTZ+RYTKkBXju0d4fkjr57RhHwwMIe24AijKk51d/zTald3chA4bg0SodHAVkJs3G1ZrfsOqadjVYI4mn9LlgpljdLEZVmNVW8'
            '5xJx6qbjtejtl6/mTuw5rVNHETjdLrk7MD7kkPx4PZaspRV9E44HuVDO/OKUNKLhQ0tc1Ez6EGXpioHrlN6d6Gi+kmnPNKPR2jtCKcHF+PWVJFS'
            'ofzp0YzbCy/ff/FCWq1Ur8a/x2z6UuXL37ccMxAsZ0oKSEeI5VQPENfqzNQM9f6yil3i8EEt3ZtNwq/r/twl+z5DAd7e8XFUffKd5hWU0/6Q7kj'
            'Q9Gl6ua4r+88kxsbHsL03yv07VxJlp15/HnkTISL/wVerP2ed2/6l5z1gCK+nVVEtcsHWdYRYes3pdxWMoPYog8iXqySKXZ+Iz4fIYr1zdCrNux'
            'n9xub0aaiJcLHSd7LW+Cwu8MZDRMn8wTEVP+Knjh/nbZeWxmSubROm6gNHh7PiORaTheEDg3IOy8YMEktVFeTbHF0Aybe8k5+ja5i8oxYKs4hqC'
            'q3ZdT902mXDUT+OB2Yohq3hdmRyMsxwZMgrVapUuXUz+D9eKToQIwyuZSaWkpmQiYTqDCkUphVIKo/Bqox6qB2X3WM0Kq76tM9p0PaCvTiAR/3V'
            'f0zoVqUUUYx7FBzAAm6aORvVo+aZ6ncmy1Dx9bUJwgrixjYY0bdVoDudT3JAuuoMyqSUxBX/1/0ESZ+s2OaKPVlWOBELSM9n5Rc7MNTJzsl3Tl0'
            'KyiXSjBfxm/V6fx1ZDQLmjKpJDTZyn4U8nQfApp7afHmW+JrXcquBrdVReXgb2MVD9qr/HJCgGFUvAqIkRX46U3OwPt31ocqxpW0VHobtiGCUCu'
            '7B8DezPd2W5ISoJFNowc7g1hPVnUtCf2XKx6UAHCmFbtR76XujOS+b0oojq7x9GKpBtLLragzn4Xjw2M8fxln4aGSs/w14QwHhy2OFMVVJVBQ9O'
            'DQk5w1MHxo9qZFaoInosjokfff0mdxZ80Z9HBHzYRKpGluCPI5avp4TJitU0ioeNgiC54HWe7x70wcCEu7MfT/V8qk1NaRUmbrGwk+Aq5dIvBDF'
            'fgdMN36aFG96nR9eFL4E+dnypRujcgLUm2Ylw/oRzQ7JQwXRuuUAwKFVszPd5vlXKPlwywdfXDKSjK6czrm5GyXEj5MVwZnd57NTVKnNGLFEMQu'
            '9kDn9gqtZrHgfR+NVub7V85YFCgQKnTybSE+IKTYZPF4XQ9X/PHvJa/8Tbs/DydgDWHhWHTDlcegr7DH2cBMKpdLmrNrauMbMil2l20SCWxxr2Z'
            'i3jVmLiQ9ZP3KT7fTrmNxfMOS4KrllkOR9iJvHjtWBbF3k9YX/ch2dm9jPbE9BT2lHwRQycNytXjlhmmm4kZxLj7qhLtMvxTiyRFLwQ03bDpPF5'
            'dwKnxzNfzE7oafhn4Ar/zubcrpPrs/m1vwkuIiCX7FN+TAzR305SIbQpnI3mHzX2S6KBgrWWhY0ewqIqgPjSk2xp/vVpM+suLcNixArYC9jOIiI'
            'hpuIOZZcevMWWzMMO4sCvsIUDjAu5iGvMdUAKtIUDswFuPKM0D+Ey/j+m8KXlmBZ4plpzkx06NfsVhmmCMsaREm0tPDfIBTr2aG/y3Y+Kl+7Z7E'
            '2UntAS2LDpFvl/89Iv0J0RsP+Q2vJ+5mfXlREJTNoTGDVFsZvB7IQqQrshv38wY96sjpow9N9kCb45lx536nke8yP1A+ukcWxQdZG9TU0Hjv4Gi'
            '7jubOD7Pmxj+IYe8uxvPzVtoGDbE6o2TYk9OJvgdEfOIBPB2bzg/rjYiDRecD3zavJeWjcdXXtKYWNaJijPL6X8ALPOLH7Q5HTRL/+Z6EEOackZ'
            '2B477AFHIxQGJ+i6YW+fpnSX+NN7uWtpHVHNG43gY+GQ2R7vxbPNe3EweJ6avF8NQDOSawqunno4O5+CYSas97wqi0FWrpvuXKPHvj8E/3mLCGp'
            '8brmWzRJWj9QH3lyr/NdElwi7Lpx0+uFyWV3rSic3aUrTsW9GW5ZT0JcuBrMemqk7arKwAetoCQqH98GN3y+78c2Wu5jgLewMFYIJTL5JgOcwJy'
            '8ib88C3cXpZRlYHhZCS3GgNdWwd/Po9UIDzCoz5oaLrD/rbGGXQecoosC6d50Luznznl8KDJxSE+q+imcIQLFfcQh0YS96O3gjvrdQBujrYM+5A'
            'xFFEA6V+TYwiI+frs/Id2vKnu0iAHOd8DXvsNQSR5v420u/u5SxznaXWUsxrCVbZhkPgPI34slT8xAy8SxItIeaJW5/KFpxySTfVxnq0dVhpiYv'
            'gfWa1UMaUAFQgtA6Ha7xHjg7HcAOsmOM9vQBCkykTftPQYzpUeDCnLg1OIpbB1PoRzpXI16Qdg/cfmKeIgReNBYNl3Vp4k6smi4egTjojGctRRW'
            'dG2oGqdPHxu/Z4TEJpFEd5uHGb3Ofc/dg8PREeGqkUMhsja2vtmC3RLW3Eo/H3ngAakcF1wBgIzpBUULtr03lT+3+oXQdDu0jlz144jaNJZnNLq'
            'xT6A/FY+EGIvfR6CHW44UC/cSLB3JTLknvuDQY7an/kl+G12Bg5sBpjBrQCIBB8Y0BelRe4F6MPItOHz/ToOM88YpCj+9rG/8tW1sECVjNJfkuB'
            'CRADQaj9gUWIpuEpI40y3HCovikEnHS+JgYLa2RJIL1Q4IaKf8uTNBf0qle+Dl8VUJIP3W4N2Yt+RD1MJmZSFL8HHbvX7nJNhadtbCm3jhJqHoy'
            'KVVU/fyXvXGhHLTRp5v6KnkcbpezRN0ASeQH+wr6NBLdJEGA5SGu+JnZFYhSVi/JlsanL/tR4fhcfEdIJ6nQ90cK4Egvpb5Uvkm8R98mjytxGQe'
            'bgYfZPijbqcr8RzZOMto5d5tShMToHTiakWiR0OOKC/g7L7rpgC1ce7onlLcHxnTyVWTYGF3M7NZFmATu7nkvy7RmPYt5LW4t3aK48ElltnRHIX'
            'D4KJ0RNf1vkHH/NT/rPuHr/ZR21fBDoWzB/nxj7bz7M4uVGiMC1xhKje2FBNON/g80ZTeQOyNqGbKGO401i1AbV5WpwnMxFzjUUzHebaC1kYhgO'
            'aJixCO1rJzChkE3NsQOkQWGKvE9+uuwD/qfo7k5SYTPenj5jfto8/VFQk/4XvJMvWTMXxKZvVrgkKftLK8m3E0dRcTW3BPL91ZmvISbRgZ3m87C'
            'vs11KcI54Ro2XThywQm2o0ycfFn/gJ/Dv2i/g1/qmGDPjMyyPo/XVt0OZIXtmGTS5ovqvR8Gl3vy1CwyAZAhHW9IkaYFpneV98vtVc9O8OCJotZ'
            'KRJcq3cxbefj7AMmV7c0aYxNlLdZVuTATrrXEoePhF6lWqvuSwFNuhdIHsX707oqOfKGzJD+7+9M4jKgF2HYCtVGgjdfI5G2OxhTcGRTvIH8XyO'
            'OhoB/MZZOdjCB2yqDSG2PfxyAWwLePfr+cltExjKB+okHtNYZtKKfPjpHZtvxbh8mbS2SLFa4Q0ikyQanUd+rnZAdw9n8FEWdLClHGv7oeyWTDa'
            'OFnPoCt3M6MHh2C2Ac+gRfv2o5eCMe5YEN6JC12GC57tbSDNfp4Xmio3x7XFahyPwf6YufRaF2eCyuWPk9VYGvm0gbHqLlw62ipKgG+DjcgvOWL'
            'yE+ymgrl88IWjOziHPCmGmfIGT8CWG+p1u8hA0b73HZSVxEGsoF4zAwe2TFMnP/9AISffxili7hqcaKzKz4JCgXw5iQljyGBu5EJHzYEu17CLHE'
            '3wnyS6Dx1ufrCnZvbSe1WZUTqKKt10FrbplWAAgMmPhvjEjt0xD0m5w+1/sVGbV3NrF49HDMaBMW0VMdctkP++sG50oR0dZxh1h1YVPaAVdcH1A'
            'CjJITDb+Ew33TclAwgC2lU9gZz3+0bA1RJ7JVPv/4eapTHvy9tod1LtwZAhP4NjupGNIoEGsAiW42lwO5mJQ6WxPWBjE/V52gni7Mi9ot7xoy9d'
            '9asUZlExMgv3HMQMUWXPTrAcH+G+UzKBrtfEkgMt7x8qhEeGkZmtNF9UhYQYUZdVCt5WMng5eFzaqxFqedyaQqFxiAaTbbB+qTYvewzRWn3+57L'
            '4c+6fQkmaNdc8ke3pn13TdWHNp/HwBpN73JgJ081m7aTD3XomhBLYbsu3KJVTEx5eX4L3DNREpw2Sa4V8bajbvhg5YNEDB9wMRzvROCoCcMRJcX'
            '0DDKDix3MHQH4sGtHc+IQnQlTpoeVcPRgwwPIlKrCNhbXBkx9VlEf8Q3hxfhqO6GOsPhqovjj9OPBK2Z6R8yYoh8aFVjDXkoRHAxjhluifvaWjg'
            'mljNoXu0IkM0fO+YP4VaGsGvRQBJZfn5EEo5spb+VnhYnISX/Paa5nvh8usJBEqiu0TgsI+PIind19SE3UlFKJ48mhYPT58KmWhqZhF8Z/hEflZ'
            'O1eHiVJmLVlvszV5qde7L1ojt1MpweUmGKwNx16IJBDfbN/03k5gT3h59z1UwXcqdgmwy6jj2nXFaHhmolUSrEUkiYDmzOfgdtZxmxJrf6I0EgR'
            '++z95KM85Et5JLgh4zFGGmrJDj0DjCiwgDLV4yJ5O/Wdlvs/Ps29SoqPjmMQgSHGV5/HheL+0rzfSrhsLW7nuftuyH3V6X+RJFfp1ZLYXik5rOD'
            'QV/EgaGB2Z5QsM41/wWgz81eGdIpurwO2qaFzQQUwfRk3qiS4+UsvcjsAH7Ei0SB51Qke9jjsM1AiZsJjHdRA2lK9UvaS+1+yT5T9lLF2NKIsea'
            'dteTp+7QyD1b3Bolou/vMoOSEZqYAeEZwNyujVp7VQwVFxf7mf7L6Wyjo3IXReBvcMmXn+FBv3iDBDSnM/3Z2ZQDcMqPxbUEJgnQh33KU3V9gLm'
            'W2HPBdVPeBhsHiiOHPvQjSJcypeuOu/meC7fr911/nKN2OdbqhD+WFoKlyFJVWYiMhO3icyIKtJvkPVS3S4gVNWDwYsvLAEB/AWVysld3ml5l+c'
            'N3XaUYYNzPAYfrXLS5abcWHrafPjLzQKe+hIEK4GaPIDXYXtFae9Vo6n/DwsSYkKIi05YCMKkzbybdDwy0fwXFiqw6naGR7tEvGqmLZ8p8o1NMx'
            '4K4VZKaTa7gSxvHdalxFuIoj3odelrM72YG4Cgbw+URUb+jcXpRtI2hqFNXj3oKRSBF98jSs1KsdBJ2uKn6wGY302c6GMPz5vQK2/sLWTuyXe4M'
            '7E6PVV5zpdjitDVK5CpzLNOGJPufQv/FoQar136L6hLnBQ8mmApydcBYc4dNnZzLU+ND81QQACad/OsZcSKJiAffBFxXLkMvhyApfHgqIeZEyug'
            'XJB01h0oTiGbvrgqo9HCmOg/ot2iT8E/iuCjvBztCkLlO5fCaLuovwtsAM+Ubl4Jqwxx2Q05lm+sFYIodmuoeEbN384YDyb9nJEp1H2etaqz++X'
            'gpagdyvNWt5ECXCvT800UPt/vzDdH9Nv7ZzuJBGhFM639qTaHNIgY5MBsFseQSx3yn9wr4oMaIVnSZzPpOaM7cVXbYIGa8dj8q8kU6wQIIvvHYw'
            '7/AmB08xO6HocsyIAL6UtVYL+MpAmeGvHLGW8vjIywZNSW/GEhGLz12oRfBDceyeQ3CWHrgeKljSdBYrCQT5j7G543W0+XzVL9XUBgtGREs8aAS'
            'PGRJlwvZdGgImT0ajsVteiNYf+yM2ZvL4hWMgOnsTW+zR8+pJ4wIcI8dCtbcebm4VjGgql+Cx4H97x/bWQDpRlo86YFnBRUzFMdO23h+Q2lW2ge'
            'FoEhKDP1tDo+Bnvnj/rYHebKkVN+V0FF7YmFaUx6d9FqOiAXXPVvkSo0bsX4VAdJjVzFUNkXTvSCE58SKO1otGmxXyI4SlTSlqNKqd5tDvhAXWQ'
            'YJr5M9NwXRS9TetdeKdzDNguJ5/Vm/yjO+xEmS2ieHpP9J7Ubg4cgHjEuwjrEjA/kCJpb+aep1nl0HNsjXgsnGrPg1N1zTMmnVX+VN5hSQkWYA8'
            'ak6q+yv4f4Kjh/Uda6W/pMj+XytZIaeUone9SsuwLI1Gkzg1wxMPQBO7J3Bc6lAXpZyGDXobe2b/hohptpthZmZUUo1Pyix25wJQrSvb6MTuFi8'
            'fHPBWIVltTS1uFYN+AtCUwqSssdTW//7IYh1WXjVl8a9a9NCxBxGZwvEAzSxDnUz4uERKeVpZykyYkaiwIv/RV9ohnf85JQwhO32Fb//t2HgJux'
            'xpK5uPx8jbNCcXX/680lNgiI/1p1Ihnw+WSUDIFiYnQUG8m8N5KKj1b4GWYlxC7ZV4z4wyxM0uUaRl70gA01VxDruaRt4h47x6Bckav4TuKpysk'
            'QGizNdJ0L7SNDuZlWNm1IwjdTToWWlwBrvyQDvqa2F9oAbAKAG3c1wKuKOJc7oqrI+dLfDjgoKGJNRKaX0Acz+k0k9Q0f+vQGDTgnRkjYDRlyd8'
            'YMthg5w5JNiq+3DLDimqgr9ptStu5kZWGEOWoWv7xcnDbBu0HK9gdanq+hXgrVYxme9YNoC03X1UmwqMVkvIVoIG1X7juV06yuNHlkOblamgI36'
            'TXc7/X07D+ILK3TAmDOg8NDP0+U6pnfF1TMogj6q8q61KoITGa2k5MZ3UaaqhmWBxdAgRWig/YmFlprnLUatF+1S7k0YIHB7uIPOP3SOCecf1a7'
            'nGqTwObjHJTp38m3LyYX8v5AfIrl3rWwaeCLyN44QcgG52rpeu6IEjqkez+L7Fxgkrqv4BHEuCxfgstO0II0/m5zNgT4TZABzx48M2utmnNLlbZ'
            '5I1Z8wAPP6VMTX/ubDlSVbx24K2jw5q7UtE3jEVT7fOf4Gc+cjcKtHCHCnY28ZHNcyAvl9jFfeo3XH/U49eSQUopIHspjzhYAvdk3VR4CXdz9RS'
            'Fepe+HFPI3q1DSpPLJRT2S69DUfEaXkdUrTump5O2CHwuUOlBnseJihtxZJUjx4ga2FVUIAUDQPZT8WZWVezAwJl14TX3XTjqlUjFuFBbzwQ98p'
            'To24BuIOKEz11tc9Q3HVU+y9LUjt0Uk2CAE/aPXorMIN52L6a+XJKQdahhV65y3YPGwK6zLPnrL9Tu1vKTDB0Rk9LcuIGyLCtIjqkUR25VM5Whu'
            'PDeHfaT3Qs8tKU4j6x+uCPDnW/QOxbBbY+qWQMBo/e/ndeoftVACGscpZk68aXOaGXRE44X9VEFaU6yZvS7sPPumMZdlvS5nnn3NI7XFRX9pk5i'
            'Y9XaD8xH9nA545zJJkcLMsdVfM9Wf5vfmTHY1G+juzNqHtoCuUJKR3TkSFW8nfQRSI+V7UT+lkXIJXAOWbrH5ZmD7Iu/PS2an4I9axHsiSnDgW2'
            'JqkDNQc0eUiUd478uUS9WsihYk2V3+yKxgx02XB8Sl4uNHBm0dBOWBaEHDy34xqfa306SNTIVOQYk3wUwJenooY5MLCGmWIk9PrfN7zqdEfITln'
            '8guvrOJz5O8Jt9vfxeB5/952HEfRdtl3NX9Z576OcXzuRDF2lTccEP+sJi9NwnOExNySgWl7y1iKo2zx+1f01h/4FEJEY1wbib4+MKpBBdV0IWt'
            '6NiRF8x56ombFVyLA5uHwbM8a/6toiCMLvZtSTGngpmKLeWyN1xFPC+CFl3JLUKypwOurN+MWXUQxlLr2Ea/9y0vRW80yRLI0PFn6ZtbNKWnKmF'
            'Dquus0Cz6hzmPKncXvBGzbbS/R0bwgGBItB7DV0+9ievySrHfWtpM7T242Cz//5vzG0yxG6fkqqNcUgxbEqYEKmpsRsEhuVkmvuYS+MBHFHEm1N'
            'ffIYIaELrH4HA2wmc0K5h9TUGAnirZjBerjGnKOy0HTHUUS59goFcWXu+2LLrVnW/KR1zQW+Vo4tkJ5DpoYpEWNy9qXWRBHMmkA8LjG+7q1jKq4'
            'nzRU2ocUDuboDqTyJtYMbjlD081A3rnR1jr9XAeGoYfAP67AfmHuuxSOrzKXJDfp1DRWPVT6Uk1O2byS5JKRn48nxPOIr0iC75j61oiP1OA+0i5'
            'wfjpAyjN0s8y7P1UAAt20C6ZZyhlrd5jarBu1G1T72VBhzLjMEVh8vk1sy/Ax0+PRtv8AY1zLbH+a/oYMpZD+/KEZzwJBiQ8C6C1HZ3GS2dI6HD'
            'L/5/mVGF/BkHlzD32E+Bk1cjg67q+p28WN9QNrrcO56k3CUr5CGMf1BaK9tV9nlqpAkXz9u8iAdp2vpNm7RT0O7fMN2AiOKUf4gNoTuJ/aDuSr4'
            'wC/CCwwapGT/7wCJMaRTQgtqTEmW5NtPQdF3Luqww6h8g6BG2Ce4xybLJ062Coie9VarmPx/Na4qJ63+fIaYh9GEPVQ6aKcwiwNWgfkiMe7JpAZ'
            'qEF0VHEbXItOPY2V0RGzCFs7kRNIt/3jG82cLV4nzIxM6TiDl6UMTdPLF7N74OGAmt+EgXGSvw0+HrHhY0HbN3nUC3k9CT0NFlMSte8PtQuvAQi'
            'UwYb91rgvZ9zdUZUQhgV7rjXedqTQNoQUq+7qLYsme8rV8bJ6cpwl4ihXLTxRaYsLkGAJs8HCiZ3Jf68YEHKTYRzbgPWT15o9DvPIqIOgPu0lgG'
            'ih7gs/fDQDti7fDgcmPhVx66zWiJpATAjQeokO27DeXzZNR3RTgAACMHsAAAAYTa7HwAAAAAAAAAAAIEzB66OmtwF11cgFPzMNiv/0CON9Kh1y2'
            'aigDGrQalq5FlvFJgVdcks1G3HaDBFhHG4xgrLpYwlFohwrUX1YRPgeurQYk2uQ0CeYQQSBqR4xMjnSd3RrPOyGBUD+oYp8Ht9LJ60B4Gby3UI9'
            '1GLM7JIK39NhbntoqKNxHcV1gVPgPRPAx6LVuRKMEw9bInpqxjBi6lk/Xh72/sMHvh6FwbALVoBCYCgAAcLAQABIwMBAQVdABAAAAyA5goBFXS+'
            'sgAA'
         ) -join''

         try {
             [System.IO.File]::WriteAllBytes("$tmpdir\patch.7z", [System.Convert]::FromBase64String($patch))

             &($7zpath) e -t7z "$tmpdir\patch.7z" -o"$tmpdir" | Out-Null
             if ($LASTEXITCODE -ne 0) {
                Show-Balloon -Message "Error unpack patch" -MessageType "Error"
                throw 'Error unpack patch'
             }
             Write-Host "Unpack patch: OK" @green

             if ([IO.File]::Exists("$scriptPath\0_zero_patch.ini")) {
                Move-Item -Path "$scriptPath\0_zero_patch.ini" -Destination "$tmpdir\0_zero_patch.ini" -Force
             }

             Write-Host "Start 0_opera_zero_patch.exe..."
             $0zpid = (Start-Process -FilePath "$tmpdir\0_opera_zero_patch.exe" -NoNewWindow -WorkingDirectory $tmpdir -PassThru).id
             if (-not $0zpid) {throw 'Error run patcher'}

             while ((Get-Counter "\Process(0_opera_zero_patch)\% Processor Time").CounterSamples.CookedValue) {Start-Sleep -s 3}
             if ($0zpid) {Stop-Process -Id $0zpid -Force}

             Write-Host "Patching completed: OK" @green
         } catch {
             Write-Host "$_.Exception.Message" @red
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
         'installation_status.json'
         'installer_prefs.json'
      )

      if ([IO.Directory]::Exists($AppPath)) {
         Get-Item -Path "$AppPath\*" -Exclude $nodel -ea 0 | Remove-Item -Recurse -Force -ea 0
         Write-Host "Delete old files: OK" @green
      } else {
         [IO.Directory]::CreateDirectory($AppPath) | Out-Null
         Write-Host "Create folder $($AppPath): OK" @green
      }

      $excludeList = $SetupExclude + @(
         'setdll-x64.exe'
         'setdll-x86.exe'
         'opera.exe~'
         '0_opera_zero_patch.exe'
         '0_zero_patch.ini'
         '2.7z'
         'patch.7z'
         '7zr.exe'
         'op.exe'
         'setdll.7z'
         'version.zip'
         'config.ini.example'
         'config.ini.example.zh-CN'
      )

      $excludeList | ForEach-Object {
         $excludePath = "$tmpdir\$_"
         Get-Item -Path $excludePath -ea 0 | Remove-Item -Recurse -Force -ea 0
      }

      Copy-Item -Path "$tmpdir\*" -Destination $AppPath -Recurse -Force
      Write-Host "Copy new files to $($AppPath): OK" @green

      Get-Item -Path "$scriptPath\*.zip" -ea 0 | Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 | ForEach-Object {
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
Function Create-Profile ([version]$Version,[object]$Settings) {
   Write-Host "Create-Profile..."
   $localStateContent = @(
      '{"browser":{"enabled_labs_experiments":["cashback-extension-download@2","enable-parallel-downloading@1","gx-liv'
      'e-wallpapers-metrics@2","ignore-gpu-blocklist","pinboard@2","smooth-scrolling@2"],"flags":{}},"gxx_flags":{"ena'
      'bled":true,"migrated":true},"hardware_acceleration_mode_previous":true,"last_version":[0,0,0,0,0],"location":{"'
      'country":"RU","country_from_server":"RU"},"ui":{"tab_menu":{"open_tabs_expanded":true,"recently_closed_expanded'
      '":true}},"user_experience_metrics":{"reporting_enabled":false}}'
   ) -join ''

   $preferencesContent = @(
      '{"adblocker":{"acceptable_ads":{"enabled":false},"easyprivacy_list_reset_number":1,"enabled":false,"lists":{"ru'
      '":true},"trackers":{"enabled":true},"whitelist_initialized":true,"whitelist_version":4},"autofill":{"credit_car'
      'd_enabled":false,"enabled":false,"orphan_rows_removed":true,"profile_enabled":false,"profile_use_dates_fixed":t'
      'rue},"better_address_bar":{"enabled":true,"onboarding":{"init":"13198440634526182"},"search":{"enabled":false}}'
      ',"bookmark_bar":{"auto_visibility":false,"show_on_all_tabs":false,"show_reading_list":false},"bookmark_editor":'
      '{"expanded_nodes":[]},"bookmarks":{"partners":{"participating_user":false,"receiving_enabled":false},"trash_cle'
      'aner":{"migration_applied":true}},"browser":{"advanced_settings_enabled":true,"check_default_browser":false,"cl'
      'ear_data":{"3rd_party_services_data":true,"form_data":true,"passwords":true,"time_period":4},"fraud_protection_'
      'enabled":false,"fraud_protection_reports_enabled":false,"window_placement":{"height":768,"left":256,"maximized"'
      ':true,"top":160,"width":1024}},"browser_sidebar":{"panel_enabled":{"bookmarks":false,"history":false}},"continu'
      'e_shopping":{"amazon_section_enabled":false,"booking_section_enabled":false},"credentials_enable_autosignin":fa'
      'lse,"credentials_enable_service":false,"default_search_provider":{"synced_guid":"FF57F01A-0718-44B7-8A1F-8B15BC'
      '33A50B"},"detached_video_view":{"onboarding_state":3},"devtools":{"disabled":false},"download":{"directory_upgr'
      'ade":true,"prompt_for_download":true},"easy_share":{"enabled":false,"group_id":"","registered":false},"enable_d'
      'o_not_track":false,"extensions":{"blacklistupdate":{"version":"2099.12.31"},"opsettings":{"aaaheibinlhdehphhplb'
      'jalhlcilbama":{"blacklist_state":1},"aaipilfmheplbcghignccoiiebekkdhe":{"blacklist_state":1},"ablgnpngfaaficpck'
      'ehadaljnjgjkhbi":{"blacklist_state":1},"acdfdofofabmipgcolilkfhnpoclgpdd":{"blacklist_state":1},"acdffiidghhgjh'
      'cmdefcgegamggnpbbo":{"blacklist_state":1},"achhckalphdlhbnohjonneffefbmaddi":{"blacklist_state":1},"acklnhgjphb'
      'hhomkneonohbjnbmkclfb":{"blacklist_state":1},"adbjdnocafdjnliogmcbgoocaclkibma":{"blacklist_state":1},"adikhbfj'
      'dbjkhelbdnffogkobkekkkej":{"blacklist_state":1},"aelmefcddnelhophneodelaokjogeemi":{"blacklist_state":1},"aemgo'
      'bnhmjkokaanfjcikbeddfpfbcce":{"blacklist_state":1},"aeomjpdpbidddnfmmlenkpaennnpopkb":{"blacklist_state":1},"af'
      'ldfjciapjgcjhfokmfcmphbnnglblh":{"blacklist_state":1},"afpabppcibfahafilhkbbgfnlncppdnc":{"blacklist_state":1},'
      '"agapaenbopboombhnknhckhipdfpafgp":{"blacklist_state":1},"ahbojpmkkkcgacccmnfmfhljdfjfbpip":{"blacklist_state":'
      '1},"ahfgeienlihckogmohjhadlkjgocpleb":{"blacklist_state":1},"ahggfmgiidlaceichjfemgbaggnbaloe":{"blacklist_stat'
      'e":1},"ainmdbchbbpamcfcjknekaocfakdnajd":{"blacklist_state":1},"akjdheomplehjdgpjenoamnhhkcenlkf":{"blacklist_s'
      'tate":1},"alecjlhgldihcjjcffgjalappiifdhae":{"blacklist_state":1},"alhkcdjmbdfapjganlbaagddjdjihcep":{"blacklis'
      't_state":1},"amniameoojfljhbifpnphelgdopoccck":{"blacklist_state":1},"anledolmjgilmoppbpgbgnomclhellkn":{"black'
      'list_state":1},"aoeblpmededdgajkjbmlefkepphboide":{"blacklist_state":1},"aonedlchkbicmhepimiahfalheedjgbh":{"bl'
      'acklist_state":1},"apkgpnbdglipaagpckkbdbigfmmomobn":{"blacklist_state":1},"bapebekcapehfapcilombbgepgedmnmn":{'
      '"blacklist_state":1},"bbglkiiiofelplniblholffbhhjmdhhi":{"blacklist_state":1},"bcabkcaakkjfdlodkolfagbdejhhkigp'
      '":{"blacklist_state":1},"bcibcaaakpeekhbnddgnajbmjdcemfkf":{"blacklist_state":1},"bcmohgmkeiagakjobmokhjoadoacl'
      'mip":{"blacklist_state":1},"bddgdepojcnlholkbcamjclbnjhkedgp":{"blacklist_state":1},"bdgdkpbjcedffdjnndlkbiklne'
      'kjjcgb":{"blacklist_state":1},"bdigkpjbmbdepgpkjeabfghlchdmphke":{"blacklist_state":1},"bennllbledkboeijomefbhp'
      'idmhfkoih":{"blacklist_state":1},"bfccjhpkgjfcpmefdpcdlggalaagmbfg":{"blacklist_state":1},"bfdlbgbpgjichdjjmkdc'
      'pagfggicjfom":{"blacklist_state":1},"bfefdmepaiiimfhbgneijclbnailbghl":{"blacklist_state":1},"bfjikbeoangkcjpai'
      'cnjgahbfgikpkdp":{"blacklist_state":1},"bgeakjmfknncppbmgkkfbglnodccdecp":{"blacklist_state":1},"bgekjjcaelmbmk'
      'cefhdbjkoodmmkpogm":{"blacklist_state":1},"bgmjggbdncggibjfgjpbigdmcllcipef":{"blacklist_state":1},"bgpmiljelfn'
      'ilfcfmoppijdkmccbccel":{"blacklist_state":1},"bhfoemlllidnfefgkeaeocnageepbael":{"blacklist_state":1},"bhpbfllm'
      'bnjkckcnppollddmfpmipdna":{"blacklist_state":1},"bifdbibngieombdobbohdcehhdakpkfp":{"blacklist_state":1},"bikof'
      'acodmhdpkfdeeocponfcgjcdfbk":{"blacklist_state":1},"bjjlbcacffbohhnhgmkdebadjbncnhag":{"blacklist_state":1},"bk'
      'foggbmaeddfflfppchdlbakjilclbp":{"blacklist_state":1},"bkjbflodeemohgdgjgkabkpgeddeoiid":{"blacklist_state":1},'
      '"blhcicojjhpbkbjkcfmbpjjjndljmfon":{"blacklist_state":1},"bmcnncbmipphlkdmgfbipbanmmfdamkd":{"blacklist_state":'
      '1},"bmegbfbhgflcckljmemoifpbmgdnjdgp":{"blacklist_state":1},"bmomlmlebemnegohbcdkbimolmpfbfkh":{"blacklist_stat'
      'e":1},"bnagjbaemgbcodcpcdmljfbjdbngilpj":{"blacklist_state":1},"boikejnhiggonokccamalbhmenopmiji":{"blacklist_s'
      'tate":1},"bonfagbdfepfbhjgolfalmgldfbgjodi":{"blacklist_state":1},"bpffalghigmkdghibgickgcnkbcaidch":{"blacklis'
      't_state":1},"bphjnafcbklppigbjmpmedbknpkgmcce":{"blacklist_state":1},"cbbhaadllfhdkedgdbbjgjpcchpphkeh":{"black'
      'list_state":1},"cbnpimmlikdmfccbjhbjlmonkehnlofh":{"blacklist_state":1},"ccfjbdjailljfihgkoccfbiljjapiijb":{"bl'
      'acklist_state":1},"ccnkbaeamfbhdnmilamlkagpfgimgppo":{"blacklist_state":1},"cejkepkfiaamcjmncopbdmkhaiejcobf":{'
      '"blacklist_state":1},"ceoldlgkhdbnnmojajjgfapagjccblib":{"blacklist_state":1},"cgloclgndbkhmjcaddholfcgghcgmmig'
      '":{"blacklist_state":1},"cgpbghdbejagejmciefmekcklikpoeel":{"blacklist_state":1},"chacaccgfimlhfpcbfnmiiakheagc'
      'gon":{"blacklist_state":1},"chbcaligghoofpkhcibiffdjodocficj":{"blacklist_state":1},"chmafjoljihhplhhpjcceofefh'
      'hoddbl":{"blacklist_state":1},"cikkigamncoobkmpenfdeniclmehdidh":{"blacklist_state":1},"cjdmfkgghdkpkioehnffllf'
      'emipmjgef":{"blacklist_state":1},"clddifkhlkcojbojppdojfeeikdkgiae":{"blacklist_state":1},"clkckblnmlbemmgefidh'
      'lmjcfboijafe":{"blacklist_state":1},"cmckkgalnmmkfnefkjngdjfjegnkphng":{"blacklist_state":1},"cockmkcmoohjkdpai'
      'glfomnfapioccfd":{"blacklist_state":1},"cofphmcjpepfemkcobighilnnmnpodbg":{"blacklist_state":1},"cogmdockhimbjf'
      'ijfadgoggdeohjbagn":{"blacklist_state":1},"cpnbgpaofhgpahgbjfbkgdgoebndmnmi":{"blacklist_state":1},"cpngackimfm'
      'ofbokmjmljamhdncknpmg":{"blacklist_state":1},"cppdfeaamgpkngcgjpieiooeaajbdcjj":{"blacklist_state":1},"dafchpgm'
      'lgkdcpcelcohjadfcpodidgi":{"blacklist_state":1},"dakhgkakbjfehpibebmlelidlfjjdfig":{"blacklist_state":1},"dbbkg'
      'ilokaohnhheanpibgklmhmknhmm":{"blacklist_state":1},"dbekdmnaopdgflfbkodfbackiiggdlhb":{"blacklist_state":1},"de'
      'jnaecmjmpnajcpbhkelomfdnjdfgfe":{"blacklist_state":1},"dekjciiicdgkkcedkkcaopjjimlbbipe":{"blacklist_state":1},'
      '"dhbiikglaiiglphmhhjdhidliagpodbi":{"blacklist_state":1},"dhdgffkkebhmkfjojejmpbldmpobfkfo":{"blacklist_state":'
      '1},"dhenbdnfbgdadlbojchhimlmjlpcfpee":{"blacklist_state":1},"dhheemiaplnehidcpjkfjojjbhkhnfhm":{"blacklist_stat'
      'e":1},"dhhemdhonhlkaoadhbgdnogknjnagplg":{"blacklist_state":1},"djnfikhimijfcoaoblganhllmdjejggi":{"blacklist_s'
      'tate":1},"dkigkllnlkoblfbgfnfngfcnhmndonjm":{"blacklist_state":1},"dlcmabphabemcibpinmdkmojaofogdee":{"blacklis'
      't_state":1},"dldcbakcjliccckkmfjcblhciilpdcil":{"blacklist_state":1},"dlkeifdhkecgglmjpdeiccjpcmhagffp":{"black'
      'list_state":1},"dpglnfbihebejclmfmdcbgjembbfjneo":{"blacklist_state":1},"dpiejmibihoklikohojpofdfgnjhjdfj":{"bl'
      'acklist_state":1},"eagomcfjiefffhpaejnlpjccikpipdoe":{"blacklist_state":1},"ebhbijlilmnmfkibfimhlofimgfnjpjl":{'
      '"blacklist_state":1},"ebongfbmlegepmkkdjlnlmdcmckedlal":{"blacklist_state":1},"ecijengmojcngjjgghkfkgbjoogmlngb'
      '":{"blacklist_state":1},"edggkgdammihneiigjkbmbjbihobpoeo":{"blacklist_state":1},"edjkooiccbgjhlpfhkknkjhfpmjkm'
      'elk":{"blacklist_state":1},"eeiccfifdclpgnnaagpkjfpkaabgcbne":{"blacklist_state":1},"eencbeelgfacnhekfiklkobllf'
      'leohce":{"blacklist_state":1},"eeocknbjpmfgaclencnfjfkklmmfmiie":{"blacklist_state":1},"efcogfmkbpacgnppjambabg'
      'jkcgokmgp":{"blacklist_state":1},"efdbfjleifmgohdfpdmkkhngjbfgfdoe":{"blacklist_state":1},"efpeldimhbhjejgcdcbh'
      'mjllaafhjmge":{"blacklist_state":1},"egafjhhpbipcmpoiomegbckljbbbphoj":{"blacklist_state":1},"egmfaijlgimjnjgbl'
      'mkhfpalbfkeocii":{"blacklist_state":1},"ehlmjgafbankbokkgbjnalkgahahjgbd":{"blacklist_state":1},"ehlplolnhhknib'
      'ceabgcifghiplhajei":{"blacklist_state":1},"eikbfklcjampfnmclhjeifbmfkpkfpbn":{"blacklist_state":1},"ejddjnilmdn'
      'cjilbfjgameihlklfpohp":{"blacklist_state":1},"ejfajpmpabphhkcacijnhggimhelopfg":{"blacklist_state":1},"ejighbge'
      'edkpcambhfkohdalcgckdein":{"blacklist_state":1},"ekfodldkedhimgldfpmaagmkollebfkd":{"blacklist_state":1},"ekhkc'
      'kippcmagmjmbjncnlgiohlgaloc":{"blacklist_state":1},"ekpfhenefmlhjaljcghbioklgcpkalnn":{"blacklist_state":1},"ek'
      'pibplnnkfdcafdpoekhoffegcajene":{"blacklist_state":1},"elchiiiejkobdbblfejjkbphbddgmljf":{"blacklist_state":1},'
      '"elfogobdbdpoimhojimfklolannbcbmn":{"blacklist_state":1},"elkloalhpglgboehkapabfhjpmkmeook":{"blacklist_state":'
      '1},"elmbcmlmdjfemolgapoecfhcmcjgdmbh":{"blacklist_state":1},"elmggllmmdmjlbkfnbpmmfaofkihmcag":{"blacklist_stat'
      'e":1},"enegjkbbakeegngfapepobipndnebkdk":{"blacklist_state":1},"enkgacgbeckkicmilhfokkjkdopicbbj":{"blacklist_s'
      'tate":1},"enmlgamfkfdemjmlfjeeipglcfpomikn":{"blacklist_state":1},"eoeoincjhpflnpdaiemgbboknhkblome":{"blacklis'
      't_state":1},"epeomjakeffkfofnidikcpbacmfliolc":{"blacklist_state":1},"faajihnmbfdjebpkhngdjlflookcjbpd":{"black'
      'list_state":1},"faminaibgiklngmfpfbhmokfmnglamcm":{"blacklist_state":1},"fbeogiannbchfkmanlajfddhjpdjccda":{"bl'
      'acklist_state":1},"fcmiiaoabfdmjddpbjianahclpbgmgnk":{"blacklist_state":1},"fefhaeemdgaophhobcpcopjgfjnmjpop":{'
      '"blacklist_state":1},"fefpbbcnadappdjlfplfppfaempaeakh":{"blacklist_state":1},"fehigimgapdgnlfhbjpjlnjgmeaamicj'
      '":{"blacklist_state":1},"fejahnjnkgccibegjdfpaekdpfppmabi":{"blacklist_state":1},"ffeocbomcpokpmjkkloomhnflpjmk'
      'jpi":{"blacklist_state":1},"ffhfoagmjcnkolneahbpagjcjjaeofbg":{"blacklist_state":1},"fgaapohcdolaiaijobecfleioh'
      'cfhdfb":{"blacklist_state":1},"fgfffefkfpmbjmhofnofmiikiolcbhll":{"blacklist_state":1},"fgldnknlljnfcfgchdijbjm'
      'mkdkmnabn":{"blacklist_state":1},"fgpadjighkndmfhkcbalgfknjomlphgp":{"blacklist_state":1},"fhnjdejfbngngppihmpg'
      'ncfnpfdaglhg":{"blacklist_state":1},"fhpakgdnncieelihbbgoamgmaijegbmg":{"blacklist_state":1},"fijhlnmmmgflacagj'
      'ecncpmpnhjieggk":{"blacklist_state":1},"fikjahjajgkcnpcbhcccfkleoaobfhnc":{"blacklist_state":1},"fjfiaeaopgmgbe'
      'nipljajjipecobmbni":{"blacklist_state":1},"fkbmjpofpcpmmokgmkehcpbofjombfoe":{"blacklist_state":1},"fklejhhcpib'
      'pijjcfoobbncmnlhnckoo":{"blacklist_state":1},"fklnhhlgonmaiddgllfeppnpdpohkilk":{"blacklist_state":1},"flijfnhi'
      'fgdcbhglkneplegafminjnhn":{"blacklist_state":1},"fmkphmmfaegafifgbimockbafpnfhkhe":{"blacklist_state":1},"fnaej'
      'njikodabjplcjngjnjniokmapkm":{"blacklist_state":1},"fnekoclofbckijjfldbebkajlclgdcop":{"blacklist_state":1},"fn'
      'eleoohaagcejefkfmanhhdoboipapk":{"blacklist_state":1},"fopbkiidibcjjlcpnpldcpdiiafeclci":{"blacklist_state":1},'
      '"fpaneejencmpllfhjmcgaochdekpbgac":{"blacklist_state":1},"gabbbocakeomblphkmmnoamkioajlkfo":{"blacklist_state":'
      '1},"gbgkoodppmcmfeaegpelbngiahdcccig":{"blacklist_state":1},"gbnahglfafmhaehbdmjedfhdmimjcbed":{"blacklist_stat'
      'e":1},"gegdfeiahlfolhcfioipjlkombmgbakh":{"blacklist_state":1},"gemikcofekbgchaopjcbkbejolnkehgk":{"blacklist_s'
      'tate":1},"gfbfbgkkbcngelbjegbhmoaopnfemijp":{"blacklist_state":1},"gfflcpencnmidmbdklfkbmfjmbieaopp":{"blacklis'
      't_state":1},"gfjocjagfinihkkaahliainflifnlnfc":{"blacklist_state":1},"gfobfmjpcnapngbghpcbodncehngmdln":{"black'
      'list_state":1},"ggolfgbegefeeoocgjbmkembbncoadlb":{"blacklist_state":1},"ghcdaheihefjaiihlegkggmmanbakmge":{"bl'
      'acklist_state":1},"ghjpghegkcioppihginheepcphjnnccc":{"blacklist_state":1},"gieanldgaaaifgdkimlkfakbpofihpdf":{'
      '"blacklist_state":1},"gigbhaknoaicbdhgjniamnpmgcpjipim":{"blacklist_state":1},"gimiionhcndpmfdmapaliaipdpfemhnb'
      '":{"blacklist_state":1},"gkcgcddlhhlldmjffagogcoalhmfigoh":{"blacklist_state":1},"gkookgoofbomddkomagahpnpdcneb'
      'nad":{"blacklist_state":1},"glcpnoejchojbemelmbedggmdcgnpjkc":{"blacklist_state":1},"glgemekgfjppocilabhlcbngob'
      'illcgf":{"blacklist_state":1},"gmafbpocegdimljancjekdbidendhhag":{"blacklist_state":1},"gnamdgilanlgeeljfnckhbo'
      'obddoahbl":{"blacklist_state":1},"gnjbfdmiommbcdfigaefehgdndnpeech":{"blacklist_state":1},"gojhcdgcpbpfigcaejpf'
      'hfegekdgiblk":{"blacklist_state":1},"gpabpfikknflecblchhfkpkcpilbkfcd":{"blacklist_state":1},"gpfbncnkoeocopnpc'
      'acbbkdljdfhekcl":{"blacklist_state":1},"gphjehcgndcjccmghmjmeeabfecdiilm":{"blacklist_state":1},"gpjmfdieiklnco'
      'hnadedkaghcenckggl":{"blacklist_state":1},"hadnccdgifjbhomjojnjpbpbcjbhamha":{"blacklist_state":1},"hcmdpeobfop'
      'pdkhcneogcflfmfceenlf":{"blacklist_state":1},"hdbipekpdpggjaipompnomhccfemaljm":{"blacklist_state":1},"hdekmjpl'
      'fobcpcbmjfgabhecjdccobnb":{"blacklist_state":1},"hdhmofnopkgkpgnpggloijpbnaonhplc":{"blacklist_state":1},"henjc'
      'fljdhhpcekclnnbhmgbacdfkoho":{"blacklist_state":1},"hffpndpljemgdfjjkijcidbhadeiillo":{"blacklist_state":1},"hh'
      'ancmkfonfhfbhjoobemlmegdjkboia":{"blacklist_state":1},"hhckidpbkbmoeejbddojbdgidalionif":{"blacklist_state":1},'
      '"hhmfdibgakhagkpalkmfamkaojignmbm":{"blacklist_state":1},"hjanbijkblmillaeknkalicgnjidndkl":{"blacklist_state":'
      '1},"hjccmeejehoiaokolmpoibekjlkgenea":{"blacklist_state":1},"hjghiofiijcepdnocbgefbdlbckjfheg":{"blacklist_stat'
      'e":1},"hjlmfejeepodkfiapgfhkniokjdcmkfo":{"blacklist_state":1},"hjmimgeipgjgdblgkjpgaknjeidbnjdb":{"blacklist_s'
      'tate":1},"hkmfdialkjnljbcnincgpollobclebaf":{"blacklist_state":1},"hlgnlpcakcbhfheemdcodfddnojhimjn":{"blacklis'
      't_state":1},"hmoajegljdhdbaggehffkmopedacnjhf":{"blacklist_state":1},"hmoibobbgceninnjaoadkgaceabjjeab":{"black'
      'list_state":1},"hnbekdjpdldejohkmdonijjglpohocgo":{"blacklist_state":1},"hndapinaldbddbjnhebjakhlgbcahhmp":{"bl'
      'acklist_state":1},"hniiadklfgdhjcmmkpggffjngihaaoip":{"blacklist_state":1},"hoidflomjnnnbiemmkjdjkkialmhbago":{'
      '"blacklist_state":1},"hpbibljgpldkablgfoapbnilcambjann":{"blacklist_state":1},"hpmcdiephomdkjdpgbbjhnlebeofkdcd'
      '":{"blacklist_state":1},"iabhcmlfmommijjhppgpmaldhnnodggp":{"blacklist_state":1},"iagimhmngolcolenneiopfpadlhka'
      'dnm":{"blacklist_state":1},"ianpkncpdncekpjnlflanaomeeenkehn":{"blacklist_state":1},"iapdadaeaebaoigieglfababne'
      'oaifnf":{"blacklist_state":1},"ibgcfekaaejggoajjnmknjcoieffdnod":{"blacklist_state":1},"icdkfljeilkpnmnaoldgjnh'
      'pdmjilacj":{"blacklist_state":1},"ickfamnaffmfjgecbbnhecdnmjknblic":{"blacklist_state":1},"icpgdmbkannfhajbcink'
      'ekegjlcbcibl":{"blacklist_state":1},"idddminncgmajidohcdinleodnnhmpip":{"blacklist_state":1},"ieejjmmgeihokfnli'
      'pbofpgnajfkdbbo":{"blacklist_state":1},"ienbdpmgofiaifnocdhlcidpbocpkcpi":{"blacklist_state":1},"ieomhnichbamgi'
      'mkoacbpinnnlnpllej":{"blacklist_state":1},"igpdmclhhlcpoindmhkhillbfhdgoegm":{"blacklist_state":1},"ihpefnlnjmj'
      'hhaeimddlnnnnmeifbaih":{"blacklist_state":1},"iibnodnghffmdcebaglfgnfkgemcbchf":{"blacklist_state":1},"iiiiclke'
      'hccggnlplmppddaojajicccb":{"blacklist_state":1},"iilfecopjcmjdgfffklfdkhbkpkmcglh":{"blacklist_state":1},"ijebc'
      'gdknomkjgokkdhjhigkamcibajk":{"blacklist_state":1},"ikfpbngpljflklamndjomipdijkhehlm":{"blacklist_state":1},"ik'
      'ihdpjgbomalcdgfdbkeodegggogdfk":{"blacklist_state":1},"iklgpchfbohgmghgfagediakopecfmbm":{"blacklist_state":1},'
      '"ildkkhljjpmpfhdfielmpmjhdnfkcnog":{"blacklist_state":1},"ilhhefepljbmehhbmjcflhcchkddfaon":{"blacklist_state":'
      '1},"immmcdbdgkahpciheaofoldhlbddmkfc":{"blacklist_state":1},"imodfccolnjcdccplejdejgjfofdemag":{"blacklist_stat'
      'e":1},"inlgdellfblpplcogjfedlhjnpgafnia":{"blacklist_state":1},"inokjfhioapobnjgjaaolbehffampmaa":{"blacklist_s'
      'tate":1},"iobdjpockeoakepiehbjjokhdaacncjl":{"blacklist_state":1},"iodlkjhnibdblegehlgpafnlhjgpfkbc":{"blacklis'
      't_state":1},"ioipkkmonpmomecbmggejienahinjkjj":{"blacklist_state":1},"ionkhgehfolinkdpgdbinmgbfaonpcnk":{"black'
      'list_state":1},"ionnbjojpjaebeodjppancfcibnhbmkj":{"blacklist_state":1},"ipffdejgljghfbblplflhbgffgfiiahi":{"bl'
      'acklist_state":1},"iphpmnjjkbneokidkdkcdfhlhlimhnfj":{"blacklist_state":1},"ipljmghelflfikejmgkmlmpjmehfjodc":{'
      '"blacklist_state":1},"ipnpelpjmnmepmgacemjkdkjlappmnen":{"blacklist_state":1},"jakjjociimoagbmcnmaamffhkblkjckg'
      '":{"blacklist_state":1},"jaocpokicpmlhbchlodlkiochdkmophj":{"blacklist_state":1},"jbbopffnmpigiiejdknggggagcona'
      'elh":{"blacklist_state":1},"jbebdjcjllheeclffnofhgcimmlkkbon":{"blacklist_state":1},"jchepaljijgokkoflakjioknkf'
      'olenbk":{"blacklist_state":1},"jenggbjfjblgmpcfejchbpnpineboigk":{"blacklist_state":1},"jfeofbkfcmflbdpoalgojin'
      'abfcmlnhd":{"blacklist_state":1},"jhapbopfchfogphiimjbhodmgnppoigk":{"blacklist_state":1},"jhfoecipcbpoboeafakd'
      'pjaakpdigclg":{"blacklist_state":1},"jhommlgbajjmgdjfkofmjkdiicdfknde":{"blacklist_state":1},"jhongheibdpfhdpfc'
      'cheljfcabgliidh":{"blacklist_state":1},"jifbgnmbgbdiedhdecealmlgmekpagde":{"blacklist_state":1},"jjemmelkbnacap'
      'onpdabclcijeocgpbj":{"blacklist_state":1},"jkbblkobgokdimiefleebjbhmnfjlcfg":{"blacklist_state":1},"jkdoinhjjdm'
      'fodnfaaephhefgngbahdp":{"blacklist_state":1},"jkkngokdooagpeidijbihiofdalckjmh":{"blacklist_state":1},"jkppjbnd'
      'blkfgafdlihkaedojdgfebkp":{"blacklist_state":1},"jnopjcjmhhkhhmnhgllahnblhhfokggh":{"blacklist_state":1},"joeal'
      'mmpdfblhdcnohmooogdinombncc":{"blacklist_state":1},"jofgidplbodcmfnnkmlbhgajpkipfiin":{"blacklist_state":1},"jo'
      'oenbpgafdodkkhmmieoenilajdkcce":{"blacklist_state":1},"kbcgpdfdlgefpkoghnfflbhbbfomiiho":{"blacklist_state":1},'
      '"kbmbmoljonchdkbjgkioneippcfpnpmp":{"blacklist_state":1},"kbmoiomgmchbpihhdpabemajcbjpcijk":{"blacklist_state":'
      '1},"kcdeaofcapijfmeopimkgcepdpbdepnb":{"blacklist_state":1},"kcfefccmndghghcanogfebekgbajgibi":{"blacklist_stat'
      'e":1},"kcknbenjnkkjknphmnidanjifbgphjke":{"blacklist_state":1},"kcmioinhpoafnnoeghbfkebnoiiibbdk":{"blacklist_s'
      'tate":1},"kdbilhbpkjkfbbnggidbphgobpcklbhl":{"blacklist_state":1},"kdjbjneddimaafbndnkbfdggjncaegoi":{"blacklis'
      't_state":1},"kdndmfchehllpmgpkgeibmojedlfdhaf":{"blacklist_state":1},"kecobnmhcdkmdjifldaeiiaajaggahdp":{"black'
      'list_state":1},"kedpicenkkndemblkfpnngmcihdfhndn":{"blacklist_state":1},"keinkhgnlckanellohdllejmhipfocmi":{"bl'
      'acklist_state":1},"kelbkhobcfhdcfhohdkjnaimmicmhcbo":{"blacklist_state":1},"kenbohlglcfaciabepmecjhipnpmjkgp":{'
      '"blacklist_state":1},"kfegjkgamdgpojndjlflplinedgplfdh":{"blacklist_state":1},"kfgaibfbmkjgmimhbbaikfnpkkjkpoan'
      '":{"blacklist_state":1},"kfhepdlicclpndldhdpnfpknmdelndkf":{"blacklist_state":1},"kfjnfapiocpibeddeekmbikhpegjh'
      'dgi":{"blacklist_state":1},"khmiehpkiedpkpifcpeplghoibfhhigo":{"blacklist_state":1},"kjmiajamiimndhpicnkbijomng'
      'kocnfn":{"blacklist_state":1},"kjpifmjicccpbkfjdkehimhgklfkbanh":{"blacklist_state":1},"kldakcdhjlgjdccaienlkmb'
      'gopehmiag":{"blacklist_state":1},"klejifgmmnkgejbhgmpgajemhlnijlib":{"blacklist_state":1},"kljbbcnooaklhpifalni'
      'hdiofoahmmjj":{"blacklist_state":1},"kllbakgkphnnkiphbfclpjfebkfiiefg":{"blacklist_state":1},"klmjcelobglnhnbfp'
      'mlbgnoeippfhhil":{"blacklist_state":1},"klonfdlcigipbecdhifijjaajfgoagkl":{"blacklist_state":1},"kmendfapggjeho'
      'dndflmmgagdbamhnfd":{"blacklist_state":1},"kneggodalbcmgdkkfhbhbicbbahnacjb":{"blacklist_state":1},"knlpigpfaog'
      'nbholppaembpfphilacie":{"blacklist_state":1},"knohfebhibeknbfioecpdmdkjkjdnjnl":{"blacklist_state":1},"kobomddd'
      'pdjfpdpkfieihgdcefokgcnd":{"blacklist_state":1},"kofpgjgokfidcohjcdfcndkbindgmcmc":{"blacklist_state":1},"kolkn'
      'mpohlhhicbgmmhnglllbgcegieb":{"blacklist_state":1},"lageaglodnhalgfffeniacefghklcdij":{"blacklist_state":1},"la'
      'lpacfpfnobgdkbbpggecolckiffhoi":{"blacklist_state":1},"lblbnlfhhblmfconjalikamamlgoobbe":{"blacklist_state":1},'
      '"lbnbllcdpdibhehjbcbaidnddopkpgbf":{"blacklist_state":1},"lcmpcbiknifdfieonipkoebfppegdmpp":{"blacklist_state":'
      '1},"ldbfffpdfgghehkkckifnjhoncdgjkib":{"blacklist_state":1},"ldkihpcibakajmpnggbjnehoifnnpebn":{"blacklist_stat'
      'e":1},"leekgcollcnefaicnebbboegaccpmabn":{"blacklist_state":1},"lfedlgnabjompjngkpddclhgcmeklana":{"blacklist_s'
      'tate":1},"lffnnnfdablgamegkcboelplpcjoacmm":{"blacklist_state":1},"lhbicobpnnmpbhnneadgpcaonipnlpab":{"blacklis'
      't_state":1},"lhnnoklckomcfdlknmjaenoodlpfdclc":{"blacklist_state":1},"ljbegplllhffbfldlfjoacfdcbhcgnpo":{"black'
      'list_state":1},"ljefoakgfhcoeobgicjgejglnpfpemgb":{"blacklist_state":1},"lkadffjmnaiokkdncgdlecdegajoiemi":{"bl'
      'acklist_state":1},"lkdanligledioimheahflbepecbceang":{"blacklist_state":1},"llkfnldljepopholdohmfjjlofppajii":{'
      '"blacklist_state":1},"llpiooofdeacaeccmkfmcolhpggemicb":{"blacklist_state":1},"lmcajpniijhhhpcnhleibgiehhicjlnk'
      '":{"blacklist_state":1},"lmiknjkanfacinilblfjegkpajpcpjce":{"blacklist_state":1},"lmkeljmlecjkakkekfebmhmahhhfl'
      'onf":{"blacklist_state":1},"lmnbobhffedhdhfpcjkjphcfpeeiocdn":{"blacklist_state":1},"lmokomhjjblhlegiepekpmdfal'
      'lkiake":{"blacklist_state":1},"lnocaphbapmclliacmbbggnfnjojbjgf":{"blacklist_state":1},"lpgjcjiidibpkgbodjpfhpb'
      'hlapmebdn":{"blacklist_state":1},"lpjhpdcflkecpciaehfbpafflkeomcnb":{"blacklist_state":1},"mafpbclkdiejmpjnmioi'
      'hcafdnlbmkco":{"blacklist_state":1},"makcojoppodhcgmmchohadhpkicoafka":{"blacklist_state":1},"mbacbcfdfaapbcnln'
      'bmciiaakomhkbkb":{"blacklist_state":1},"mbcghjbibnjcclnoddklipnkmggfinfb":{"blacklist_state":1},"mbgbaiiinbmbam'
      'iflklamkebhkcglfin":{"blacklist_state":1},"mchcgpoacfgcfeidgjhokjgiblhhpcgn":{"blacklist_state":1},"mdnmhbnbeba'
      'bimcjggckeoibchhckemm":{"blacklist_state":1},"mdpgppkombninhkfhaggckdmencplhmg":{"blacklist_state":1},"mdpljndc'
      'mbeikfnlflcggaipgnhiedbl":{"blacklist_state":1},"meejmcfbiapijdfaadackoblffmidlig":{"blacklist_state":1},"mfglb'
      'jdihkhhnimlecioccjbjiepicip":{"blacklist_state":1},"mfhnkgpdlogbknkhlgdjlejeljbhflim":{"blacklist_state":1},"mg'
      'fbpopbgcnocgpncdjlmifdbcdipbfa":{"blacklist_state":1},"mhjfbmdgcfjbbpaeojofohoefgiehjai":{"blacklist_state":1},'
      '"mhljmbhdpcbofeflpfiehajciopgajen":{"blacklist_state":1},"mibfbmhijjgpkmobcfdlelpccpeafoom":{"blacklist_state":'
      '1},"midfadfpkkakgcmbgpngfnfekghligek":{"blacklist_state":1},"miejmllodobdobgjbeonandkjhnhpjbn":{"blacklist_stat'
      'e":1},"mjahececmjlmafhbafbbopnfgkigfdgc":{"blacklist_state":1},"mjfnijmemjilopepdgnakgghiboempgf":{"blacklist_s'
      'tate":1},"mjoahfjnfmhgjiioedjkbclgkcjcbjef":{"blacklist_state":1},"mkndcbhcgphcfkkddanakjiepeknbgle":{"blacklis'
      't_state":1},"mlgoafdnenppocminhopgjkicnieaodp":{"blacklist_state":1},"mlicfibfgknanmflbnecpkokekamjbei":{"black'
      'list_state":1},"mljbnbeedpkgakdchcmfapkjhfcogaoc":{"blacklist_state":1},"mlkeojglbgaiiejfjfhackccniicnkib":{"bl'
      'acklist_state":1},"mmmbddcnnndpbdflpccgcknaaabgldak":{"blacklist_state":1},"mmnbenehknklpbendgmgngeaignppnbe":{'
      '"blacklist_state":1},"mnafnfdagggclnaggnjajohakfbppaih":{"blacklist_state":1},"mnanplinmmnjhobaliikmelmmjpoogkb'
      '":{"blacklist_state":1},"mnjejilcobdkeaholenhgcchnelddigl":{"blacklist_state":1},"mnonkalmdjjnelekfdaldkknjkedg'
      'amf":{"blacklist_state":1},"moifnijmpffdmniakcdkhageikfcgmbm":{"blacklist_state":1},"mpaghnpkgmnikepcgjddhckced'
      'apomkp":{"blacklist_state":1},"mpcgcpbbohmcfanbnlobnmnfojpilomj":{"blacklist_state":1},"mpojjmidmnpcpopbebmecmj'
      'dkdbgdeke":{"blacklist_state":1},"najdlnokhipbhcnfadjmdnieblmciedc":{"blacklist_state":1},"napifgkjbjeodgmfjmgn'
      'cljmnmdefpbf":{"blacklist_state":1},"nbomckfkgpfkhgcponiencnhemallhhh":{"blacklist_state":1},"ncnadiaifiaoeoela'
      'ipabcacbkgjilmn":{"blacklist_state":1},"ndbnfbenjdkkckmlklmjpipaokfccegf":{"blacklist_state":1},"neclhebkjhajag'
      'boegcjjhfmkmpgonmf":{"blacklist_state":1},"nfcgjdbmaldigcikhaommmbndpiajidc":{"blacklist_state":1},"nhihpocelkl'
      'gjchjgmbedohjgckokfha":{"blacklist_state":1},"nhjehbmopbfbomhchfkhbghcehpeiijl":{"blacklist_state":1},"nhkchino'
      'gebbapokmlnfbfoglnonminm":{"blacklist_state":1},"nilbfjdbacfdodpbdondbbkmoigehodg":{"blacklist_state":1},"njfjk'
      'pickfhifbpkbkobflbggphjncgf":{"blacklist_state":1},"njmpphablmnjackgpmigponapahookhj":{"blacklist_state":1},"nk'
      'eimhogjdpnpccoofpliimaahmaaome":{"blacklist_state":1},"nklfajnmfbchcceflgddnkignfheooic":{"blacklist_state":1},'
      '"nlgdemkdapolikbjimjajpmonpbpmipk":{"blacklist_state":1},"nmeeibajhbcldcphgjpmailfheoikbjn":{"blacklist_state":'
      '1},"nmghlnjjldbehnfaejmbpophglopclgn":{"blacklist_state":1},"nmpbgihpdmmclgognfcendlnemeppbna":{"blacklist_stat'
      'e":1},"nncaiajgdieahgnnoeijjohcnpobmcmo":{"blacklist_state":1},"nnjpmkckpiemokajkiggmmelpkdnkamd":{"blacklist_s'
      'tate":1},"noeldoghpbgogfocehhbhhpfnagnhbbh":{"blacklist_state":1},"nojkagbjbhgnilkopgljfkhddmdjcjfn":{"blacklis'
      't_state":1},"nomkmakjljpekcjbckcmffldeekdanpa":{"blacklist_state":1},"nonjdcjchghhkdoolnlbekcfllmednbl":{"black'
      'list_state":1},"npefbnhfjaofkhehcnhmacaeinbponln":{"blacklist_state":1},"oaljndinbnpjfmcgphpnbpgodonlkfgo":{"bl'
      'acklist_state":1},"obhaigpnhcioanniiaepcgkdilopflbb":{"blacklist_state":1},"obibnhlhdkjpopoicbdaahjoalknmhdc":{'
      '"blacklist_state":1},"objoaichchnolncdebkiiipkjlligamm":{"blacklist_state":1},"obpjkecphechmoodhajjnggfpfmnclfc'
      '":{"blacklist_state":1},"ocpleophfhddnogoadhmhpbjanddmnnj":{"blacklist_state":1},"odjhjffdagbhaiolbgglchoknklcj'
      'pab":{"blacklist_state":1},"odndjkngipngdmdlfodecoelobjbidna":{"blacklist_state":1},"oehahoblpagnioelpmminjmlpn'
      'abnmok":{"blacklist_state":1},"ofaemmlijemfcopjandkcndefpnacabg":{"blacklist_state":1},"ognampngfcbddbfemdapefo'
      'hjiobgbdl":{"blacklist_state":1},"oigmkbmjkjbfaplhliobjafedfaiimnb":{"blacklist_state":1},"oijfnkfijppleacdmhpo'
      'gnjiflfmhhll":{"blacklist_state":1},"ojgocckppmpfapbainkbhggkhfehjeal":{"blacklist_state":1},"oknpgmaeedlbdichg'
      'aghebhiknmghffa":{"blacklist_state":1},"olkpikmlhoaojbbmmpejnimiglejmboe":{"blacklist_state":1},"olmkgngoemapff'
      'inkddjhgdfngbeklml":{"blacklist_state":1},"ompjkhnkeoicimmaehlcmgmpghobbjoj":{"blacklist_state":1},"onbkopaoema'
      'chfglhlpomhbpofepfpom":{"blacklist_state":1},"onigllbobbpllnfcjanphobocbkcdghh":{"blacklist_state":1},"ooaghkci'
      'ikfmlhgnhfacgefmpilcmjfm":{"blacklist_state":1},"oobppndjaabcidladjeehddkgkccfcpn":{"blacklist_state":1},"papba'
      'doldddalgcjcicnikcfenodpghp":{"blacklist_state":1},"pbdpajcdgknpendpmecafmopknefafha":{"blacklist_state":1},"pb'
      'fepikhnmdnebapdmnhpbpckliioejd":{"blacklist_state":1},"pbffpbffjfiigoledmkcibcbadpbenec":{"blacklist_state":1},'
      '"pcaaejaejpolbbchlmbdjfiggojefllp":{"blacklist_state":1},"pcedcainfpmibhlcppehljkpejdcpjjn":{"blacklist_state":'
      '1},"pclkdeomnmkopgobgjfpejgkpmeoooen":{"blacklist_state":1},"pdcifnciicbfakdajkbbhphlabjminhg":{"blacklist_stat'
      'e":1},"pdfbhfjldacbdamjhomkgomeialekbng":{"blacklist_state":1},"pdfmhakmnmnlelkmmjjhohokbnlffmam":{"blacklist_s'
      'tate":1},"pdjjjmnacfjnmgckbhldbekckfldeolk":{"blacklist_state":1},"pdkmcmpnodclbbopghhicfkifklpokkf":{"blacklis'
      't_state":1},"pebomakhlodngdfjibemmpmbjgkcmboh":{"blacklist_state":1},"pepjgkdpkihjnbdaggonbpphlfkbhdli":{"black'
      'list_state":1},"pfbcjkjbmanhfmofhiinhmndghpadicm":{"blacklist_state":1},"pfmbamigamleojkkogbejpgjdbmadgca":{"bl'
      'acklist_state":1},"pfmhmjadbiokegmddpjggiaenhjopfek":{"blacklist_state":1},"pfmlgdpgagephflfijfmhjckammbifgk":{'
      '"blacklist_state":1},"pfnmibjifkhhblmdmaocfohebdpfppkf":{"blacklist_state":1},"pgeolalilifpodheeocdmbhehgnkkbak'
      '":{"blacklist_state":1},"pgjndpcilbcanlnhhjmhjalilcmoicjc":{"blacklist_state":1},"pgkbgflmbfpkbehmfneoglkjkagbk'
      'hgd":{"blacklist_state":1},"phefhkfojhcgelmcpapbplmnnbplaceg":{"blacklist_state":1},"pheobeikgpfdjfnlnhinkcogfl'
      'mkcmlc":{"blacklist_state":1},"pigfcegpjglokkoepljficmhccdliidd":{"blacklist_state":1},"pjbgfifennfhnbkhoidkdch'
      'bflppjncb":{"blacklist_state":1},"pjpjebckabnbmgoemoffjnnkggcopgkb":{"blacklist_state":1},"pkbffhpdalaceholagpc'
      'omhnigjjdfdb":{"blacklist_state":1},"pkhnghdfdplkeiiodmfnfdkipfmpgabe":{"blacklist_state":1},"plbapklgjloajcpha'
      'kijooiimlfbghaj":{"blacklist_state":1},"pldeppocfnbnopadlkalkhefdhglkijd":{"blacklist_state":1},"pleoihkpdomoij'
      'dpaibdciidfoeedamm":{"blacklist_state":1},"plimopelmdneikoknbgpopffpbmlhgpa":{"blacklist_state":1},"pmijnggdaad'
      'ccmmmoofgdcaikjmkiglk":{"blacklist_state":1},"pmpnemphhmmpkcafgpdjanghiaadfbef":{"blacklist_state":1},"pnafobbi'
      'lipbceafdgkhepgdhjahjkjl":{"blacklist_state":1},"pnejckbihndhccfkbmngjjoaiefmjofm":{"blacklist_state":1},"pnncl'
      'ahpifbjkboanbjecjoaoelleoep":{"blacklist_state":1},"pnokkmkadpdpeejjcpcidionamhmoolj":{"blacklist_state":1},"po'
      'gmclhffdfjphnjlikiijmdjpjlfodk":{"blacklist_state":1},"poifboaadcogleeibokkcinojokfldem":{"blacklist_state":1},'
      '"pojgkmkfincpdkdgjepkmdekcahmckjp":{"blacklist_state":1},"pookachmhghnpgjhebhilcidgdphdlhi":{"blacklist_state":'
      '1}}},"freedom":{"proxy_switcher":{"bytes_transferred":"0","enabled":false,"forbidden":false,"local_searches":fa'
      'lse,"stats":{"values":[]},"tos_accepted":true,"ui_visible":true}},"game_strips":{"enabled":false},"gcm":{"produ'
      'ct_category_for_subtypes":"org.chromium.windows"},"gx":{"chroma_equalizer_sites_version":1,"hidden_sections":"n'
      'ews,stores,video-princess-farmer,upcoming_releases,trailers,deals_aggregator,top-demo-try,release_calendar,gxc,'
      'free_games,top-music23,games-that-will-touch-your-heart","monday_news_locales":"en_US","play_sounds":false,"wid'
      'gets":{"enabled":false,"gx_me":false}},"gxcorner":{"is_custom_wallpaper_enabled":false,"is_wallpaper_animation_'
      'enabled":false},"hint":{"ad_blocker_offer":{"init_time":"13140303966104492"},"ad_blocker_offer_for_power_save":'
      '{"init_time":"13140303966104492"},"address_bar_search":{"init_time":"13140303966104492"},"mute_background_tab":'
      '{"init_time":"13140303966104492"},"power_save_mode":{"init_time":"13140303966104492"},"power_save_mode_automati'
      'c":{"init_time":"13140303966104492"},"proxy_switcher_reminder":{"init_time":"13140303966104492"},"sidebar_media'
      '_permissions_cam":{"init_time":"13195491792226515"},"sidebar_media_permissions_mic":{"init_time":"1319549179222'
      '6453"},"startpage_configuration":{"init_time":"13140303966104492"}},"mouse_gestures":{"enabled":false,"user_not'
      'ified":true},"net":{"network_prediction_options":2,"network_qualities":{}},"opera":{"deduplication_bookmark_mod'
      'el_changed":false,"deduplication_last_successful_run":"13245409147440487","oauth2":{"session":{"refresh_token":'
      '"","session_id":"","session_state":"","start_method":"","start_time":"","user_id":"","user_name":null}},"qualit'
      'y":{"utime":-11644388756}},"partition":{"per_host_zoom_levels":{}},"payments":{"can_make_payment_enabled":false'
      '},"personal_news":{"history_recommendations_enabled":false,"notification_interval_minutes":0,"settings_data":"{'
      '\"version\":4,\"userLanguageCodes\":[\"ru-ru\"],\"subscribedCatalogSourceIds\":[],\"subscribedCustomSourceUrls\'
      '":[],\"userTop50LanguageCode\":\"uk-ua\"}"},"play_again":{"enabled":false,"visibility_state":"{\"state\":\"visi'
      'ble\",\"timestamp\":null,\"actionTimestamp\":1674341235134}"},"player_service":{"enabled":false,"id":"home"},"p'
      'lugins":{"always_open_pdf_externally":false,"plugins_list":[]},"power_save_mode":{"always_show_icon":true,"auto'
      'matic_enabled":true},"private_mode":{"welcome_page_enabled":false},"profile":{"block_third_party_cookies":false'
      ',"content_settings":{"exceptions":{},"pref_version":1},"cookie_controls_mode":0,"credentials_with_wrong_signon_'
      'realm_removed":true,"default_content_setting_values":{"crypto_wallet":2},"duplicated_blacklisted_credentials_re'
      'moved":true,"password_manager_onboarding_state":1},"rich_hints":{"marketplace_enabled":false},"rocker_gestures"'
      ':{"enabled":true},"safebrowsing":{"saw_interstitial_sber1":true,"saw_interstitial_sber2":true,"scout_group_sele'
      'cted":true},"search":{"suggest_enabled":false},"search_engines_private":{"opted_in":false},"sessions":{"last_se'
      'ssion_number":"2"},"settings":{"privacy":{"drm_enabled":false}},"speeddial":{"bigger_tiles":false,"disable_anim'
      'ations":true,"hide_plus_button":true,"hide_search_box":true,"hide_suggestions_forced_for_news":true,"imported_t'
      'o_bookmarks":true,"partners":{"guid":"1c78717f-67bf-47e1-970d-aff484b8d806","migration_state":2},"show_suggesti'
      'ons":false,"suggestions":{"guid":"c76e4d23-c45f-4b09-961a-d8e31fdc2b73","next_update":"13500000000000000"}},"sp'
      'ellcheck":{"dictionaries":["ru","en-US","uk"],"dictionary":""},"startpage":{"background_color":"#f5f5f7","dark_'
      'theme_hint_state":2,"navigation_hide_toggle_tooltip_state":2,"news_aggregator":1,"search_engine_suggestion_enab'
      'led":false,"search_engine_suggestion_next_appearance":"1900000000000","search_engine_suggestion_previous_action'
      '":"DISMISSED","search_engine_suggestion_tries":1,"shopping_corner":{"enabled":false},"show_news":false,"show_ne'
      'ws_container":false,"weather":{"enabled":false}},"statistics":{"collection_asked":true,"collection_enabled":fal'
      'se},"sticky_site_in_sidebar":true,"survey":{"next_time":"13500000000000000"},"sync":{"keep_everything_synced":f'
      'alse,"requested":false},"themes":{"custom_wallpapers_enabled":false,"enabled":false,"selected_id":"gx-1-white-w'
      'olf-light"},"translate_site_blacklist_with_time":{},"ui":{"active_theme_id":"bundled/white-wolf","ai_tools":{"e'
      'nabled":false,"prompts":{"address_bar":false,"highlighted_text":false}},"browser":{"sidebar":{"item_prefs":{"vi'
      'sibility":{"Activity":false,"Aria":false,"Bookmarks":true,"ChatGpt":false,"ChatSonic":false,"CryptoWallet":fals'
      'e,"CustomSitePreview":false,"CustomSite_1":false,"CustomSite_2":false,"CustomSite_3":false,"CustomSite_4":false'
      ',"CustomSite_5":false,"Discord":false,"Downloads":true,"Extensions":true,"FacebookMessenger":false,"GamingCorne'
      'r":false,"Instagram":false,"Loomi":false,"Mods":false,"News":true,"OpenAI":false,"OperaTouch":false,"Pinboards"'
      ':false,"Player":false,"Separator":false,"Settings":true,"Shaders":false,"Snap":true,"SpeedDial":true,"Telegram"'
      ':false,"TikTok":false,"Tutorials":false,"Twitter":false,"VKontakte":false,"Whatsapp":false,"Workspace_1":false,'
      '"Workspace_10":false,"Workspace_11":false,"Workspace_12":false,"Workspace_13":false,"Workspace_14":false,"Works'
      'pace_15":false,"Workspace_16":false,"Workspace_17":false,"Workspace_18":false,"Workspace_19":false,"Workspace_2'
      '":false,"Workspace_20":false,"Workspace_21":false,"Workspace_22":false,"Workspace_23":false,"Workspace_24":fals'
      'e,"Workspace_25":false,"Workspace_3":false,"Workspace_4":false,"Workspace_5":false,"Workspace_6":false,"Workspa'
      'ce_7":false,"Workspace_8":false,"Workspace_9":false,"cofphmcjpepfemkcobighilnnmnpodbg":false,"gojhcdgcpbpfigcae'
      'jpfhfegekdgiblk":false,"niedpkpgcoojodjamdaecieijchonfnm":false,"pdcifnciicbfakdajkbbhphlabjminhg":false}},"mon'
      'ochromatic_messenger_icons":true,"notifications_enabled":false,"visible":false,"visible_proxy":0}},"currency_co'
      'nverter":{"currency":"","enabled":false},"dark_skin":false,"dark_skin_settings_proxy":0,"feedback_dialog_enable'
      'd":false,"lazy_session_loading":true,"open_startpage_on_session_restore":true,"scroll_on_active_tab_on_click":f'
      'alse,"search_box_enabled":false,"search_popup_enabled":false,"sharpen_videos":false,"sharpen_videos_overlay_but'
      'ton":false,"show_all_extensions_onboarding_enabled":false,"show_full_url":true,"show_tab_preview":true,"sidebar'
      '_state":{"active_extension":"","panel_size":240,"right_aligned":false,"visible":false},"snap_onboarding_hint_st'
      'ate":3,"snap_onboarding_tools_state":2,"tab_cycling":{"in_activation_order":false},"top_tab_spacing_disabled":t'
      'rue,"top_tab_spacing_disabled_default_enabled":true,"web_feed_finder_enabled":true,"workspaces":{"config":{"ena'
      'bled":false,"id":{"0":true,"1":false},"order":["0"]}},"ybox_expiry":"13500000000000000"},"usage":{"address_bar_'
      'or_search_box_search":"13500000000000000","startpage_configuration_open":"13500000000000000"},"video_popout":{"'
      'enabled":true},"webkit":{"webprefs":{"encrypted_media_enabled":false,"fonts":{"fixed":{"Zyyy":"Lucida Console"}'
      ',"serif":{"Zyyy":"Times New Roman"}},"force_dark_mode_enabled":false}}}'
   ) -join ''

   try {
      # Удаление из preferences информации о блокировке расширения Default Mod, иначе старые версии некоторых редакций падают
      if (
          $Version -le [version]'119.0.5497.88' -and $Settings[1] -eq 0 -or
          $Version -le [version]'119.0.5497.28' -and $Settings[1] -eq 1 -or
          $Version -le [version]'120.0.5516.0'  -and $Settings[1] -eq 2
         )
      {
          $preferencesContent = $preferencesContent -replace ",\x22ffeocbomcpokpmjkkloomhnflpjmkjpi\x22:{\x22blacklist_state\x22:1}",''
      }

      # Настройка списка блокировки встроенных расширений в соответствии с параметрами $BlackList
      $extensionName = $BlackList | %{'(?<='+$_.split()[0]+'\x22:{\x22blacklist_state\x22:)\d'}
      $extensionState = $BlackList | %{$_.split()[-1]}

      for ($i = 0; $i -lt $extensionName.Length; $i++) {
         $preferencesContent = $preferencesContent -replace $extensionName[$i],$extensionState[$i]
      }

      # Создание профиля с папкой Default или без в зависимости от запускаемой версии Оперы
      if ($Version -ge [version]$Settings[0]) {
         [IO.Directory]::CreateDirectory("$profilePath\Default") | Out-Null
         Write-Host " ---> $($profilePath.Split('\')[-1])\Default"
         $preferences = Join-Path "$profilePath\Default" "Preferences"
      } else {
         [IO.Directory]::CreateDirectory($profilePath) | Out-Null
         Write-Host " ---> $($profilePath.Split('\')[-1])"
         $preferences = Join-Path $profilePath "Preferences"
      }

      # Сохранение данных Preferences и Local State в кодировке UTF-8 без BOM и без новой строки в конце
      [System.IO.File]::WriteAllText($preferences, $preferencesContent, (New-Object System.Text.UTF8Encoding $false))
      Write-Host " ---> $($profilePath.Split('\')[-1])\$($preferences.Replace("$profilePath\",''))"

      # Вставка текущей версии Оперы в Local State, чтобы не открывалась страница обновления
      $localStateContent = $localStateContent -replace '0,0,0,0',$("$version".Replace('.',','))
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

Write-Host                   "Initialize variables..."
Write-Host                   "Script:    $scriptName"  @darkcyan
Write-Host                   "App:       $AppPath"     @darkcyan
Write-Host                   "Browser:   $BrowserName" @darkcyan
if ($UseProxy) {Write-Host   "Proxy:     $ProxyPath"   @darkcyan}
Write-Host                   "Profile:   $profilePath" @darkcyan
if ($cachePath) {Write-Host  "Cache:     $cachePath"   @darkcyan}
if ($7zpath) {Write-Host     "7z:        $7zpath"      @darkcyan}
if ($DllPath) {Write-Host    "Dll:       $DllPath"     @darkcyan}
if ($SetDllPath) {Write-Host "SetDll:    $SetDllPath"  @darkcyan}
Write-Host                   "Mutex:     $MutexName"   @darkcyan

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
   try {
      $exeInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$AppPath\$ExeName")
      if (-not $exeInfo) {throw}
   } catch {
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

   # Версии и редакции Оперы, ниже которых профиль не имел папки Default
   $defaultMinVer = switch -Wildcard ($exeInfo.FileDescription) {
     '*beta*'{'102.0.4880.10',1}
     '*dev*' {'102.0.4850.0',2}
     '*gx*'  {'121.0.5600.41',3}
     '*air*' {'116.0.5366.171',4} 
     default {'102.0.4880.16',0}
   }

   if ([IO.Directory]::Exists($profilePath)) {
   #  Попытка совместить несовместимые версию и профиль
      if ($exeInfo.ProductVersionRaw -ge [version]$defaultMinVer[0] -and -not [IO.Directory]::Exists("$profilePath\Default")) {

         try {
            [IO.Directory]::CreateDirectory("$profilePath\Default") | Out-Null
            Write-Host "Create folder $profilePath\Default: OK" @green
            Get-Item "$profilePath\*" -Exclude 'Default','Local State' | Move-Item -Destination "$profilePath\Default" -Force -ea 1
            Write-Host "Move all from $profilePath to $profilePath\Default: OK" @green
            $changeProfile = $true
         } catch {Write-Host "$_.Exception.Message" @red; $errprofile = $true}

      } elseif ($exeInfo.ProductVersionRaw -lt [version]$defaultMinVer[0] -and [IO.Directory]::Exists("$profilePath\Default")) {

         Show-Balloon -Message "The profile is not compatible with this browser version" -MessageType "Warning"
         Write-Host "Version $($exeInfo.ProductVersion) NOT use Default folder"
         try {
            Move-Item -Path "$profilePath\Default\*" -Destination "$profilePath" -Force -ea 1
            Write-Host "Move all from $profilePath\Default to $($profilePath): OK" @green
            $changeProfile = $true
         }
         catch {Write-Host "$_.Exception.Message" @red; $errprofile = $true}
         try {
            Remove-Item -Path "$profilePath\Default" -Recurse -Force -ErrorAction Stop
            Write-Host "Remove $profilePath\Default folder: OK" @green
            $changeProfile = $true
         }
         catch {Write-Host "$_.Exception.Message" @red; $errprofile = $true}
      }

   #  В Local State ставится текущая версия Оперы, чтобы не открывалась страница обновления
      if ([IO.File]::Exists("$profilePath\Local State")) {
         $ls = "$profilePath\Local State"
         $lastVersion = '(?<=\x22last_version\x22:\[)\d+,\d+,\d+,\d+'
         $currentVersion = $($exeinfo.ProductVersion).Replace('.',',')
         $oldLS = Get-Content -LiteralPath $ls -Encoding UTF8
         if ($oldLS -notmatch $currentVersion) {
            $newLS = $oldLS -replace $lastVersion,$currentVersion
            try {
               [System.IO.File]::WriteAllText($ls, $newLS, (New-Object System.Text.UTF8Encoding $false))
               $changeProfile = $true
            } catch {Write-Host "$_.Exception.Message" @red; $errprofile = $true}
         }
      }
      if ($changeProfile -and -not $errprofile) {Write-Host "Profile tuned: OK" @green}
   } else {
   # Создание нового профиля с параметрами для данной версии Оперы
      Create-Profile -Version $exeInfo.ProductVersionRaw -Settings $defaultMinVer
   }

   # Настройка ini
   try {if (-not (Check-IniFile -Dlldescr $dllInfo)) {Write-Host "Not changed $baseini"}}
   catch {throw "Error tuned $($baseini): $_"}

   # Заглушки и файлы настроек
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

   if (-not [IO.File]::Exists("$AppPath\installation_status.json")) {
       $isContent = @(
          '{"_all_users":false,"copy_only":true,"files":[""],"path":"","product":"Opera","registry":{},"root_files":[],"version":""}'
       )
       $is = Join-Path $AppPath "installation_status.json"
       try {
          [System.IO.File]::WriteAllText($is, $isContent, (New-Object System.Text.UTF8Encoding $false))
          Write-Host "Create file $AppDir\installation_status.json: OK" @green
       }
       catch {Write-Host "$_.Exception.Message" @red}
   }

   if (-not [IO.File]::Exists("$AppPath\installer_prefs.json")) {
       $ipContent = @('{"language":"ru","single_profile":true}')
       $ip = Join-Path $AppPath "installer_prefs.json"
       try {
          [System.IO.File]::WriteAllText($ip, $ipContent, (New-Object System.Text.UTF8Encoding $false))
          Write-Host "Create file $AppDir\installer_prefs.json: OK" @green
       }
       catch {Write-Host "$_.Exception.Message" @red}
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
      if ($exeInfo.ProductVersionRaw -lt [version]$defaultMinVer[0]) {
         $DelDirs = $DelDirs -replace 'Default\\',''
         $DelFiles = $DelFiles -replace 'Default\\',''
      }
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
