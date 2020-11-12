# For reference, this is brilliant: https://github.com/jlipps/simple-wd-spec

import os, httpclient, uri, packedjson, options, strutils, sequtils, base64, strformat, tables
import base64, sets
import unicode except strip

import zip / zipfiles
import uuids, tempfile
import exceptions, service, errorhandler, commands, utils, browser

const actionDelayMs {.intdefine.} = 0

type
  WebDriver* = ref object
    url*: Uri
    client*: HttpClient
    browser*: BrowserKind
    keepAlive*: bool
    w3c*: bool
    session: Session
    capabilities: JsonNode

  SessionKind* = enum
    RemoteSession
    LocalSession

  Session* = ref object
    driver*: WebDriver
    case kind*: SessionKind
    of LocalSession:
      service: Service
    of RemoteSession:
      discard
    id*: string

  NetworkConditions* = object
    offline: bool
    latency: int
    downloadThroughput: int
    uploadThroughput: int

  Element* = ref object
    session*: Session
    id*: string

  Orientation* = enum
    oLandscape = "landscape"
    oPortrait = "portrait"

  ApplicationCacheStatus* = object
    build*: tuple[version: string]
    message*: string
    os*: tuple[arch, name, version: string]
    ready*: bool

  WindowKind* = enum
    wkWindow = "window"
    wkTab = "tab"

  LogType* = enum
    ltBrowser = "browser"
    ltDriver = "driver"

  LogEntry* = object
    level*: string
    source*: Option[string]
    message*: string
    timestamp*: uint64

  Window* = object
    handle*: string
    kind*: WindowKind
    session: Session

  Cookie* = object
    name*: string
    value*: string
    path*: Option[string]
    domain*: Option[string]
    secure*: Option[bool]
    httpOnly*: Option[bool]
    expiry*: Option[BiggestInt]

  LocationStrategy* = enum
    IDSelector = "id"
    XPathSelector = "xpath"
    LinkTextSelector = "link text"
    PartialLinkTextSelector = "partial link text"
    NameSelector = "name"
    TagNameSelector = "tag name"
    ClassNameSelector = "class name"
    CssSelector = "css selector"

  Key* {.pure.} = enum
    Null = "\ue000"
    Cancel = "\ue001"
    Help = "\ue002"
    Backspace = "\ue003"
    Tab = "\ue004"
    Clear = "\ue005"
    Return = "\ue006"
    Enter = "\ue007"
    LeftShift = "\ue008"
    Shift = $LeftShift
    LeftControl = "\ue009"
    Control = $LeftControl
    LeftAlt = "\ue00a"
    Alt = $LeftAlt
    Pause = "\ue00b"
    Escape = "\ue00c"
    Space = "\ue00d"
    PageUp = "\ue00e"
    PageDown = "\ue00f"
    End = "\ue010"
    Home = "\ue011"
    Left = "\ue012"
    ArrowLeft = $Left
    Up = "\ue013"
    ArrowUp = $Up
    Right = "\ue014"
    ArrowRight = $Right
    Down = "\ue015"
    ArrowDown = $Down
    Insert = "\ue016"
    Delete = "\ue017"
    Semicolon = "\ue018"
    Equals = "\ue019"

    Numpad0 = "\ue01a"
    Numpad1 = "\ue01b"
    Numpad2 = "\ue01c"
    Numpad3 = "\ue01d"
    Numpad4 = "\ue01e"
    Numpad5 = "\ue01f"
    Numpad6 = "\ue020"
    Numpad7 = "\ue021"
    Numpad8 = "\ue022"
    Numpad9 = "\ue023"
    Multiply = "\ue024"
    Add = "\ue025"
    Separator = "\ue026"
    Subtract = "\ue027"
    Decimal = "\ue028"
    Divide = "\ue029"

    F1 = "\ue031"
    F2 = "\ue032"
    F3 = "\ue033"
    F4 = "\ue034"
    F5 = "\ue035"
    F6 = "\ue036"
    F7 = "\ue037"
    F8 = "\ue038"
    F9 = "\ue039"
    F10 = "\ue03a"
    F11 = "\ue03b"
    F12 = "\ue03c"

    Meta = "\ue03d"
    Command = "\ue03d"

  PointerType* = enum
    ptMouse = "mouse"
    ptTouch = "touch"
    ptPen = "pen"

  SourceType* = enum
    stNone = "none"
    stKey = "key"
    stPointer = "pointer"

  MouseButton* = enum
    mbLeft, mbMiddle, mbRight

  ActionChain* = ref object
    w3cKeyActions: seq[Action]
    w3cPointerActions: seq[Action]
    actions: seq[(Command, Action)]
    session: Session

  ActionKind* = enum
    akKeyUp = "keyUp"
    akKeyDown = "keyDown"
    akKeyPause = "pause"
    akPointerUp = "pointerUp"
    akPointerDown = "pointerDown"
    akPointerMove = "pointerMove"
    akPointerCancel = "pointerCancel"
    akPointerPause = "pause"

  OriginKind* = enum
    okViewPort = "viewport"
    okPointer = "pointer"
    okElementSelector = "elementselector"
    okElement = "element"

  Origin = object
    case kind: OriginKind
    of okElementSelector:
      selector: string
      locationStrategy: LocationStrategy
    of okElement:
      elementId: string
    else:
      discard

  Action = ref object
    case ty: ActionKind
    of akKeyUp, akKeyDown:
      strValue: string
    of akPointerPause, akKeyPause:
      intValue: int
    of akPointerUp, akPointerDown:
      clickDuration: int
      button: MouseButton
    of akPointerMove:
      moveDuration: int
      x: float
      y: float
      origin: Origin
    of akPointerCancel:
      discard

  Rect* = tuple[x, y, width, height: float]


proc stop*(session: Session)
proc quit*(session: Session)
proc execute(self: WebDriver, command: Command, params: JsonNode = %*{}): JsonTree
proc getSelectorParams(self: Session, selector: string, strategy: LocationStrategy): JsonTree
proc `%`*(element: Element): JsonNode
proc clear*(element: Element)
proc rect*(element: Element): Rect
proc x*(element: Element): float
proc y*(element: Element): float
proc width*(element: Element): float
proc height*(element: Element): float
proc text*(element: Element): string

proc elementIsSome*(element: Option[Element]): bool =
  return element.isSome

proc elementIsNone*(element: Option[Element]): bool =
  return element.isNone

proc waitForElement*(
  session: Session,
  selector: string,
  strategy=CssSelector,
  timeout=10000,
  pollTime=50,
  waitCondition=elementIsSome
): Option[Element]

proc sourceType(action: Action): SourceType =
  result = stNone
  case action.ty
  of akKeyDown, akKeyPause, akKeyUp:
    result = stKey
  of akPointerCancel, akPointerDown, akPointerMove, akPointerPause, akPointerUp:
    result = stPointer

template unwrap(node: JsonNode, ty: untyped): untyped =
  if node.hasKey("value"):
    node["value"].to(ty)
  else:
    node.to(ty)

template unwrap(node: JsonNode): untyped =
  unwrap(node, type(result))

proc toElement*(node: JsonNode, session: Session): Element =
  for key, value in node.pairs():
    return Element(id: value.getStr(), session: session)

proc getDriverUri(kind: BrowserKind, url: string): Uri =
  case kind
  of Android, PhantomJs:
    if "wd/hub" notin url:
      parseUri(url) / "wd" / "hub"
    else:
      parseUri(url)
  else:
    parseUri(url)

########################################## WEBDRIVER PROCS ####################################

