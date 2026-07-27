<# :
:: Скрипт с нуля создает портабельную автообновляемую сборку браузера Ungoogled Chromium и далее работает как запускатель.
:: Проверяет обновления с заданным интервалом, после закрытия чистит профиль и реестр.
:: Для работы достаточно поместить батник в любую пустую папку (кроме корневых, системных и с ограниченным доступом) и запустить.
:: Сразу качается актуальная версия, распаковывается в папку рядом с батником и запускается браузер.
:: Обновления качаются с официального сайта в подпапку папки батника и после установки удаляются.
:: Будет скачиваться каждая новая сборка от Macchrome, даже если версия Ungoogled остается без изменений.
:: Портабельность обеспечивается ключами запуска --disable-machine-id, --disable-encryption.
:: Для проверки/скачивания обновлений и для браузера можно использовать opera-proxy (https://github.com/Alexey71/opera-proxy),
:: который будет скачан и запущен с заданными параметрами, при выходе новых версий будет автообновляться.
:: Если указать свой профиль в ключе --user-data-dir, то подхватится он, иначе создается новый
:: с преднастройками от Insorg (https://forum.ru-board.com/topic.cgi?forum=2&bm=1&topic=5915&start=60#1).
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
$RunMode = 0 # 0 - обычный режим, 1 - только запуск, 2 - только проверка/установка обновлений
$CreateShortcut = $false # создать ярлык на рабочем столе
$AskUpdate = $true # перед обновлением спрашивать
$Backup = $false # при обновлении создавать в папке батника zip-бэкап профиля
$MakeStub = $false # создавать взамен удаляемых в профиле папок ($DelDirs) файлы-заглушки нулевого размера
$AppDir = "App" # папка сборки, создается рядом со скриптом
$7zpath = "" # локальный путь к 7zr.exe или 7z.exe, если оставить пустым, будет скачан с github.com
$UseProxy = 0 # 0 - не включать, 1 - только для браузера, 2 - для браузера и для проверки/закачки обновлений
$ProxyPath = "" # путь к файлу опера прокси, если оставить пустым, будет скачан с github.com (при $UseProxy <> 0)
$ProxyArg = "-bind-address 127.0.0.1:18088","-verbosity 30","-country AM" # параметры прокси
$ShowConsole = $false # показывать консоль при старте для контроля ошибок

$Switches = @( # список ключей запуска браузера
   "--user-data-dir=`"..\Profile`"" # Имя/путь каталога пользовательских данных
   "--disable-machine-id" # Отключает использование сгенерированного идентификатора, специфичного для компьютера, для блокировки каталога пользовательских данных на этом компьютере. Это используется для включения переносимых каталогов пользовательских данных (делает браузер портабельным)
   "--disable-encryption" # Отключает шифрование файлов cookie, паролей и настроек, которое использует сгенерированный ключ шифрования для конкретного компьютера. Это используется для включения переносимых каталогов пользовательских данных (делает браузер портабельным)
   "--disable-encryption-win" # То же, что и предыдущий
   "--no-default-browser-check" # Отключает проверку браузера по умолчанию
#   "--disk-cache-dir=nul" # Определяет каталог дискового кэша (значение nul - не кэшировать)
#   "--disable-gpu-shader-disk-cache" # Отключает кэширование на диске шейдеров GPU
#   "--gpu-disk-cache-size-kb=1" # Определяет размер GPU кэша в килобайатах
#   "--disk-cache-size=1" # Определяет размер дискового кэша в килобайатах
   "--disable-search-engine-collection" # Отключает автоматическое сканирование веб-страниц поисковыми системами
   "--disable-sharing-hub" # Отключает кнопку центра общего доступа
   "--hide-sidepanel-button" # Скрывает кнопку боковой панели
   "--remove-tabsearch-button" # Удаляет кнопку поиска вкладок из панели вкладок
   "--remove-grab-handle" # Удаляет зарезервированное пустое пространство в полосе вкладок для перемещения окна
   "--scroll-tabs=always" # Определяет, вызовет ли прокрутка переключение на соседнюю вкладку, если курсор наведен на вкладки, или на пустое пространство рядом с вкладками. Флаг требует одного из значений: always, never, incognito-and-guest. Если этот параметр опущен, по умолчанию используется поведение, зависящее от платформы, которое в настоящее время включено только в настольной Linux
   "--popups-to-tabs" # Позволяет всплывающим окнам открываться в новых вкладках
   "--close-window-with-last-tab=never" # Определяет, должно ли окно закрываться после закрытия последней вкладки. Принимает только значение never.
   "--show-avatar-button=never" # Устанавливает видимость кнопки аватара. Для флага требуется одно из значений: always, incognito-and-guest (показывать только режимы инкогнито или гостевой) или never
   "--tab-hover-cards=tooltip" # Позволяет удалить всплывающие миниатюры при наведении на вкладку или использовать всплывающую подсказку в качестве замены. Это можно установить с помощью значений none или tooltip
   "--extension-mime-request-handling=always-prompt-for-install" # Изменяет способ обработки типов расширения MIME (CRX и пользовательские сценарии). Допустимые значения: download-as-regular-file или always-prompt-for-install. Если вообще не использовать, то будет нормальное поведение
   "--enable-features=#enable-parallel-downloading" # Разрешает одновременную закгрузку нескольких файлов
   "--force-punycode-hostnames" # Преобразует все интернационализированные доменные имена в punycode (ASCII-представление Unicode)
   "--proxy-server=$(($ProxyArg -Split " ")[1])" # IP адрес и порт локального прокси-сервера. В данном случае - тот, что прописан выше в переменной $ProxyArg
   "--disable-features=PrintCompositorLPAC" # Исправляет ошибку предварительного просмотра печати
   "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled" # Поддержка устаревших расширений
   "--no-first-run"
#   "--disable-beforeunload" # Отключает диалоговые окна JavaScript, запускаемые перед выгрузкой JS модуля/скрипта
#   "--disable-grease-tls" # Отключает GREASE для TLS. В сочетании с --http-accept-header позволяет браузеру больше походить на tor-браузер
#   "--fingerprinting-canvas-image-data-noise" # Реализует обман при снятии отпечатков пальцев для данных изображения Canvas, полученных через API JS. В данных не более 10 пикселей слегка изменены
#   "--fingerprinting-canvas-measuretext-noise" # Масштабирует выходные значения Canvas::measureText() со случайно выбранным коэффициентом в диапазоне от -0,0003% до 0,0003%, который пересчитывается при каждой инициализации документа
#   "--fingerprinting-client-rects-noise" # Реализует обман API JS с помощью отпечатков пальцев getClientRects() и getBoundingClientRect(), масштабирует их выходные значения со случайным коэффициентом в диапазоне от -0,0003% до 0,0003%, которые пересчитываются для каждого экземпляра документа
#   "--hide-crashed-bubble" # Скрывает всплывающее окно с сообщением «Восстановить страницы? Chromium завершил работу неправильно». Это отображается при запуске после того, как браузер не завершил работу корректно
#   "--http-accept-header" # Изменяет значение по умолчанию AcceptHTTP-заголовка, отправляемого с HTTP-запросами. В сочетании с --disable-grease-tls позволяет браузеру больше походить на tor-браузер
#   "--keep-old-history" # Отключает удаление локальной истории браузера через 90 дней
#   "--max-connections-per-host" # Настроить максимально допустимое количество подключений на хост. Допустимые значения: 6 и 15
#   "--omnibox-autocomplete-filtering" # Ограничивает результаты автозаполнения омнибокса комбинацией поисковых предложений (если они включены), закладок и внутренних страниц Chrome. Принимает значения: search, search-bookmarks, search-chrome, и search-bookmarks-chrome
#   "--bookmark-bar-ntp" # Устанавливает видимость панели закладок на странице новой вкладки. Принимает только значение never.
#   "--close-confirmation" # Показывать предупреждение при закрытии окна браузера. Принимает значения: last (запрос при закрытии последнего окна с несколькими вкладками) и multiple (запрос только если открыто более одного окна)
#   "--custom-ntp" # Позволяет установить собственный URL-адрес для страницы новой вкладки. Значение может быть внутренним (например, about:blank или chrome://new-tab-page), внешним (например example.com) или локальным (например, file:///tmp/startpage.html). Это относится и к окнам в режиме инкогнито, если не установлено значение chrome:// внутренней страницы
#   "--enable-incognito-themes" # Позволяет темам изменять внешний вид окон в режиме инкогнито
#   "--hide-extensions-menu" # Скрывает контейнер расширений. Сюда входит значок головоломки, а также любые закрепленные расширения
#   "--hide-fullscreen-exit-ui" # Скрывает значок «X», который появляется, когда курсор мыши перемещается к верхней части окна в полноэкранном режиме. Кроме того, это скрывает всплывающее окно «Нажмите F11, чтобы выйти из полноэкранного режима»
#   "--hide-tab-close-buttons" # Скрывает кнопки закрытия на вкладках
#   "--enable-features=MinimalReferrers" # Удаляет все рефереры перекрестного происхождения и разделяет рефереры одного и того же происхождения до источника. Имеет более низкий приоритет, чем NoCrossOriginReferrers
#   "--enable-features=NoCrossOriginReferrers" # Удаляет все рефереры из перекрестного источника. Имеет более низкий приоритет, чем NoReferrers
#   "--enable-features=NoReferrers" # Удаляет все рефереры
#   "--enable-features=SetIpv6ProbeFalse" # Принудительно делает результат проверки IPv6 браузера (т. е. проверки подключения IPv6) неуспешным. Это приводит к тому, что адреса IPv4 имеют приоритет над адресами IPv6. Без этого флага результат проверки считается успешным, что приводит к использованию IPv6 вместо IPv4, когда это возможно
#   "--enable-features=ClearDataOnExit" # Очищает все данные просмотра при выходе
#   "--enable-features=DisableLinkDrag" # Предотвращает перетаскивание ссылок и выделенного текста. Позволяет выделить текст из середины ссылки. Также позволяет начать выбор без предварительной очистки существующего. Это поведение похоже на поведение старой Opera
#   "--enable-features=DisableQRGenerator" # Отключает QR-генератор для обмена ссылками на страницы
#   "--disable-top-sites" # Отключает самые популярные сайты и наиболее посещаемые записи на странице новой вкладки
#   "--disable-webgl" # Отключает все версии WebGL
#   "--enable-low-end-device-mode" # Принудительно использовать режим нижнего уровня устройства, если он установлен
#   "--force-dark-mode" # Включает темный режим в пользовательском интерфейсе для платформ, которые его поддерживают
#   "--no-pings" # Не отправлять пинг-запросы проверки гиперссылок
#   "--webrtc-ip-handling-policy" # Ограничить IP-адреса и интерфейсы, которые использует WebRTC
#   "--incognito" # Старт браузера в режиме инкогнито
#   "--start-maximized" # Запускает браузер в развернутом виде независимо от любых предыдущих настроек
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
#  Работа браузера во многом ломается, раскомментируйте, если приватность важнее потери данных
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

$Trash = @( # папки и файлы вне профиля, подлежащие удалению после закрытия браузера
#   "$env:TEMP\*.tmp"
)

# ============================================================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
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
      if (-not (Download-File -Source $distrLink -Dest "$tmpdir\ungoogled.7z" -Text $Latest -Pbar $true)) {throw}
      Write-Host "Download installer: OK" @green

      # 7-Zip
      if (-not [IO.File]::Exists("$7zpath")) {
          $7zpath = "$tmpdir\7zr.exe"
          if (-not (Download-File -Source "https://github.com/ip7z/7zip/releases/latest/download/7zr.exe" -Dest $7zpath)) {throw}
          Write-Host "Download 7-zip: OK" @green
      }

      Show-Balloon -Message "Unpack and copy files..."

      # Распаковка
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

# Новый профиль
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

      # Сохранение данных Preferences и Local State в кодировке UTF-8 без BOM и без новой строки в конце
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

# Удаление хлама после закрытия браузера
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
if ($7zpath) {Write-Host    "7z:        $7zpath"      @darkcyan}
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

   # Создание нового профиля
   if (-not [IO.Directory]::Exists($profilePath)) {Create-Profile}

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
