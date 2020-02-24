import tables, httpcore, sequtils

type
  CommandEndpointTuple* = tuple[httpMethod: HttpMethod, endpoint: string]
  CommandTable* = Table[Command, CommandEndpointTuple]
  Command* {.pure.} = enum
    Status = "status"
    NewSession = "newSession"
    GetAllSessions = "getAllSessions"
    DeleteSession = "deleteSession"
    NewWindow = "newWindow"
    Close = "close"
    Quit = "quit"
    Get = "get"
    GoBack = "goBack"
    GoForward = "goForward"
    Refresh = "refresh"
    AddCookie = "addCookie"
    GetCookie = "getCookie"
    GetAllCookies = "getCookies"
    DeleteCookie = "deleteCookie"
    DeleteAllCookies = "deleteAllCookies"
    FindElement = "findElement"
    FindElements = "findElements"
    FindChildElement = "findChildElement"
    FindChildElements = "findChildElements"
    ClearElement = "clearElement"
    ClickElement = "clickElement"
    SendKeysToElement = "sendKeysToElement"
    SendKeysToActiveElement = "sendKeysToActiveElement"
    SubmitElement = "submitElement"
    UploadFile = "uploadFile"
    GetCurrentWindowHandle = "getCurrentWindowHandle"
    W3CgetCurrentWindowHandle = "w3cGetCurrentWindowHandle"
    GetWindowHandles = "getWindowHandles"
    W3CgetWindowHandles = "w3cGetWindowHandles"
    GetWindowSize = "getWindowSize"
    W3CgetWindowSize = "w3cGetWindowSize"
    W3CgetWindowPosition = "w3cGetWindowPosition"
    GetWindowPosition = "getWindowPosition"
    SetWindowSize = "setWindowSize"
    W3CsetWindowSize = "w3cSetWindowSize"
    SetWindowRect = "setWindowRect"
    GetWindowRect = "getWindowRect"
    SetWindowPosition = "setWindowPosition"
    W3CsetWindowPosition = "w3cSetWindowPosition"
    SwitchToWindow = "switchToWindow"
    SwitchToFrame = "switchToFrame"
    SwitchToParentFrame = "switchToParentFrame"
    GetActiveElement = "getActiveElement"
    W3CgetActiveElement = "w3cGetActiveElement"
    GetCurrentUrl = "getCurrentUrl"
    GetPageSource = "getPageSource"
    GetTitle = "getTitle"
    ExecuteScript = "executeScript"
    W3CexecuteScript = "w3cExecuteScript"
    W3CexecuteScriptAsync = "w3cExecuteScriptAsync"
    GetElementText = "getElementText"
    GetElementValue = "getElementValue"
    GetElementTagName = "getElementTagName"
    SetElementSelected = "setElementSelected"
    IsElementSelected = "isElementSelected"
    IsElementEnabled = "isElementEnabled"
    IsElementDisplayed = "isElementDisplayed"
    GetElementLocation = "getElementLocation"
    GetElementLocationOnceScrolledIntoView = "getElementLocationOnceScrolledIntoView"
    GetElementSize = "getElementSize"
    GetElementRect = "getElementRect"
    GetElementAttribute = "getElementAttribute"
    GetElementProperty = "getElementProperty"
    GetElementValueOfCssProperty = "getElementValueOfCssProperty"
    Screenshot = "screenshot"
    ElementScreenshot = "elementScreenshot"
    ImplicitWait = "implicitlyWait"
    ExecuteAsyncScript = "executeAsyncScript"
    SetScriptTimeout = "setScriptTimeout"
    SetTimeouts = "setTimeouts"
    MaximizeWindow = "windowMaximize"
    W3CmaximizeWindow = "w3cMaximizeWindow"
    GetLog = "getLog"
    GetAvailableLogTypes = "getAvailableLogTypes"
    FullscreenWindow = "fullscreenWindow"
    MinimizeWindow = "minimizeWindow"

    # Alerts
    DismissAlert = "dismissAlert"
    W3CdismissAlert = "w3cDismissAlert"
    AcceptAlert = "acceptAlert"
    W3CacceptAlert = "w3cAcceptAlert"
    SetAlertValue = "setAlertValue"
    W3CsetAlertValue = "w3cSetAlertValue"
    GetAlertText = "getAlertText"
    W3CgetAlertText = "w3cGetAlertText"
    SetAlertCredentials = "setAlertCredentials"

    # Advanced user interactions
    W3Cactions = "actions"
    W3CclearActions = "clearActionState"
    Click = "mouseClick"
    DoubleClick = "mouseDoubleClick"
    MouseDown = "mouseButtonDown"
    MouseUp = "mouseButtonUp"
    MoveTo = "mouseMoveTo"

    # Screen Orientation
    SetScreenOrientation = "setScreenOrientation"
    GetScreenOrientation = "getScreenOrientation"

    # Touch Actions
    SingleTap = "touchSingleTap"
    TouchDown = "touchDown"
    TouchUp = "touchUp"
    TouchMove = "touchMove"
    TouchScroll = "touchScroll"
    DoubleTap = "touchDoubleTap"
    LongPress = "touchLongPress"
    Flick = "touchFlick"

    # Html 5
    ExecuteSql = "executeSql"

    GetLocation = "getLocation"
    SetLocation = "setLocation"

    GetAppCache = "getAppCache"
    GetAppCacheStatus = "getAppCacheStatus"
    ClearAppCache = "clearAppCache"

    GetLocalStorageItem = "getLocalStorageItem"
    RemoveLocalStorageItem = "removeLocalStorageItem"
    GetLocalStorageKeys = "getLocalStorageKeys"
    SetLocalStorageItem = "setLocalStorageItem"
    ClearLocalStorage = "clearLocalStorage"
    GetLocalStorageSize = "getLocalStorageSize"

    GetSessionStorageItem = "getSessionStorageItem"
    RemoveSessionStorageItem = "removeSessionStorageItem"
    GetSessionStorageKeys = "getSessionStorageKeys"
    SetSessionStorageItem = "setSessionStorageItem"
    ClearSessionStorage = "clearSessionStorage"
    GetSessionStorageSize = "getSessionStorageSize"

    # Mobile
    GetNetworkConnection = "getNetworkConnection"
    SetNetworkConnection = "setNetworkConnection"
    CurrentContextHandle = "getCurrentContextHandle"
    ContextHandles = "getContextHandles"
    SwitchToContext = "switchToContext"

    # Firefox
    GetContext = "GET_CONTEXT"
    SetContext = "SET_CONTEXT"
    ElementGetAnonymousChildren = "ELEMENT_GET_ANONYMOUS_CHILDREN"
    ElementFindAnonymousElementsByAttribute = "ELEMENT_FIND_ANONYMOUS_ELEMENTS_BY_ATTRIBUTE"
    InstallAddon = "INSTALL_ADDON"
    UninstallAddon = "UNINSTALL_ADDON"
    FullPageScreenshot = "FULL_PAGE_SCREENSHOT"

    # Safari
    GetPermissions = "GET_PERMISSIONS"
    SetPermissions = "SET_PERMISSIONS"
    AttachDebugger = "ATTACH_DEBUGGER"

    # Chromium / Chrome
    LaunchApp = "launchApp"
    SetNetworkConditions = "setNetworkConditions"
    GetNetworkConditions = "getNetworkConditions"
    ExecuteCdpCommand = "executeCdpCommand"
    GetSinks = "getSinks"
    GetIssueMessage = "getIssueMessage"
    SetSinkToUse = "setSinkToUse"
    StartTabMirroring = "startTabMirroring"
    StopCasting = "stopCasting"