proc getConnectionHeaders(self: WebDriver, url: string, keepAlive = false): HttpHeaders =
  let uri = parseUri(url)
  let haloniumVersion = "0.1.0"
  var headers = @{
    "Accept": "application/json",
    "Content-Type": "application/json;charset=UTF-8",
    "User-Agent": fmt"halonium/{haloniumVersion} (nim {hostOs})"
  }

  if uri.username.len > 0:
    let encodedCreds = fmt"{uri.username}:{uri.password}".encode()
    headers = headers.concat(@{
      "Authorization": fmt"Basic {encodedCreds}"
    })

  if keepAlive:
    headers = headers.concat(@{
      "Connection": "keep-alive"
    })

  result = newHttpHeaders(headers)

proc request(self: WebDriver, httpMethod: HttpMethod, url: string, postBody = newJNull()): JsonTree =
  let headers = self.getConnectionHeaders(url, self.keepAlive)

  var bodyString: string
  if postBody.kind != JNull and httpMethod in {HttpPost, HttpPut}:
    bodyString = $postBody

  let
    response = self.client.request(url, httpMethod, bodyString, headers)
  var
    status = response.code.int

  if status in Http300.int ..< Http304.int:
    return self.request(HttpGet, response.headers["location"])
  if status in Http400.int .. Http500.int:
    return %*{
      "status": status,
      "value": response.body
    }

  let contentTypes = response.headers.getOrDefault("Content-Type").split(';')
  var isPng = false

  for ct in contentTypes:
    if ct.startsWith("image/png"):
      isPng = true
      break

  if isPng:
    return %*{"status": ErrorCode.Success.int, "value": response.body}
  else:
    try:
      result = parseJson(response.bodyStream)
    except JsonParsingError:
      if status > 199 and status < Http300.int:
        status = ErrorCode.Success.int
      else:
        status = ErrorCode.UnknownError.int
      return %*{"status": status, "value": response.body}

    if not result.hasKey("value"):
      result["value"] = newJNull()

proc newRemoteWebDriver*(kind: BrowserKind, url = "http://localhost:4444", keepAlive = true): WebDriver =
  result = WebDriver(
    url: getDriverUri(kind, url), browser: kind,
    client: newHttpClient(), keepAlive: keepAlive
  )

proc execute(self: WebDriver, command: Command, params: JsonNode = %*{}): JsonTree =
  var commandInfo: CommandEndpointTuple
  try:
    commandInfo = self.browser.getCommandTuple(command)
  except:
    raise newWebDriverException(fmt"Command '{$command}' could not be found.")

  let filledUrl = commandInfo[1].replace(params)

  var data = params.copy
  if self.w3c:
    if params.hasKey("sessionId"):
      data.delete("sessionId")

  let
    url = fmt"{self.url}{filledUrl}"

  let response = self.request(commandInfo[0], url, data)
  if response.kind != JNull:
    checkResponse(response)
    return response

  return %*{
    "success": Success.int,
    "value": nil,
    "sessionId": if not self.session.isNil: self.session.id else: ""
  }

const W3CCapabilityNames = [
  "acceptInsecureCerts",
  "browserName",
  "browserVersion",
  "platformName",
  "pageLoadStrategy",
  "proxy",
  "setWindowRect",
  "timeouts",
  "unhandledPromptBehavior",
  "strictFileInteractability"
].toHashSet

const OssW3CConversion = {
  "acceptSslCerts": "acceptInsecureCerts",
  "version": "browserVersion",
  "platform": "platformName"
}.toTable

proc toW3CCaps(caps: JsonNode): JsonTree =
  var newCaps = caps.copy
  var alwaysMatch = %*{}

  if newCaps{"proxy", "proxyType"}.kind != JNull:
    newCaps["proxy", "proxyType"] = %newCaps{"proxy", "proxyType"}.getStr().toLowerAscii

  for (k, v) in newCaps.pairs:
    if v.kind != JNull and v.getStr.len > 0 and OssW3CConversion.hasKey(k):
      alwaysMatch[OssW3CConversion[k]] = if k == "platform": %v.getStr().toLowerAscii else: v
    if k.contains(":") or k in W3CCapabilityNames:
      alwaysMatch[k] = v

  result = %*{"firstMatch": [{}], "alwaysMatch": alwaysMatch}

proc getSession(self: WebDriver, kind = RemoteSession, opts: JsonNode = %*{}): Session =
  var capabilities = desiredCapabilities(self.browser)
  for key, value in opts.pairs():
    capabilities[key] = value

  let parameters = %*{
    "capabilities": capabilities.toW3CCaps,
    "desiredCapabilities": capabilities
  }
  var response = self.execute(Command.NewSession, parameters)
  if not response.hasKey("sessionId"):
    response = response["value"].JsonTree

  let sessionId = response["sessionId"].getStr()
  self.capabilities = response{"value"}

  if self.capabilities.kind == JNull:
    self.capabilities = response{"capabilities"}
  self.w3c = response{"status"}.kind == JNull

  result = Session(driver: self, id: sessionId, kind: kind)

proc createRemoteSession*(browser: BrowserKind, url = "http://localhost:4444", keepAlive = true, browserOptions: JsonNode = %*{}): Session =
  ## Creates a remote session of type ``browser`` at the URL ``url``.
  ## ``browserOptions`` is a JsonNode generated by one of the procs in ``driveroptions.nim``
  runnableExamples:
    createRemoteSession(Chrome, url="http://my.site:4444", browserOptions=chromeOptions(args=["--headless"]))
  let driver = newRemoteWebDriver(browser, url, keepAlive)
  driver.getSession(opts=browserOptions)

proc createRemoteSession*(self: WebDriver, browserOptions: JsonNode = %*{}): Session =
  self.getSession(opts=browserOptions)

proc createSession*(
  self: WebDriver,
  driverExePath = none(string),
  port = freePort(),
  env = getAllEnv(),
  args = newSeq[string](),
  logPath = getDevNull(),
  logLevel = "",
  browserOptions: JsonNode = %*{}
): Session =
  ## Creates a session from an existing WebDriver instance
  ##
  ## Arguments
  ## ``driverExePath``: The path to the webdriver executable.
  ## ``port``: The port where the webdriver will run at. Defaults to a random free port
  ## ``env``: A string table of environment variables to load before the driver is run
  ## ``args``: A list of arguments to pass to the driver executable
  ## ``logPath``: The path to log messages from the driver to
  ## ``browserOptions``: A JsonNode representing arguments to send to the browser. Options can be
  ##                    generated using the procs in driveroptions.nim
  runnableExamples:
    let driver = newRemoteWebDriver(Firefox, url = "http://localhost:4444")
    let session = driver.createSession(driverExePath="customgeckodriver", port=4444, browserOptions=firefoxOptions(args=["--headless"]))
  result = getSession(self, LocalSession, opts=browserOptions)
  result.service = newService(self.browser, driverExePath, port, env, args, logPath, logLevel=logLevel)

  self.url = result.service.url.parseUri()
  result.service.start()

###################################### SESSION PROCS ##########################################

proc w3c*(self: Session): bool =
  return self.driver.w3c

proc execute(self: Session, command: Command, params: JsonNode = %*{}, stopOnException = true): JsonTree =
  var newParams = params.copy
  newParams["sessionId"] = %self.id
  try:
    result = self.driver.execute(command, newParams)
  except Exception as exc:
    if stopOnException:
      echo &"Unexpected exception caught while executing command {$command}. Message: {exc.msg}"
      echo "Closing session..."
      self.stop()
    raise exc

proc status*(self: Session): tuple[message: string, ready: bool] =
  self.execute(Command.Status).unwrap

