import tables, httpcore, sequtils

type
  CommandEndpointTuple* = tuple[httpMethod: HttpMethod, endpoint: string]
  CommandTable* = TableRef[Command, CommandEndpointTuple]
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
    # Chromium

const BasicCommands = @{
  Command.Status: (HttpGet, "/status"),
  Command.NewSession: (HttpPost, "/session"),
  Command.GetAllSessions: (HttpGet, "/sessions"),
  Command.Quit: (HttpDelete, "/session/$sessionId"),
  Command.GetCurrentWindowHandle: (HttpGet, "/session/$sessionId/window_handle"),
  Command.W3CGetCurrentWindowHandle: (HttpGet, "/session/$sessionId/window"),
  Command.GetWindowHandles: (HttpGet, "/session/$sessionId/window_handles"),
  Command.W3CGetWindowHandles: (HttpGet, "/session/$sessionId/window/handles"),
  Command.Get: (HttpPost, "/session/$sessionId/url"),
  Command.GoForward: (HttpPost, "/session/$sessionId/forward"),
  Command.GoBack: (HttpPost, "/session/$sessionId/back"),
  Command.Refresh: (HttpPost, "/session/$sessionId/refresh"),
  Command.ExecuteScript: (HttpPost, "/session/$sessionId/execute"),
  Command.W3CExecuteScript: (HttpPost, "/session/$sessionId/execute/sync"),
  Command.W3CExecuteScriptAsync: (HttpPost, "/session/$sessionId/execute/async"),
  Command.GetCurrentUrl: (HttpGet, "/session/$sessionId/url"),
  Command.GetTitle: (HttpGet, "/session/$sessionId/title"),
  Command.GetPageSource: (HttpGet, "/session/$sessionId/source"),
  Command.Screenshot: (HttpGet, "/session/$sessionId/screenshot"),
  Command.ElementScreenshot: (HttpGet, "/session/$sessionId/element/$id/screenshot"),
  Command.FindElement: (HttpPost, "/session/$sessionId/element"),
  Command.FindElements: (HttpPost, "/session/$sessionId/elements"),
  Command.W3CGetActiveElement: (HttpGet, "/session/$sessionId/element/active"),
  Command.GetActiveElement: (HttpPost, "/session/$sessionId/element/active"),
  Command.FindChildElement: (HttpPost, "/session/$sessionId/element/$id/element"),
  Command.FindChildElements: (HttpPost, "/session/$sessionId/element/$id/elements"),
  Command.ClickElement: (HttpPost, "/session/$sessionId/element/$id/click"),
  Command.ClearElement: (HttpPost, "/session/$sessionId/element/$id/clear"),
  Command.SubmitElement: (HttpPost, "/session/$sessionId/element/$id/submit"),
  Command.GetElementText: (HttpGet, "/session/$sessionId/element/$id/text"),
  Command.SendKeysToElement: (HttpPost, "/session/$sessionId/element/$id/value"),
  Command.SendKeysToActiveElement: (HttpPost, "/session/$sessionId/keys"),
  Command.UploadFile: (HttpPost, "/session/$sessionId/file"),
  Command.GetElementValue: (HttpGet, "/session/$sessionId/element/$id/value"),
  Command.GetElementTagName: (HttpGet, "/session/$sessionId/element/$id/name"),
  Command.IsElementSelected: (HttpGet, "/session/$sessionId/element/$id/selected"),
  Command.SetElementSelected: (HttpPost, "/session/$sessionId/element/$id/selected"),
  Command.IsElementEnabled: (HttpGet, "/session/$sessionId/element/$id/enabled"),
  Command.IsElementDisplayed: (HttpGet, "/session/$sessionId/element/$id/displayed"),
  Command.GetElementLocation: (HttpGet, "/session/$sessionId/element/$id/location"),
  Command.GetElementLocationOnceScrolledIntoView: (HttpGet, "/session/$sessionId/element/$id/location_in_view"),
  Command.GetElementSize: (HttpGet, "/session/$sessionId/element/$id/size"),
  Command.GetElementRect: (HttpGet, "/session/$sessionId/element/$id/rect"),
  Command.GetElementAttribute: (HttpGet, "/session/$sessionId/element/$id/attribute/$name"),
  Command.GetElementProperty: (HttpGet, "/session/$sessionId/element/$id/property/$name"),
  Command.GetAllCookies: (HttpGet, "/session/$sessionId/cookie"),
  Command.AddCookie: (HttpPost, "/session/$sessionId/cookie"),
  Command.GetCookie: (HttpGet, "/session/$sessionId/cookie/$name"),
  Command.DeleteAllCookies: (HttpDelete, "/session/$sessionId/cookie"),
  Command.DeleteCookie: (HttpDelete, "/session/$sessionId/cookie/$name"),
  Command.SwitchToFrame: (HttpPost, "/session/$sessionId/frame"),
  Command.SwitchToParentFrame: (HttpPost, "/session/$sessionId/frame/parent"),
  Command.SwitchToWindow: (HttpPost, "/session/$sessionId/window"),
  Command.NewWindow: (HttpPost, "/session/$sessionId/window/new"),
  Command.Close: (HttpDelete, "/session/$sessionId/window"),
  Command.GetElementValueOfCssProperty: (HttpGet, "/session/$sessionId/element/$id/css/$propertyName"),
  Command.ImplicitWait: (HttpPost, "/session/$sessionId/timeouts/implicit_wait"),
  Command.ExecuteAsyncScript: (HttpPost, "/session/$sessionId/execute_async"),
  Command.SetScriptTimeout: (HttpPost, "/session/$sessionId/timeouts/async_script"),
  Command.SetTimeouts: (HttpPost, "/session/$sessionId/timeouts"),
  Command.DismissAlert: (HttpPost, "/session/$sessionId/dismiss_alert"),
  Command.W3CDismissAlert: (HttpPost, "/session/$sessionId/alert/dismiss"),
  Command.AcceptAlert: (HttpPost, "/session/$sessionId/accept_alert"),
  Command.W3CAcceptAlert: (HttpPost, "/session/$sessionId/alert/accept"),
  Command.SetAlertValue: (HttpPost, "/session/$sessionId/alert_text"),
  Command.W3CSetAlertValue: (HttpPost, "/session/$sessionId/alert/text"),
  Command.GetAlertText: (HttpGet, "/session/$sessionId/alert_text"),
  Command.W3CGetAlertText: (HttpGet, "/session/$sessionId/alert/text"),
  Command.SetAlertCredentials: (HttpPost, "/session/$sessionId/alert/credentials"),
  Command.Click: (HttpPost, "/session/$sessionId/click"),
  Command.W3CActions: (HttpPost, "/session/$sessionId/actions"),
  Command.W3CClearActions: (HttpDelete, "/session/$sessionId/actions"),
  Command.DoubleClick: (HttpPost, "/session/$sessionId/doubleclick"),
  Command.MouseDown: (HttpPost, "/session/$sessionId/buttondown"),
  Command.MouseUp: (HttpPost, "/session/$sessionId/buttonup"),
  Command.MoveTo: (HttpPost, "/session/$sessionId/moveto"),
  Command.GetWindowSize: (HttpGet, "/session/$sessionId/window/$windowHandle/size"),
  Command.SetWindowSize: (HttpPost, "/session/$sessionId/window/$windowHandle/size"),
  Command.GetWindowPosition: (HttpGet, "/session/$sessionId/window/$windowHandle/position"),
  Command.SetWindowPosition: (HttpPost, "/session/$sessionId/window/$windowHandle/position"),
  Command.SetWindowRect: (HttpPost, "/session/$sessionId/window/rect"),
  Command.GetWindowRect: (HttpGet, "/session/$sessionId/window/rect"),
  Command.MaximizeWindow: (HttpPost, "/session/$sessionId/window/$windowHandle/maximize"),
  Command.W3CMaximizeWindow: (HttpPost, "/session/$sessionId/window/maximize"),
  Command.SetScreenOrientation: (HttpPost, "/session/$sessionId/orientation"),
  Command.GetScreenOrientation: (HttpGet, "/session/$sessionId/orientation"),
  Command.SingleTap: (HttpPost, "/session/$sessionId/touch/click"),
  Command.TouchDown: (HttpPost, "/session/$sessionId/touch/down"),
  Command.TouchUp: (HttpPost, "/session/$sessionId/touch/up"),
  Command.TouchMove: (HttpPost, "/session/$sessionId/touch/move"),
  Command.TouchScroll: (HttpPost, "/session/$sessionId/touch/scroll"),
  Command.DoubleTap: (HttpPost, "/session/$sessionId/touch/doubleclick"),
  Command.LongPress: (HttpPost, "/session/$sessionId/touch/longclick"),
  Command.Flick: (HttpPost, "/session/$sessionId/touch/flick"),
  Command.ExecuteSql: (HttpPost, "/session/$sessionId/execute_sql"),
  Command.GetLocation: (HttpGet, "/session/$sessionId/location"),
  Command.SetLocation: (HttpPost, "/session/$sessionId/location"),
  Command.GetAppCache: (HttpGet, "/session/$sessionId/application_cache"),
  Command.GetAppCacheStatus: (HttpGet, "/session/$sessionId/application_cache/status"),
  Command.ClearAppCache: (HttpDelete, "/session/$sessionId/application_cache/clear"),
  Command.GetNetworkConnection: (HttpGet, "/session/$sessionId/network_connection"),
  Command.SetNetworkConnection: (HttpPost, "/session/$sessionId/network_connection"),
  Command.GetLocalStorageItem: (HttpGet, "/session/$sessionId/local_storage/key/$key"),
  Command.RemoveLocalStorageItem: (HttpDelete, "/session/$sessionId/local_storage/key/$key"),
  Command.GetLocalStorageKeys: (HttpGet, "/session/$sessionId/local_storage"),
  Command.SetLocalStorageItem: (HttpPost, "/session/$sessionId/local_storage"),
  Command.ClearLocalStorage: (HttpDelete, "/session/$sessionId/local_storage"),
  Command.GetLocalStorageSize: (HttpGet, "/session/$sessionId/local_storage/size"),
  Command.GetSessionStorageItem: (HttpGet, "/session/$sessionId/session_storage/key/$key"),
  Command.RemoveSessionStorageItem: (HttpDelete, "/session/$sessionId/session_storage/key/$key"),
  Command.GetSessionStorageKeys: (HttpGet, "/session/$sessionId/session_storage"),
  Command.SetSessionStorageItem: (HttpPost, "/session/$sessionId/session_storage"),
  Command.ClearSessionStorage: (HttpDelete, "/session/$sessionId/session_storage"),
  Command.GetSessionStorageSize: (HttpGet, "/session/$sessionId/session_storage/size"),
  Command.GetLog: (HttpPost, "/session/$sessionId/se/log"),
  Command.GetAvailableLogTypes: (HttpGet, "/session/$sessionId/se/log/types"),
  Command.CurrentContextHandle: (HttpGet, "/session/$sessionId/context"),
  Command.ContextHandles: (HttpGet, "/session/$sessionId/contexts"),
  Command.SwitchToContext: (HttpPost, "/session/$sessionId/context"),
  Command.FullscreenWindow: (HttpPost, "/session/$sessionId/window/fullscreen"),
  Command.MinimizeWindow: (HttpPost, "/session/$sessionId/window/minimize")
}

const FirefoxCommands = BasicCommands.concat(
  @{
    Command.GetContext: (HttpGet, "/session/$sessionId/moz/context"),
    Command.SetContext: (HttpPost, "/session/$sessionId/moz/context"),
    Command.ElementGetAnonymousChildren: (HttpPost, "/session/$sessionId/moz/xbl/$id/anonymous_children"),
    Command.ElementFindAnonymousElementsByAttribute: (HttpPost, "/session/$sessionId/moz/xbl/$id/anonymous_by_attribute"),
    Command.InstallAddon: (HttpPost, "/session/$sessionId/moz/addon/install"),
    Command.UninstallAddon: (HttpPost, "/session/$sessionId/moz/addon/uninstall"),
    Command.FullPageScreenshot: (HttpGet, "/session/$sessionId/moz/screenshot/full")
  }
)

const BaseCommandTable*: Table[Command, CommandEndpointTuple] = BasicCommands.toTable
const FirefoxCommandTable*: Table[Command, CommandEndpointTuple] = FirefoxCommands.toTable