const sessionIdPath = "/session/$sessionId"
const elementIdPath = "/element/$id"
const windowHandlePath = "/window/$windowHandle"

const BasicCommands = @{
  Command.Status: (HttpGet, "/status"),
  Command.NewSession: (HttpPost, "/session"),
  Command.GetAllSessions: (HttpGet, "/sessions"),
  Command.Quit: (HttpDelete, sessionIdPath),
  Command.GetCurrentWindowHandle: (HttpGet, sessionIdPath & "/window_handle"),
  Command.W3CGetCurrentWindowHandle: (HttpGet, sessionIdPath & "/window"),
  Command.GetWindowHandles: (HttpGet, sessionIdPath & "/window_handles"),
  Command.W3CGetWindowHandles: (HttpGet, sessionIdPath & "/window/handles"),
  Command.Get: (HttpPost, sessionIdPath & "/url"),
  Command.GoForward: (HttpPost, sessionIdPath & "/forward"),
  Command.GoBack: (HttpPost, sessionIdPath & "/back"),
  Command.Refresh: (HttpPost, sessionIdPath & "/refresh"),
  Command.ExecuteScript: (HttpPost, sessionIdPath & "/execute"),
  Command.W3CExecuteScript: (HttpPost, sessionIdPath & "/execute/sync"),
  Command.W3CExecuteScriptAsync: (HttpPost, sessionIdPath & "/execute/async"),
  Command.GetCurrentUrl: (HttpGet, sessionIdPath & "/url"),
  Command.GetTitle: (HttpGet, sessionIdPath & "/title"),
  Command.GetPageSource: (HttpGet, sessionIdPath & "/source"),
  Command.Screenshot: (HttpGet, sessionIdPath & "/screenshot"),
  Command.ElementScreenshot: (HttpGet, sessionIdPath & elementIdPath & "/screenshot"),
  Command.FindElement: (HttpPost, sessionIdPath & "/element"),
  Command.FindElements: (HttpPost, sessionIdPath & "/elements"),
  Command.W3CGetActiveElement: (HttpGet, sessionIdPath & "/element/active"),
  Command.GetActiveElement: (HttpPost, sessionIdPath & "/element/active"),
  Command.FindChildElement: (HttpPost, sessionIdPath & elementIdPath & "/element"),
  Command.FindChildElements: (HttpPost, sessionIdPath & elementIdPath & "/elements"),
  Command.ClickElement: (HttpPost, sessionIdPath & elementIdPath & "/click"),
  Command.ClearElement: (HttpPost, sessionIdPath & elementIdPath & "/clear"),
  Command.SubmitElement: (HttpPost, sessionIdPath & elementIdPath & "/submit"),
  Command.GetElementText: (HttpGet, sessionIdPath & elementIdPath & "/text"),
  Command.SendKeysToElement: (HttpPost, sessionIdPath & elementIdPath & "/value"),
  Command.SendKeysToActiveElement: (HttpPost, sessionIdPath & "/keys"),
  Command.UploadFile: (HttpPost, sessionIdPath & "/file"),
  Command.GetElementValue: (HttpGet, sessionIdPath & elementIdPath & "/value"),
  Command.GetElementTagName: (HttpGet, sessionIdPath & elementIdPath & "/name"),
  Command.IsElementSelected: (HttpGet, sessionIdPath & elementIdPath & "/selected"),
  Command.SetElementSelected: (HttpPost, sessionIdPath & elementIdPath & "/selected"),
  Command.IsElementEnabled: (HttpGet, sessionIdPath & elementIdPath & "/enabled"),
  Command.IsElementDisplayed: (HttpGet, sessionIdPath & elementIdPath & "/displayed"),
  Command.GetElementLocation: (HttpGet, sessionIdPath & elementIdPath & "/location"),
  Command.GetElementLocationOnceScrolledIntoView: (HttpGet, sessionIdPath & elementIdPath & "/location_in_view"),
  Command.GetElementSize: (HttpGet, sessionIdPath & elementIdPath & "/size"),
  Command.GetElementRect: (HttpGet, sessionIdPath & elementIdPath & "/rect"),
  Command.GetElementAttribute: (HttpGet, sessionIdPath & elementIdPath & "/attribute/$name"),
  Command.GetElementProperty: (HttpGet, sessionIdPath & elementIdPath & "/property/$name"),
  Command.GetAllCookies: (HttpGet, sessionIdPath & "/cookie"),
  Command.AddCookie: (HttpPost, sessionIdPath & "/cookie"),
  Command.GetCookie: (HttpGet, sessionIdPath & "/cookie/$name"),
  Command.DeleteAllCookies: (HttpDelete, sessionIdPath & "/cookie"),
  Command.DeleteCookie: (HttpDelete, sessionIdPath & "/cookie/$name"),
  Command.SwitchToFrame: (HttpPost, sessionIdPath & "/frame"),
  Command.SwitchToParentFrame: (HttpPost, sessionIdPath & "/frame/parent"),
  Command.SwitchToWindow: (HttpPost, sessionIdPath & "/window"),
  Command.NewWindow: (HttpPost, sessionIdPath & "/window/new"),
  Command.Close: (HttpDelete, sessionIdPath & "/window"),
  Command.GetElementValueOfCssProperty: (HttpGet, sessionIdPath & elementIdPath & "/css/$propertyName"),
  Command.ImplicitWait: (HttpPost, sessionIdPath & "/timeouts/implicit_wait"),
  Command.ExecuteAsyncScript: (HttpPost, sessionIdPath & "/execute_async"),
  Command.SetScriptTimeout: (HttpPost, sessionIdPath & "/timeouts/async_script"),
  Command.SetTimeouts: (HttpPost, sessionIdPath & "/timeouts"),
  Command.DismissAlert: (HttpPost, sessionIdPath & "/dismiss_alert"),
  Command.W3CDismissAlert: (HttpPost, sessionIdPath & "/alert/dismiss"),
  Command.AcceptAlert: (HttpPost, sessionIdPath & "/accept_alert"),
  Command.W3CAcceptAlert: (HttpPost, sessionIdPath & "/alert/accept"),
  Command.SetAlertValue: (HttpPost, sessionIdPath & "/alert_text"),
  Command.W3CSetAlertValue: (HttpPost, sessionIdPath & "/alert/text"),
  Command.GetAlertText: (HttpGet, sessionIdPath & "/alert_text"),
  Command.W3CGetAlertText: (HttpGet, sessionIdPath & "/alert/text"),
  Command.SetAlertCredentials: (HttpPost, sessionIdPath & "/alert/credentials"),
  Command.Click: (HttpPost, sessionIdPath & "/click"),
  Command.W3CActions: (HttpPost, sessionIdPath & "/actions"),
  Command.W3CClearActions: (HttpDelete, sessionIdPath & "/actions"),
  Command.DoubleClick: (HttpPost, sessionIdPath & "/doubleclick"),
  Command.MouseDown: (HttpPost, sessionIdPath & "/buttondown"),
  Command.MouseUp: (HttpPost, sessionIdPath & "/buttonup"),
  Command.MoveTo: (HttpPost, sessionIdPath & "/moveto"),
  Command.GetWindowSize: (HttpGet, sessionIdPath & windowHandlePath & "/size"),
  Command.SetWindowSize: (HttpPost, sessionIdPath & windowHandlePath & "/size"),
  Command.GetWindowPosition: (HttpGet, sessionIdPath & windowHandlePath & "/position"),
  Command.SetWindowPosition: (HttpPost, sessionIdPath & windowHandlePath & "/position"),
  Command.SetWindowRect: (HttpPost, sessionIdPath & "/window/rect"),
  Command.GetWindowRect: (HttpGet, sessionIdPath & "/window/rect"),
  Command.MaximizeWindow: (HttpPost, sessionIdPath & windowHandlePath & "/maximize"),
  Command.W3CMaximizeWindow: (HttpPost, sessionIdPath & "/window/maximize"),
  Command.SetScreenOrientation: (HttpPost, sessionIdPath & "/orientation"),
  Command.GetScreenOrientation: (HttpGet, sessionIdPath & "/orientation"),
  Command.SingleTap: (HttpPost, sessionIdPath & "/touch/click"),
  Command.TouchDown: (HttpPost, sessionIdPath & "/touch/down"),
  Command.TouchUp: (HttpPost, sessionIdPath & "/touch/up"),
  Command.TouchMove: (HttpPost, sessionIdPath & "/touch/move"),
  Command.TouchScroll: (HttpPost, sessionIdPath & "/touch/scroll"),
  Command.DoubleTap: (HttpPost, sessionIdPath & "/touch/doubleclick"),
  Command.LongPress: (HttpPost, sessionIdPath & "/touch/longclick"),
  Command.Flick: (HttpPost, sessionIdPath & "/touch/flick"),
  Command.ExecuteSql: (HttpPost, sessionIdPath & "/execute_sql"),
  Command.GetLocation: (HttpGet, sessionIdPath & "/location"),
  Command.SetLocation: (HttpPost, sessionIdPath & "/location"),
  Command.GetAppCache: (HttpGet, sessionIdPath & "/application_cache"),
  Command.GetAppCacheStatus: (HttpGet, sessionIdPath & "/application_cache/status"),
  Command.ClearAppCache: (HttpDelete, sessionIdPath & "/application_cache/clear"),
  Command.GetNetworkConnection: (HttpGet, sessionIdPath & "/network_connection"),
  Command.SetNetworkConnection: (HttpPost, sessionIdPath & "/network_connection"),
  Command.GetLocalStorageItem: (HttpGet, sessionIdPath & "/local_storage/key/$key"),
  Command.RemoveLocalStorageItem: (HttpDelete, sessionIdPath & "/local_storage/key/$key"),
  Command.GetLocalStorageKeys: (HttpGet, sessionIdPath & "/local_storage"),
  Command.SetLocalStorageItem: (HttpPost, sessionIdPath & "/local_storage"),
  Command.ClearLocalStorage: (HttpDelete, sessionIdPath & "/local_storage"),
  Command.GetLocalStorageSize: (HttpGet, sessionIdPath & "/local_storage/size"),
  Command.GetSessionStorageItem: (HttpGet, sessionIdPath & "/session_storage/key/$key"),
  Command.RemoveSessionStorageItem: (HttpDelete, sessionIdPath & "/session_storage/key/$key"),
  Command.GetSessionStorageKeys: (HttpGet, sessionIdPath & "/session_storage"),
  Command.SetSessionStorageItem: (HttpPost, sessionIdPath & "/session_storage"),
  Command.ClearSessionStorage: (HttpDelete, sessionIdPath & "/session_storage"),
  Command.GetSessionStorageSize: (HttpGet, sessionIdPath & "/session_storage/size"),
  Command.GetLog: (HttpPost, sessionIdPath & "/se/log"),
  Command.GetAvailableLogTypes: (HttpGet, sessionIdPath & "/se/log/types"),
  Command.CurrentContextHandle: (HttpGet, sessionIdPath & "/context"),
  Command.ContextHandles: (HttpGet, sessionIdPath & "/contexts"),
  Command.SwitchToContext: (HttpPost, sessionIdPath & "/context"),
  Command.FullscreenWindow: (HttpPost, sessionIdPath & "/window/fullscreen"),
  Command.MinimizeWindow: (HttpPost, sessionIdPath & "/window/minimize")
}