proc createSession*(
  browser: BrowserKind,
  driverExePath = none(string),
  port = freePort(),
  env = getAllEnv(),
  args = newSeq[string](),
  logPath = getDevNull(),
  logLevel = "",
  browserOptions: JsonNode = %*{}
): Session =
  ## Creates a session and starts a webdriver instance
  ##
  ## Arguments
  ## ``browser``: The kind of browser to start a webdriver for
  ## ``driverExePath``: The path to the webdriver executable.
  ## ``port``: The port where the webdriver will run at. Defaults to a random free port
  ## ``env``: A string table of environment variables to load before the driver is run
  ## ``args``: A list of arguments to pass to the driver executable
  ## ``logPath``: The path to log messages from the driver to
  ## ``browserOptions``: A JsonNode representing arguments to send to the browser. Options can be
  ##                    generated using the procs in driveroptions.nim
  let service = newService(browser, driverExePath, port, env, args, logPath, logLevel=logLevel)
  service.start()
  let driver = newRemoteWebDriver(browser, service.url, keepAlive=true)
  result = getSession(driver, LocalSession, opts=browserOptions)
  result.service = service

proc getSelectorParams(self: Session, selector: string, strategy: LocationStrategy): JsonTree =
  var modifiedSelector = selector
  var modifiedStrategy = strategy

  if self.w3c:
    case strategy
    of IDSelector:
      modifiedSelector = &"[id=\"{selector}\"]"
      modifiedStrategy = CssSelector
    of TagNameSelector:
      modifiedStrategy = CssSelector
    of ClassNameSelector:
      modifiedStrategy = CssSelector
      modifiedSelector = &".{selector}"
    of NameSelector:
      modifiedStrategy = CssSelector
      modifiedSelector = &"[name=\"{selector}\"]"
    else:
      discard

  return %*{
      "using": $modifiedStrategy,
      "value": modifiedSelector
  }

proc findElement*(self: Session, selector: string, strategy = CssSelector): Option[Element] =
  try:
    let response = self.execute(
      Command.FindElement,
      getSelectorParams(self, selector, strategy),
      stopOnException = false
    )
    return some(response["value"].toElement(self))
  except NoSuchElementException:
    return none(Element)

proc findElements*(self: Session, selector: string, strategy = CssSelector): seq[Element] =
  try:
    let response = self.execute(
      Command.FindElements,
      getSelectorParams(self, selector, strategy),
      stopOnException = false
     )
    for elementNode in response["value"].items:
      result.add(elementNode.toElement(self))
  except NoSuchElementException:
    return @[]

proc executeScript*(self: Session, code: string, args: varargs[JsonNode, `%`]): JsonTree =
  let params = %*{
    "script": code,
    "args": args
  }
  if self.w3c:
    self.execute(Command.W3CExecuteScript, params)["value"].JsonTree
  else:
    self.execute(Command.ExecuteScript, params)["value"].JsonTree

proc executeScriptAsync*(self: Session, code: string, args: varargs[JsonNode, `%`]): JsonTree =
  let params = %*{
    "script": code,
    "args": args
  }
  if self.w3c:
    self.execute(Command.W3CExecuteScriptAsync, params)["value"].JsonTree
  else:
    self.execute(Command.ExecuteAsyncScript, params)["value"].JsonTree

proc takeScreenshotBase64*(self: Session): string =
  self.execute(Command.Screenshot).unwrap

proc takeScreenshotPng*(self: Session): string =
  base64.decode(self.takeScreenshotBase64())

proc saveScreenShotTo*(self: Session, filename: string): string =
  let png = self.takeScreenShotPng()
  try:
    filename.writeFile(png)
  except Exception as exc:
    # TODO: Move this to a logging module
    echo fmt"Could not save image '{filename}'. Error: {exc.msg}"

proc currentWindow*(self: Session): Window =
  var handle: string
  if self.w3c:
    handle = self.execute(Command.W3CGetCurrentWindowHandle).unwrap(string)
  else:
    handle = self.execute(Command.GetCurrentWindowHandle).unwrap(string)

  Window(handle: handle, session: self)

proc windows*(self: Session): seq[Window] =
  var handles: seq[string]
  if self.w3c:
    handles = self.execute(Command.W3CGetWindowHandles).unwrap(seq[string])
  else:
    handles = self.execute(Command.GetWindowHandles).unwrap(seq[string])

  for handle in handles:
    result.add(Window(handle: handle, session: self))

proc navigate*(self: Session, url: string) =
  let response = self.execute(Command.Get, %*{"url": %url})
  if response{"value"}.len != 0:
    raise newWebDriverException($response)

proc forward*(self: Session) =
  ## Go one step forward in the browser history
  discard self.execute(Command.GoForward)

proc back*(self: Session) =
  ## Go one step backward in the browser history
  discard self.execute(Command.GoBack)

proc refresh*(self: Session) =
  ## Refresh the current page
  discard self.execute(Command.Refresh)

proc currentUrl*(self: Session): string =
  self.execute(Command.GetCurrentUrl).unwrap

proc title*(self: Session): string =
  self.execute(Command.GetTitle).unwrap

proc pageSource*(self: Session): string =
  self.execute(Command.GetPageSource).unwrap

proc activeElement*(self: Session): Element =
  if self.w3c:
    self.execute(Command.W3CGetActiveElement)["value"].toElement(self)
  else:
    self.execute(Command.GetActiveElement)["value"].toElement(self)

proc sendKeysToActiveElement*(self: Session, text: string) =
  discard self.execute(Command.SendKeysToActiveElement, %*{"text": text})

# proc uploadFile*(self: Session, file: string) =

proc close*(session: Session) =
  ## Closes the current session
  discard session.execute(Command.Quit, stopOnException=false)

proc stop*(session: Session) =
  session.close()
  case session.kind
  of LocalSession:
    session.service.stop()
  of RemoteSession:
    discard

proc quit*(session: Session) =
  session.stop()

proc getCookie*(self: Session, name: string): Option[Cookie] =
  try:
    self.execute(Command.GetCookie, %*{"name": name}, stopOnException=false).unwrap
  except NoSuchCookieException:
    none(Cookie)
  except Exception as exc:
    self.stop()
    raise exc

proc deleteCookie*(self: Session, name: string) =
  try:
    discard self.execute(Command.DeleteCookie, %*{"name": name}, stopOnException=false)
  except NoSuchCookieException:
    # TODO: Warning: cookie not found
    discard
  except Exception as exc:
    self.stop()
    raise exc

proc allCookies*(self: Session): seq[Cookie] =
  self.execute(Command.GetAllCookies).unwrap

proc deleteAllCookies*(self: Session) =
  discard self.execute(Command.DeleteAllCookies)

proc switchToFrame*(self: Session, frame: Element) =
  discard self.execute(Command.SwitchToFrame, %*{"id": frame})

proc switchToFrame*(self: Session, frameId: int) =
  discard self.execute(Command.SwitchToFrame, %*{"id": frameId})

proc execute*(window: Window, command: Command, params: JsonNode = %*{}): JsonTree =
  var newParams = params.copy
  newParams["windowHandle"] = %window.handle
  try:
    result = window.session.execute(command, newParams)
  except Exception as exc:
    echo &"Unexpected exception caught while executing command {$command}. Message: {exc.msg}"
    echo "Closing session..."
    window.session.stop()
    raise exc

proc switchToWindow*(self: Session, window: Window) =
  discard self.execute(Command.SwitchToWindow, %*{"handle": window.handle})

proc toWindowKind(str: string): WindowKind =
  for val in WindowKind:
    if $val == str:
      return val

proc newWindow*(self: Session, ty: WindowKind): Window =
  let response = self.execute(Command.NewWindow, %*{"type": $ty})["value"]
  result.handle = response["handle"].getStr()
  result.kind = response["type"].getStr().toWindowKind
  result.session = self

proc newWindow*(self: Session): Window =
  let response = self.execute(Command.NewWindow)["value"]
  result.handle = response["handle"].getStr()
  result.kind = response["type"].getStr().toWindowKind
  result.session = self

proc closeCurrentWindow*(self: Session) =
  discard self.execute(Command.Close)

proc closeWindow*(self: Session, window: Window) =
  self.switchToWindow(window)
  discard self.execute(Command.Close)

proc rect*(window: Window): Rect =
  window.execute(Command.GetWindowRect).unwrap

proc `rect=`*(window: Window, rect: Rect) =
  if not window.session.w3c:
    window.session.stop()
    raise newWebDriverException(UnknownMethodException, "Setting window.rect is only supported on W3C compatible drivers")
  discard window.execute(Command.SetWindowRect, %rect)

proc size*(window: Window): tuple[width, height: float] =
  if window.session.w3c:
    if window.handle != "current":
      echo "Only current window is supported for W3C Compatible browsers"
    let rect = window.rect
    (width: rect.width, height: rect.height)
  else:
    window.execute(Command.GetWindowSize).unwrap

proc `size=`*(window: Window, size: tuple[width, height: float]) =
  if window.session.w3c:
    if window.handle != "current":
      echo "Only current window is supported for W3C Compatible browsers"
    var rect = window.rect
    rect.width = size.width
    rect.height = size.height
    window.rect = rect
  else:
    discard window.execute(Command.SetWindowSize, %size)

proc position*(window: Window): tuple[x, y: float] =
  if window.session.w3c:
    if window.handle != "current":
      echo "Only current window is supported for W3C Compatible browsers"
    let rect = window.rect
    (x: rect.x, y: rect.y)
  else:
    window.execute(Command.GetWindowPosition).unwrap

proc `position=`*(window: Window, pos: tuple[x, y: float]) =
  if window.session.w3c:
    if window.handle != "current":
      echo "Only current window is supported for W3C Compatible browsers"
    var rect = window.rect
    rect.x = pos.x
    rect.y = pos.y
    window.rect = rect
  else:
    discard window.execute(Command.SetWindowPosition, %pos)

proc maximize*(window: Window) =
  if window.session.w3c:
    discard window.execute(Command.W3CMaximizeWindow)
  else:
    discard window.execute(Command.MaximizeWindow)

proc toOrientation(str: string): Orientation =
  for kind in Orientation:
    if $kind == str:
      return kind

proc orientation*(self: Session): Orientation =
  if self.w3c:
    self.stop()
    raise newWebDriverException("Orientation is only supported on non-W3C compatible drivers")
  self.execute(Command.GetScreenOrientation)["value"].getStr().toOrientation

proc `orientation=`*(self: Session, orientation: Orientation) =
  if self.w3c:
    self.stop()
    raise newWebDriverException("Orientation is only supported on non-W3C compatible drivers")
  discard self.execute(Command.SetScreenOrientation, %*{"orientation": $orientation})

proc applicationCacheStatus*(self: Session): ApplicationCacheStatus =
  self.execute(Command.GetAppCacheStatus).unwrap

proc applicationCache*(self: Session) =
  ## This seems to not be supported in the latest chrome/firefox/safari drivers.
  ## Not sure what it's supposed to return
  discard self.execute(Command.GetAppCache)

proc clearApplicationCache*(self: Session) =
  ## This seems to not be supported in the latest chrome/firefox/safari drivers.
  ## Not sure what it's supposed to return
  discard self.execute(Command.ClearAppCache)

proc networkConnection*(self: Session) =
  ## TODO: Support this. Requires implementing options
  echo self.execute(Command.GetNetworkConnection)

proc log*(self: Session, logType: LogType): seq[LogEntry] =
  self.execute(Command.GetLog, %*{"type": $logType}).unwrap

proc logTypes*(self: Session): seq[LogType] =
  self.execute(Command.GetAvailableLogTypes).unwrap

proc fullScreenWindow*(self: Session): Rect =
  self.execute(Command.FullScreenWindow).unwrap

proc minimizeWindow*(self: Session): Rect =
  self.execute(Command.MinimizeWindow).unwrap

################################ Non-W3C commands #################################

proc localStorageKeys*(self: Session) =
  if not self.w3c:
    echo self.execute(Command.GetLocalStorageKeys)
  else:
    self.stop()
    raise newWebDriverException("localStorageKeys is only supported on non-W3C compatible drivers")

proc removeLocalStorageItem*(self: Session, item: string) =
  if not self.w3c:
    echo self.execute(Command.RemoveLocalStorageItem, %*{"key": item})
  else:
    self.stop()
    raise newWebDriverException("removeLocalStorageItem is only supported on non-W3C compatible drivers")

proc currentContextHandle*(self: Session) =
  if not self.w3c:
    echo self.execute(Command.CurrentContextHandle)
  else:
    self.stop()
    raise newWebDriverException("currentContextHandle is only supported on non-W3C compatible drivers")

###################################################################################

proc `implicitWait=`*(self: Session, waitingTime: float) =
  if self.w3c:
    discard self.execute(Command.SetTimeouts, %*{"implicit": (waitingTime * 1000).int})
  else:
    discard self.execute(Command.ImplicitWait, %*{"ms": (waitingTime * 1000).int})

proc `scriptTimeout=`*(self: Session, waitingTime: float) =
  if self.w3c:
    discard self.execute(Command.SetTimeouts, %*{"script": (waitingTime * 1000).int})
  else:
    discard self.execute(Command.SetScriptTimeout, %*{"ms": (waitingTime * 1000).int})

proc `pageLoadTimeout`*(self: Session, waitingTime: float) =
  try:
    discard self.execute(
      Command.SetTimeouts, %*{"pageLoad": (waitingTime * 1000).int}, stopOnException = false
    )
  except WebDriverException:
    discard self.execute(
      Command.SetTimeouts,
      %*{"ms": (waitingTime * 1000).int, "type": "page load"}
    )

proc dismissAlert*(self: Session) =
  if self.w3c:
    discard self.execute(Command.W3CDismissAlert)
  else:
    discard self.execute(Command.DismissAlert)

proc acceptAlert*(self: Session) =
  if self.w3c:
    discard self.execute(Command.W3CAcceptAlert)
  else:
    discard self.execute(Command.AcceptAlert)

proc `alertValue=`*(self: Session, value: string) =
  if self.w3c:
    discard self.execute(Command.W3CSetAlertValue, %*{"value": value, "text": value})
  else:
    discard self.execute(Command.SetAlertValue, %*{"text": value})

proc alertText*(self: Session): string =
  if self.w3c:
    self.execute(Command.W3CGetAlertText).unwrap
  else:
    self.execute(Command.GetAlertText).unwrap

proc waitForElement*(
  session: Session, selector: string, strategy=CssSelector,
  timeout=10000, pollTime=50,
  waitCondition=elementIsSome
): Option[Element] =
  ## Wait for an element based on a wait condition
  ##
  ## ``selector``: A selector string. It should be in the style that ``strategy`` expects
  ## ``waitCondition``: a condition with the signature ``proc (element: Option[Element]): bool``.
  ##                    Defaults to waiting until an element is found
  var waitTime = 0

  when actionDelayMs > 0:
    sleep(actionDelayMs)

  while true:
    try:
      let loading = session.findElement(selector, strategy)
      if waitCondition(loading):
        return loading
    except:
      discard
    sleep(pollTime)
    waitTime += pollTime

    if waitTime > timeout:
      session.stop()
      raise newWebDriverException(fmt"Waiting for element '{selector}' failed")

proc waitForElements*(
  session: Session, selector: string, strategy=CssSelector,
  timeout=10000, pollTime=50
): seq[Element] =
  var waitTime = 0

  when actionDelayMs > 0:
    sleep(actionDelayMs)

  while true:
    try:
      let loading = session.findElements(selector, strategy)
      if loading.len > 0:
        return loading
    except Exception:
      discard
    sleep(pollTime)
    waitTime += pollTime

    if waitTime > timeout:
      session.stop()
      raise newWebDriverException(fmt"Waiting for elements '{selector}' failed")

template waitForElement(chain: ActionChain, code: untyped): untyped =
  let elOption = chain.session.waitForElement(selector, strategy = locationStrategy)
  if elOption.isSome():
    let element {.inject.} = elOption.get()
    code
  else:
    chain.session.stop()
    raise newWebDriverException(NoSuchElementException, fmt"Could not find element '{selector}'")