const FirefoxCommands = BasicCommands.concat(
  @{
    Command.GetContext: (HttpGet, sessionIdPath & "/moz/context"),
    Command.SetContext: (HttpPost, sessionIdPath & "/moz/context"),
    Command.ElementGetAnonymousChildren: (HttpPost, sessionIdPath & "/moz/xbl/$id/anonymous_children"),
    Command.ElementFindAnonymousElementsByAttribute: (HttpPost, sessionIdPath & "/moz/xbl/$id/anonymous_by_attribute"),
    Command.InstallAddon: (HttpPost, sessionIdPath & "/moz/addon/install"),
    Command.UninstallAddon: (HttpPost, sessionIdPath & "/moz/addon/uninstall"),
    Command.FullPageScreenshot: (HttpGet, sessionIdPath & "/moz/screenshot/full")
  }
)

const SafariCommands = BasicCommands.concat(
  @{
    Command.GetPermissions: (HttpGet, sessionIdPath & "/apple/permissions"),
    Command.SetPermissions: (HttpPost, sessionIdPath & "/apple/permissions"),
    Command.AttachDebugger: (HttpPost, sessionIdPath & "/apple/attach_debugger")
  }
)

const ChromiumCommands = BasicCommands.concat(
  @{
    Command.LaunchApp: (HttpPost, sessionIdPath & "/chromium/launch_app"),
    Command.SetNetworkConditions: (HttpPost, sessionIdPath & "/chromium/network_conditions"),
    Command.GetNetworkConditions: (HttpGet, sessionIdPath & "/chromium/network_conditions"),
    Command.ExecuteCdpCommand: (HttpPost, sessionIdPath & "/goog/cdp/execute"),
    Command.GetSinks: (HttpGet, sessionIdPath & "/goog/cast/get_sinks"),
    Command.GetIssueMessage: (HttpGet, sessionIdPath & "/goog/cast/get_issue_message"),
    Command.SetSinkToUse: (HttpPost, sessionIdPath & "/goog/cast/set_sink_to_use"),
    Command.StartTabMirroring: (HttpPost, sessionIdPath & "/goog/cast/start_tab_mirroring"),
    Command.StopCasting: (HttpPost, sessionIdPath & "/goog/cast/stop_casting")
  }
)

const BaseCommandTable*: CommandTable = BasicCommands.toTable
const FirefoxCommandTable*: CommandTable = FirefoxCommands.toTable
const SafariCommandTable*: CommandTable = SafariCommands.toTable
const ChromiumCommandTable*: CommandTable = ChromiumCommands.toTable