###################################### Actions #####################################

proc clearActions*(self: Session) =
  discard self.execute(Command.W3CClearActions)

proc actionChain*(self: Session): ActionChain =
  result = ActionChain(session: self, w3cKeyActions: @[], w3cPointerActions: @[])

proc createAction(
  ty: ActionKind,
  element: Element = nil,
  selector: string = "",
  x: float = -1, y: float = -1,
  duration: float = 0,
  button: MouseButton = mbLeft,
  key: Key | Rune | string = Key.Null,
  originKind = okViewPort,
  locationStrategy = CssSelector
): Action =
  case ty
  of akPointerPause, akKeyPause:
    Action(ty: ty, intValue: (duration * 1000).int)
  of akKeyDown, akKeyUp:
    Action(ty: ty, strValue: $key)
  of akPointerCancel:
    Action(ty: ty)
  of akPointerDown, akPointerUp:
    Action(ty: ty, clickDuration: (duration * 1000).int, button: button)
  of akPointerMove:
    var origin: Origin
    case originKind
    of okElementSelector:
      origin = Origin(kind: originKind, selector: selector,
                      locationStrategy: locationStrategy)
    of okElement:
      origin = Origin(kind: originKind, elementId: element.id)
    else:
      origin = Origin(kind: originKind)
    Action(
      ty: ty,
      moveDuration: (duration * 1000).int,
      x: x, y: y,
      origin: origin
    )

proc addW3CAction(chain: ActionChain, action: Action): ActionChain =
  let sourceType = action.sourceType()
  case sourceType
  of stKey:
    chain.w3cKeyActions.add(action)
    # Add a pause for Pointer types when a Key type has been added
    # so that webdriver ticks align
    chain.w3cPointerActions.add(createAction(akPointerPause))
  of stPointer:
    chain.w3cPointerActions.add(action)
    # Add a pause for Key types when a Pointer type has been added
    # so that webdriver ticks align
    chain.w3cKeyActions.add(createAction(akKeyPause))
  of stNone:
    discard
  chain

proc addAction(chain: ActionChain, command: Command, action: Action): ActionChain =
  chain.actions.add((command, action))
  chain

proc resetActions*(chain: ActionChain): ActionChain =
  result = chain.session.actionChain()
  chain.actions = result.actions
  chain.w3cKeyActions = result.w3cKeyActions
  chain.w3cPointerActions = result.w3cPointerActions

proc createKeyUp(key: Key | Rune | string): Action =
  createAction(akKeyUp, key=key)

proc createKeyDown(key: Key | Rune | string): Action =
  createAction(akKeyDown, key=key)

proc createMouseUp(button: MouseButton, duration: float = 0): Action =
  createAction(akPointerUp, button=button, duration=duration)

proc createMouseDown(button: MouseButton, duration: float = 0): Action =
  createAction(akPointerDown, button=button, duration=duration)

proc mouseButtonDown*(chain: ActionChain, button = mbLeft, duration: float = 0): ActionChain =
  let action = createMouseDown(button, duration)
  if chain.session.w3c:
    chain.addW3CAction(action)
  else:
    chain.addAction(Command.MouseDown, action)

proc mouseButtonUp*(chain: ActionChain, button = mbLeft, duration: float = 0): ActionChain =
  let action = createMouseUp(button, duration)
  if chain.session.w3c:
    chain.addW3CAction(action)
  else:
    chain.addAction(Command.MouseDown, action)

proc createPointerMove(x, y: float, duration: float = 0, originKind: OriginKind = okViewPort): Action =
  createAction(akPointerMove, x=x, y=y, duration=duration, originKind=originKind)

proc createPointerMove(x, y: float, element: Element, duration: float = 0): Action =
  createAction(akPointerMove, x=x, y=y, duration=duration, element=element, originKind=okElement)

proc createPointerMove(x, y: float, selector: string, duration: float = 0, locationStrategy = CssSelector): Action =
  createAction(
    akPointerMove, x=x, y=y, duration=duration,
    selector=selector, locationStrategy=locationStrategy,
    originKind=okElementSelector
  )

proc createPointerMove(element: Element, duration: float = 0): Action =
  createAction(akPointerMove, duration=duration, element=element, originKind=okElement)

proc createPointerMove(selector: string, duration: float = 0, locationStrategy = CssSelector): Action =
  createAction(
    akPointerMove, duration=duration,
    selector=selector, locationStrategy=locationStrategy,
    originKind=okElementSelector
  )

proc moveMouse*(chain: ActionChain, x, y, duration: float = 0, origin: OriginKind): ActionChain =
  if chain.session.w3c:
    chain.addW3CAction(createPointerMove(x, y, duration, origin))
  else:
    raise newWebDriverException("moveMouse to absolute x, y is only supported in W3C compatible drivers")

proc moveMouseTo*(chain: ActionChain, x, y, duration: float = 0): ActionChain =
  ## Moves mouse to ``x``, ``y`` coordinates from the current viewport over ``duration`` seconds
  moveMouse(chain, x, y, duration, okViewPort)

proc moveMouseTo*(chain: ActionChain, element: Element, deltaX, deltaY, duration: float): ActionChain =
  ## Moves the mouse cursor from it's location to element.x + deltaX, element.y + deltaY over ``duration``
  ## seconds
  if chain.session.w3c:
    chain.addW3CAction(createPointerMove(deltaX, deltaY, element, duration))
  else:
    raise newWebDriverException("moveMouseTo with duration is not supported for non-W3C drivers")

proc moveMouseTo*(chain: ActionChain, element: Element, deltaX, deltaY: float): ActionChain =
  ## Moves the mouse cursor from it's location to element.x + deltaX, element.y + deltaY
  if chain.session.w3c:
    chain.moveMouseTo(element, deltaX, deltaY, 0)
  else:
    chain.addAction(
      Command.MoveTo,
      createPointerMove(deltaX, deltaY, element)
    )

proc moveMouseTo*(
  chain: ActionChain,
  selector: string,
  deltaX, deltaY: float,
  locationStrategy = CssSelector
): ActionChain =
  let action = createPointerMove(deltaX, deltaY, selector, locationStrategy=locationStrategy)
  if chain.session.w3c:
    chain.addW3CAction(action)
  else:
    chain.addAction(Command.MoveTo, action)

proc moveMouseTo*(chain: ActionChain, element: Element, duration: float): ActionChain =
  ## Moves the mouse cursor from it's location to the center of ``element`` over ``duration`` seconds
  if chain.session.w3c:
    chain.addW3CAction(createPointerMove(0, 0, element, duration))
  else:
    raise newWebDriverException("moveMouseTo with duration is not supported for non-W3C drivers")

proc moveMouseTo*(
  chain: ActionChain,
  selector: string,
  duration: float,
  locationStrategy = CssSelector
): ActionChain =
  if chain.session.w3c:
    chain.addW3CAction(
      createPointerMove(0, 0, selector, duration=duration, locationStrategy=locationStrategy)
    )
  else:
    raise newWebDriverException("moveMouseTo with duration is not supported for non-W3C drivers")

proc moveMouseTo*(chain: ActionChain, element: Element): ActionChain =
  ## Moves the mouse cursor from it's location to the center of ``element``
  if chain.session.w3c:
    chain.moveMouseTo(element, 0)
  else:
    chain.addAction(Command.MoveTo, createPointerMove(element, 0))

proc moveMouseTo*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  ## Moves the mouse cursor from it's location to the center of ``selector``
  if chain.session.w3c:
    chain.moveMouseTo(selector, 0, locationStrategy)
  else:
    chain.addAction(Command.MoveTo, createPointerMove(selector, 0, locationStrategy))

proc moveMouseBy*(chain: ActionChain, deltaX, deltaY, duration: float): ActionChain =
  ## Moves the mouse cursor from it current x, y to x + deltaX, y + deltaY over ``duration``
  ## seconds. Only supported in W3C Compatible drivers
  chain.moveMouse(deltaX, deltaY, duration, okPointer)

proc moveMouseBy*(chain: ActionChain, deltaX, deltaY: float): ActionChain =
  ## Moves the mouse cursor from it current x, y to x + deltaX, y + deltaY
  ## seconds
  if chain.session.w3c:
    chain.moveMouseBy(deltaX, deltaY, 0)
  else:
    chain.addAction(Command.MoveTo, createPointerMove(deltaX, deltaY, 0, okPointer))

proc pause*(chain: ActionChain, duration: float = 0): ActionChain =
  if chain.session.w3c:
    chain.w3cKeyActions.add(createAction(akPointerPause, duration=duration))
    chain.w3cKeyActions.add(createAction(akKeyPause, duration=duration))
    chain
  else:
    chain.addAction(Command.Pause, createAction(akKeyPause, duration=duration))

proc click*(chain: ActionChain, button = mbLeft): ActionChain =
  chain.mouseButtonDown(button)
       .mouseButtonUp(button)

proc click*(chain: ActionChain, element: Element, button = mbLeft): ActionChain =
  chain.moveMouseTo(element).click(button)

proc click*(
  chain: ActionChain,
  selector: string,
  button = mbLeft,
  locationStrategy = CssSelector
): ActionChain =
  chain.moveMouseTo(selector, locationStrategy).click(button)

proc rightClick*(chain: ActionChain): ActionChain =
  chain.click(mbRight)

proc rightClick*(chain: ActionChain, element: Element): ActionChain =
  chain.click(element, mbRight)

proc rightClick*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  chain.click(selector, button=mbRight, locationStrategy=locationStrategy)

proc clickAndHold*(chain: ActionChain, button = mbLeft): ActionChain =
  chain.mouseButtonDown(button)

proc clickAndHold*(chain: ActionChain, element: Element, button = mbLeft): ActionChain =
  chain.moveMouseTo(element).clickAndHold(button)

proc clickAndHold*(
  chain: ActionChain,
  selector: string,
  button = mbLeft,
  locationStrategy = CssSelector
): ActionChain =
  chain.moveMouseTo(selector, locationStrategy).clickAndHold(button)

proc rightClickAndHold*(chain: ActionChain): ActionChain =
  chain.clickAndHold(mbRight)

proc rightClickAndHold*(chain: ActionChain, element: Element): ActionChain =
  chain.clickAndHold(element, mbRight)

proc rightClickAndHold*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  chain.clickAndHold(selector, mbRight, locationStrategy)

proc doubleClick*(chain: ActionChain, button = mbLeft): ActionChain =
  chain.click(button)
       .click(button)

proc doubleClick*(chain: ActionChain, element: Element, button = mbLeft): ActionChain =
  chain.moveMouseTo(element).doubleClick(button)

proc doubleClick*(
  chain: ActionChain,
  selector: string,
  button = mbLeft,
  locationStrategy = CssSelector
): ActionChain =
  chain.moveMouseTo(selector, locationStrategy).doubleClick(button)

proc doubleRightClick*(chain: ActionChain): ActionChain =
  chain.doubleClick(mbRight)

proc doubleRightClick*(chain: ActionChain, element: Element): ActionChain =
  chain.doubleClick(element, mbRight)

proc doubleRightClick*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  chain.doubleClick(selector, mbRight, locationStrategy)

proc release*(chain: ActionChain, button = mbLeft): ActionChain =
  chain.mouseButtonUp(button, 0)

proc releaseRight*(chain: ActionChain): ActionChain =
  chain.release(mbRight)

proc release*(chain: ActionChain, element: Element, button = mbLeft): ActionChain =
  chain.moveMouseTo(element).mouseButtonUp(button, 0)

proc releaseRight*(chain: ActionChain, element: Element): ActionChain =
  chain.release(element, mbRight)

proc release*(
  chain: ActionChain,
  selector: string,
  button = mbLeft,
  locationStrategy = CssSelector
): ActionChain =
  chain.moveMouseTo(selector, locationStrategy).mouseButtonUp(button, 0)

proc releaseRight*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  chain.release(selector, mbRight, locationStrategy)

proc dragAndDrop*(chain: ActionChain, source, dest: Element): ActionChain =
  chain.clickAndHold(source)
       .release(dest)

proc dragAndDrop*(chain: ActionChain, source, dest: string, locationStrategy = CssSelector): ActionChain =
  chain.clickAndHold(source, locationStrategy=locationStrategy)
       .release(dest, locationStrategy=locationStrategy)

proc dragAndDrop*(chain: ActionChain, source: Element, deltaX, deltaY: float): ActionChain =
  chain.clickAndHold(source)
       .moveMouseBy(deltaX, deltaY)
       .release()

proc dragAndDrop*(
  chain: ActionChain,
  selector: string,
  deltaX, deltaY: float,
  locationStrategy = CssSelector
): ActionChain =
  chain.clickAndHold(selector, locationStrategy=locationStrategy)
       .moveMouseBy(deltaX, deltaY)
       .release()

proc keyDown*(chain: ActionChain, key: Key | Rune): ActionChain =
  if chain.session.w3c:
    chain.addW3CAction(createKeyDown(key))
  else:
    chain.addAction(Command.SendKeysToActiveElement, createKeyDown(key))

proc keyUp*(chain: ActionChain, key: Key | Rune): ActionChain =
  if chain.session.w3c:
    chain.addW3CAction(createKeyUp(key))
  else:
    chain.addAction(Command.SendKeysToActiveElement, createKeyUp(key))

proc keyDown*(chain: ActionChain, key: Key | Rune, element: Element): ActionChain =
  if chain.session.w3c:
    chain.click(element).addW3CAction(createKeyDown(key))
  else:
    chain.click(element).addAction(Command.SendKeysToActiveElement, createKeyDown(key))

proc keyDown*(
  chain: ActionChain,
  key: Key | Rune,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  if chain.session.w3c:
    chain.click(selector, locationStrategy).addW3CAction(createKeyDown(key))
  else:
    chain.click(selector, locationStrategy).addAction(Command.SendKeysToActiveElement, createKeyDown(key))

proc keyUp*(chain: ActionChain, key: Key | Rune, element: Element): ActionChain =
  if chain.session.w3c:
    chain.click(element).addW3CAction(createKeyUp(key))
  else:
    chain.click(element).addAction(Command.SendKeysToActiveElement, createKeyUp(key))

proc keyUp*(
  chain: ActionChain,
  key: Key | Rune,
  selector: string,
  locationStrategy = CssSelector
): ActionChain =
  if chain.session.w3c:
    chain.click(selector, locationStrategy).addW3CAction(createKeyUp(key))
  else:
    chain.click(selector, locationStrategy).addAction(Command.SendKeysToActiveElement, createKeyUp(key))

proc convertKeyRuneString*(key: Key | Rune | string): string {.inline.} = $key

proc sendKeys*(chain: ActionChain, keys: varargs[string, convertKeyRuneString]): ActionChain =
  let res = keys.join("")
  if chain.session.w3c:
    for key in res.runes:
      discard chain.keyDown(key).keyUp(key)
  else:
    discard chain.addAction(Command.SendKeysToActiveElement, createKeyDown(res))
  chain

proc sendKeys*(chain: ActionChain, element: Element, keys: varargs[string, convertKeyRuneString]): ActionChain =
  chain.click(element).sendKeys(keys)

proc sendKeys*(
  chain: ActionChain,
  selector: string,
  keys: varargs[string, convertKeyRuneString]
): ActionChain =
  let locationStrategy = CssSelector
  chain.click(selector, locationStrategy=locationStrategy).sendKeys(keys)

proc sendKeys*(
  chain: ActionChain,
  selector: string,
  locationStrategy = CssSelector,
  keys: varargs[string, convertKeyRuneString]
): ActionChain =
  chain.click(selector, locationStrategy=locationStrategy).sendKeys(keys)

proc clearActions*(chain: ActionChain): ActionChain =
  ## Clears the queued actions after ``perform`` is called. Only works
  ## for drivers that are W3C Compliant
  if chain.session.w3c:
    chain.session.clearActions()
  chain

proc actionToJson(chain: ActionChain, action: Action, debugMouseMove = false): JsonTree =
  let isW3C = chain.session.w3c
  case action.ty
  of akKeyUp, akKeyDown:
    if isW3C:
      %*{
        "type": $action.ty,
        "value": action.strValue
      }
    else:
      %*{"value": action.strValue}
  of akPointerPause, akKeyPause:
    if isW3C:
      %*{
        "type": $action.ty,
        "value": action.intValue,
        # Some drivers need this (Safari)
        "duration": action.intValue
      }
    else:
      %*{}
  of akPointerCancel:
    if isW3C:
      %*{"type": $action.ty}
    else:
      %*{}
  of akPointerUp, akPointerDown:
    if isW3C:
      %*{
        "type": $action.ty,
        "duration": action.clickDuration,
        "button": action.button.int
      }
    else:
      %*{}
  of akPointerMove:
    case action.origin.kind
    of okViewPort, okPointer:
      if isW3C:
        %*{
          "type": $action.ty,
          "duration": action.moveDuration,
          "x": action.x.int,
          "y": action.y.int,
          "origin": $action.origin
        }
      else:
        %*{
          "xoffset": action.x.int,
          "yoffset": action.y.int
        }
    of okElementSelector:
      let selector = action.origin.selector
      let locationStrategy = action.origin.locationStrategy
      chain.waitForElement():
        let x = action.x.int #(action.x + element.rect.width/2).int
        let y = action.y.int #(action.y + element.rect.height/2).int
        if debugMouseMove:
          discard chain.session.executeScript(DEBUG_MOUSE_MOVE_SCRIPT, element, x, y)
        if isW3C:
          %*{
            "type": $action.ty,
            "duration": action.moveDuration,
            "x": x,
            "y": y,
            "origin": %element
          }
        else:
          if action.x.int > 0 and action.y.int > 0:
            %*{
              "element": element.id,
              "xoffset": x,
              "yoffset": y
            }
          else:
            %*{
              "element": element.id
            }
    of okElement:
      let element = Element(id: action.origin.elementId, session: chain.session)
      let x = action.x.int#(action.x + element.rect.width/2).int
      let y = action.y.int#(action.y + element.rect.height/2).int
      if debugMouseMove:
        discard chain.session.executeScript(DEBUG_MOUSE_MOVE_SCRIPT, element, x, y)
      if isW3C:
        %*{
          "type": $action.ty,
          "duration": action.moveDuration,
          "x": x,
          "y": y,
          "origin": {
            "element-6066-11e4-a52e-4f735466cecf": action.origin.elementId
          }
        }
      else:
        if action.x.int > 0 and action.y.int > 0:
          %*{
            "element": action.origin.elementId,
            "xoffset": action.x.int,
            "yoffset": action.y.int
          }
        else:
          %*{
            "element": action.origin.elementId,
          }

proc createNewW3CActions(
  chain: ActionChain,
  keyActions: seq[Action],
  pointerActions: seq[Action],
  pointerType = ptMouse,
  debugMouseMove = false
): JsonTree =
  result = %*{
    "actions": [
      {
        "type": $stKey,
        "id": $genUUID(),
        "actions": keyActions.mapIt(chain.actionToJson(it, debugMouseMove=debugMouseMove))
      },
      {
        "type": $stPointer,
        "id": $genUUID(),
        "parameters": { "pointerType": $pointerType },
        "actions": pointerActions.mapIt(chain.actionToJson(it, debugMouseMove=debugMouseMove))
      }
    ]
  }

proc perform*(chain: ActionChain, debugMouseMove = false): ActionChain {.discardable.} =
  ## Perform all of the queued actions in the chain
  if chain.session.w3c:
    var pointerActions: seq[Action]
    var keyActions: seq[Action]
    for i in 0 ..< chain.w3cKeyActions.len:
      let keyAction = chain.w3cKeyActions[i]
      let pointerAction = chain.w3cPointerActions[i]

      case pointerAction.ty
      of akPointerMove:
        case pointerAction.origin.kind
        of okElementSelector:
          if pointerActions.len > 0 or keyActions.len > 0:
            discard chain.session.execute(
              Command.W3CActions,
              chain.createNewW3CActions(keyActions, pointerActions, debugMouseMove=debugMouseMove)
            )
          keyActions = @[keyAction]
          pointerActions = @[pointerAction]
          continue
        else:
          discard
      else:
        discard
      pointerActions.add(pointerAction)
      keyActions.add(keyAction)

    if pointerActions.len > 0 or keyActions.len > 0:
      discard chain.session.execute(
        Command.W3CActions,
        chain.createNewW3CActions(keyActions, pointerActions, debugMouseMove=debugMouseMove)
      )
  else:
    for (command, action) in chain.actions:
      case command
      of Command.Pause:
        case action.ty
        of akPointerPause, akKeyPause:
          sleep(action.intValue)
        else:
          discard
      else:
        discard chain.session.execute(command, chain.actionToJson(action))
  chain

##################################### ELEMENT PROCS ###########################################

proc w3c*(element: Element): bool =
  return element.session.driver.w3c

proc `%`*(element: Element): JsonNode =
  result = %*{
    "ELEMENT": element.id,
    "element-6066-11e4-a52e-4f735466cecf": element.id
  }

proc execute*(element: Element, command: Command, params: JsonNode = %*{}, stopOnException = true): JsonTree =
  var newParams = params.copy
  newParams["elementId"] = %element.id
  newParams["sessionId"] = %element.session.id
  try:
    result = element.session.driver.execute(command, newParams)
  except Exception as exc:
    if stopOnException:
      echo &"Unexpected exception caught while executing command {$command}. Message: {exc.msg}"
      echo "Closing session..."
      element.session.stop()
    raise exc

proc attribute*(element: Element, name: string): string =
  element.execute(Command.GetElementAttribute, %*{"name": name}).unwrap

proc property*(element: Element, name: string): string =
  element.execute(Command.GetElementProperty, %*{"name": name}).unwrap

proc findElement*(element: Element, selector: string, strategy = CssSelector): Option[Element] =
  try:
    let response = element.execute(
      Command.FindChildElement,
      getSelectorParams(element.session, selector, strategy),
      stopOnException = false
    )
    return some(response["value"].toElement(element.session))
  except NoSuchElementException:
    return none(Element)

proc findElements*(element: Element, selector: string, strategy = CssSelector): seq[Element] =
  try:
    let response = element.execute(
      Command.FindChildElements,
      getSelectorParams(element.session, selector, strategy),
      stopOnException = false
    )
    for elementNode in response["value"].items:
      result.add(elementNode.toElement(element.session))
  except NoSuchElementException:
    return @[]

proc takeScreenshotBase64*(element: Element): string =
  element.execute(Command.ElementScreenshot).unwrap

proc takeScreenshotPng*(element: Element): string =
  base64.decode(element.takeScreenshotBase64())

proc saveScreenshotTo*(element: Element, filename: string): string =
  let png = element.takeScreenShotPng()
  try:
    filename.writeFile(png)
  except Exception as exc:
    # TODO: Move this to a logging module
    echo fmt"Could not save image '{filename}'. Error: {exc.msg}"

proc sendKeys*(element: Element, keys: varargs[string, convertKeyRuneString]) =
  let text = keys.join("")
  discard element.execute(Command.SendKeysToElement, %*{"text": text})

proc clear*(element: Element) =
  discard element.execute(Command.ClearElement)

proc click*(element: Element) =
  discard element.execute(Command.ClickElement)

proc submit*(element: Element) =
  if element.w3c:
    let form = element.findElement("./ancestor-or-self::form", strategy=XPathSelector)
    discard element.session.executeScript("""
      var e = arguments[0].ownerDocument.createEvent('Event');
      e.initEvent('submit', true, true);
      if (arguments[0].dispatchEvent(e)) { arguments[0].submit() };
    """, form)
  else:
    discard element.execute(Command.SubmitElement)

proc uploadFile*(element: Element, filename: string) =
  let zfile = mktempUnsafe()
  defer: zfile.removeFile

  var z: ZipArchive
  discard z.open(zfile, fmWrite)
  z.addFile(filename.extractFilename, filename)
  z.close()

  let bytes = base64.encode(zfile.readFile())

  let value = element.execute(Command.UploadFile, %*{"file": bytes}).unwrap(string)
  element.sendKeys(value)

proc text*(element: Element): string =
  ## Returns the element's text, regardless of visibility
  element.property("innerText").strip()

proc visibleText*(element: Element): string =
  element.execute(Command.GetElementText).unwrap

proc value*(element: Element): string =
  element.execute(Command.GetElementValue).unwrap

proc tagName*(element: Element): string =
  element.execute(Command.GetElementTagName).unwrap

proc selected*(element: Element): bool =
  element.execute(Command.IsElementSelected).unwrap

proc enabled*(element: Element): bool =
  element.execute(Command.IsElementEnabled).unwrap

proc displayed*(element: Element): bool =
  element.execute(Command.IsElementDisplayed).unwrap

proc location*(element: Element): tuple[x, y: float] =
  ## Returns the x, y coordinates of the element. Element is not
  ## scrolled into view first, so it might be outside of the visible
  ## page
  if element.w3c:
    element.session.executeScript("""
      return arguments[0].getBoundingClientRect();
    """, element).unwrap
  else:
    element.execute(Command.GetElementLocation).unwrap

proc locationWhenScrolledTo*(element: Element): tuple[x, y: float] =
  ## Returns the x, y coordinates of the element once scrolled into view
  if element.w3c:
    element.session.executeScript("""
      arguments[0].scrollIntoView(true); return arguments[0].getBoundingClientRect();
    """, element).unwrap
  else:
    element.execute(Command.GetElementLocationOnceScrolledIntoView).unwrap

proc size*(element: Element): tuple[width, height: float] =
  if element.w3c:
    element.execute(Command.GetElementRect).unwrap
  else:
    element.execute(Command.GetElementSize).unwrap

proc rect*(element: Element): Rect =
  if element.w3c:
    element.execute(Command.GetElementRect).unwrap
  else:
    let size = element.size()
    let location = element.location()
    (x: location.x, y: location.y, width: size.width, height: size.height)

proc x*(element: Element): float =
  element.rect.x

proc y*(element: Element): float =
  element.rect.y

proc width*(element: Element): float =
  element.rect.width

proc height*(element: Element): float =
  element.rect.height

proc cssPropertyValue*(element: Element, name: string): string =
  element.execute(Command.GetElementValueOfCssProperty, %*{"name": name}).unwrap

proc `$`*(element: Element): string =
  let tag = element.session.executeScript("""
    let element = arguments[0];
    var openTag = "<"+element.tagName.toLowerCase();
    for (var i = 0; i < element.attributes.length; i++) {
        var attrib = element.attributes[i];
        openTag += " "+attrib.name + '="' + attrib.value+ '"';
    }
    openTag += ">";
    return openTag;
  """, element).to(string)
  &"Element({tag})"

################################## Firefox Commands #########################################

proc checkFirefox(self: Session) =
  if self.driver.browser != BrowserKind.Firefox:
    self.quit()
    raise newWebDriverException("You must be using the Firefox webdriver in order to use this command")

proc firefoxContext*(self: Session): string =
  self.checkFirefox
  self.execute(Command.GetContext).unwrap

proc `firefoxContext=`*(self: Session, context: string) =
  self.checkFirefox
  discard self.execute(Command.SetContext, %*{"context": context})

proc firefoxInstallAddon*(self: Session, addonPath: string, temporary = false): string =
  self.checkFirefox
  ## Returns the id of the addon
  self.execute(Command.InstallAddon, %*{"path": addonPath, "temporary": false}).unwrap

proc firefoxUninstallAddon*(self: Session, id: string) =
  self.checkFirefox
  discard self.execute(Command.UninstallAddon, %*{"id": id})

proc firefoxFullPageScreenshotBase64*(self: Session): string =
  self.execute(Command.FullPageScreenshot).unwrap

proc firefoxFullPageScreenshotPng*(self: Session): string =
  base64.decode(self.firefoxFullPageScreenshotBase64())

proc firefoxSaveFullPageScreenShotTo*(self: Session, filename: string): string =
  let png = self.firefoxFullPageScreenshotPng()
  try:
    filename.writeFile(png)
  except Exception as exc:
    # TODO: Move this to a logging module
    echo fmt"Could not save image '{filename}'. Error: {exc.msg}"

################################## Chrome Commands #########################################

proc checkChrome(self: Session) =
  if self.driver.browser != BrowserKind.Chrome:
    self.quit()
    raise newWebDriverException("You must be using the Chrome webdriver in order to use this command")

proc chromeLaunchApp*(self: Session, appId: string) =
  self.checkChrome
  discard self.execute(Command.LaunchApp, %*{"id": appId})

proc chromeNetworkConditions*(self: Session): NetworkConditions =
  self.checkChrome
  self.execute(Command.GetNetworkConditions).unwrap

proc `chromeNetworkConditions=`*(self: Session, networkConditions: NetworkConditions) =
  self.checkChrome
  var payload = %*{
    "offline": networkConditions.offline,
    "latency": networkConditions.latency,
    "download_throughput": networkConditions.downloadThroughput,
    "upload_throughput": networkConditions.uploadThroughput
  }
  discard self.execute(Command.SetNetworkConditions, payload)

proc chromeSinks*(self: Session): seq[string] =
  self.checkChrome
  self.execute(Command.GetSinks).unwrap

proc `chromeSink=`*(self: Session, sinkName: string) =
  self.checkChrome
  discard self.execute(Command.SetSinkToUse, %*{"sinkName": sinkName})

proc chromeStartTabMirroring*(self: Session, sinkName: string) =
  self.checkChrome
  discard self.execute(Command.StartTabMirroring, %*{"sinkName": sinkName})

proc chromeStopCasting*(self: Session, sinkName: string) =
  self.checkChrome
  discard self.execute(Command.StopCasting, %*{"sinkName": sinkName})

proc chromeIssueMessage*(self: Session): string =
  self.checkChrome
  discard self.execute(Command.GetIssueMessage).unwrap

proc chromeExecuteCDPCommand*(self: Session, cmd: string, args: JsonNode): JsonTree =
  self.checkChrome
  discard self.execute(Command.ExecuteCdpCommand, %*{"cmd": cmd, "params": args}).unwrap

################################## Safari Commands #########################################

proc checkSafari(self: Session) =
  if self.driver.browser != BrowserKind.Safari:
    self.quit()
    raise newWebDriverException("You must be using the Safari webdriver in order to use this command")

proc safariPermissions*(self: Session): Table[string, bool] =
  self.checkSafari
  self.execute(Command.GetPermissions).unwrap(JsonNode)["permissions"].unwrap

proc `safariPermissions=`*(self: Session, perms: Table[string, bool]) =
  self.checkSafari
  discard self.execute(Command.SetPermissions, %*{"permissions": perms})

proc safariSetPermission*(self: Session, key: string, value: bool) =
  self.checkSafari
  self.safariPermissions = {key: value}.toTable

proc safariDebug*(self: Session) =
  self.checkSafari
  discard self.execute(Command.AttachDebugger)
  discard self.executeScript("debugger;")
