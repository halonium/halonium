# For reference, this is brilliant: https://github.com/jlipps/simple-wd-spec

import httpclient, uri, json, options, strutils, sequtils, base64, strformat, tables

import unicode except strip
import exceptions, service, errorhandler, commands, utils, browser

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

  Element* = ref object
    session: Session
    id*: string

  WindowKind* {.pure.} = enum
    Tab = "tab"
    Window = "window"

  Window* = object
    handle*: string
    kind*: WindowKind

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

proc stop*(session: Session)
proc execute(self: WebDriver, command: Command, params = %*{}): JsonNode
proc getSelectorParams(self: Session, selector: string, strategy: LocationStrategy): JsonNode
proc `%`*(element: Element): JsonNode

template unwrap(node: JsonNode, ty: untyped): untyped =
  if node.hasKey("value"):
    node["value"].to(ty)
  else:
    node.to(ty)

template unwrap(node: JsonNode): untyped =
  unwrap(node, type(result))

proc toElement*(node: JsonNode, session: Session): Element =
  for key, value in node.getFields().pairs():
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

proc request(self: WebDriver, httpMethod: HttpMethod, url: string, postBody: JsonNode = nil): JsonNode =
  let headers = self.getConnectionHeaders(url, self.keepAlive)

  var bodyString: string

  if not postBody.isNil and httpMethod != HttpPost and httpMethod != HttpPut:
    bodyString = ""
  else:
    bodyString = $postBody

  let
    response = self.client.request(url, httpMethod, bodyString, headers)
    respData = response.body
  var
    status = response.code.int

  if status >= Http300.int and status < Http304.int:
    return self.request(HttpGet, response.headers["location"])
  if status > 399 and status <= Http500.int:
    return %*{
      "status": status,
      "value": respData
    }

  let contentTypes = response.headers.getOrDefault("Content-Type").split(';')
  var isPng = false

  for ct in contentTypes:
    if ct.startsWith("image/png"):
      isPng = true
      break

  if isPng:
    return %*{"status": ErrorCode.Success.int, "value": respData}
  else:
    try:
      result = parseJson(respData.strip())
    except JsonParsingError:
      if status > 199 and status < Http300.int:
        status = ErrorCode.Success.int
      else:
        status = ErrorCode.UnknownError.int
      return %*{"status": status, "value": respData.strip()}

    if not result.hasKey("value"):
      result["value"] = nil

proc newRemoteWebDriver*(kind: BrowserKind, url = "http://localhost:4444", keepAlive = true): WebDriver =
  result = WebDriver(url: getDriverUri(kind, url), browser: kind, client: newHttpClient(), keepAlive: keepAlive)

proc execute(self: WebDriver, command: Command, params = %*{}): JsonNode =
  var commandInfo: CommandEndpointTuple
  try:
    commandInfo = self.browser.getCommandTuple(command)
  except:
    raise newWebDriverException(fmt"Command '{$command}' could not be found.")

  let filledUrl = commandInfo[1].replace(params)

  var data = params
  if self.w3c:
    for key in params.keys():
      if key == "sessionId":
        data.delete(key)

  let
    url = fmt"{self.url}{filledUrl}"

  let response = self.request(commandInfo[0], url, data)
  if not response.isNil:
    checkResponse(response)
    return response

  return %*{
    "success": Success.int,
    "value": nil,
    "sessionId": if not self.session.isNil: self.session.id else: ""
  }

proc getSession(self: WebDriver, kind = RemoteSession): Session =
  let capabilities = desiredCapabilities(self.browser)

  let parameters = %*{
    "capabilities": capabilities,
    "desiredCapabilities": capabilities
  }
  var response = self.execute(Command.NewSession, parameters)
  if not response.hasKey("sessionId"):
    response = response["value"]

  let sessionId = response["sessionId"].getStr()
  self.capabilities = response{"value"}

  if self.capabilities.isNil:
    self.capabilities = response{"capabilities"}
  self.w3c = response{"status"}.isNil

  result = Session(driver: self, id: sessionId, kind: kind)

proc createRemoteSession*(browser: BrowserKind, url = "http://localhost:4444", keepAlive = true): Session =
  let driver = newRemoteWebDriver(browser, url, keepAlive)
  driver.getSession()

proc createRemoteSession*(self: WebDriver): Session =
  self.getSession()

proc createSession*(
  self: WebDriver,
  exePath="",
  port=freePort(),
  env=getAllEnv(),
  args=newSeq[string](),
  logPath=getDevNull(),
  logLevel=""
): Session =
  result = getSession(self, LocalSession)
  result.service = newService(self.browser, exePath, port, env, args, logPath, logLevel=logLevel)

  self.url = result.service.url.parseUri()
  result.service.start()

###################################### SESSION PROCS ##########################################

proc w3c*(self: Session): bool =
  return self.driver.w3c

proc execute(self: Session, command: Command, params = %*{}, stopOnException = true): JsonNode =
  params["sessionId"] = %self.id
  try:
    result = self.driver.execute(command, params)
  except Exception as exc:
    if stopOnException:
      echo "Unexpected exception caught. Closing session..."
      self.stop()
    raise exc

proc status*(self: Session): tuple[message: string, ready: bool] =
  self.execute(Command.Status).unwrap

proc createSession*(
  browser: BrowserKind,
  exePath="",
  port=freePort(),
  env=getAllEnv(),
  args=newSeq[string](),
  logPath=getDevNull(),
  logLevel=""
): Session =
  let service = newService(browser, exePath, port, env, args, logPath, logLevel=logLevel)
  service.start()
  let driver = newRemoteWebDriver(browser, service.url, keepAlive=true)
  result = getSession(driver, LocalSession)
  result.service = service

proc getSelectorParams(self: Session, selector: string, strategy: LocationStrategy): JsonNode =
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
    let response = self.execute(Command.FindElement, getSelectorParams(self, selector, strategy))
    return some(response["value"].toElement(self))
  except NoSuchElementException:
    return none(Element)

proc findElements*(self: Session, selector: string, strategy = CssSelector): seq[Element] =
  try:
    let response = self.execute(Command.FindElements, getSelectorParams(self, selector, strategy))
    for elementNode in response["value"].to(seq[JsonNode]):
      result.add(elementNode.toElement(self))
  except NoSuchElementException:
    return @[]

proc executeScript*(self: Session, code: string, args: varargs[JsonNode, `%`]): JsonNode =
  let params = %*{
    "script": code,
    "args": args
  }
  if self.w3c:
    self.execute(Command.W3CExecuteScript, params)["value"]
  else:
    self.execute(Command.ExecuteScript, params)["value"]

proc executeScriptAsync*(self: Session, code: string, args: varargs[JsonNode, `%`]): JsonNode =
  let params = %*{
    "script": code,
    "args": args
  }
  if self.w3c:
    self.execute(Command.W3CExecuteScriptAsync, params)["value"]
  else:
    self.execute(Command.ExecuteAsyncScript, params)["value"]

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

  Window(handle: handle)

proc windows*(self: Session): seq[Window] =
  var handles: seq[string]
  if self.w3c:
    handles = self.execute(Command.W3CGetWindowHandles).unwrap(seq[string])
  else:
    handles = self.execute(Command.GetWindowHandles).unwrap(seq[string])

  for handle in handles:
    result.add(Window(handle: handle))

proc navigate*(self: Session, url: string) =
  let response = self.execute(Command.Get, %*{"url": %url})
  if response{"value"}.getFields().len != 0:
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
  discard session.execute(Command.Quit)

proc stop*(session: Session) =
  session.close()
  case session.kind
  of LocalSession:
    session.service.stop()
  of RemoteSession:
    discard

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

proc newWindow*(self: Session): Window =
  let response = self.execute(Command.NewWindow)["value"]
  result.handle = response["handle"].getStr()
  result.kind = response["type"].getStr().toWindowKind

proc closeCurrentWindow*(self: Session) =
  discard self.execute(Command.Close)

proc closeWindow*(self: Session, window: Window) =
  self.switchToWindow(window)
  discard self.execute(Command.Close)

proc setImplicitWait*(self: Session, waitingTime: float) =
  if self.w3c:
    discard self.execute(Command.SetTimeouts, %*{"implicit": (waitingTime * 1000).int})
  else:
    discard self.execute(Command.ImplicitWait, %*{"ms": (waitingTime * 1000).int})

proc setScriptTimeout*(self: Session, waitingTime: float) =
  if self.w3c:
    discard self.execute(Command.SetTimeouts, %*{"script": (waitingTime * 1000).int})
  else:
    discard self.execute(Command.SetScriptTimeout, %*{"ms": (waitingTime * 1000).int})

proc setPageLoadTimeout*(self: Session, waitingTime: float) =
  try:
    discard self.execute(Command.SetTimeouts, %*{"pageLoad": (waitingTime * 1000).int}, stopOnException = false)
  except WebDriverException:
    discard self.execute(Command.SetTimeouts, %*{"ms": (waitingTime * 1000).int, "type": "page load"})

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

proc setAlertValue*(self: Session, value: string) =
  if self.w3c:
    discard self.execute(Command.W3CSetAlertValue, %*{"value": value, "text": value})
  else:
    discard self.execute(Command.SetAlertValue, %*{"text": value})

proc alertText*(self: Session): string =
  if self.w3c:
    self.execute(Command.W3CGetAlertText).unwrap
  else:
    self.execute(Command.GetAlertText).unwrap


##################################### ELEMENT PROCS ###########################################

proc w3c*(element: Element): bool =
  return element.session.driver.w3c

proc `%`*(element: Element): JsonNode =
  result = %*{
    "ELEMENT": element.id,
    "element-6066-11e4-a52e-4f735466cecf": element.id
  }

proc execute(element: Element, command: Command, params: JsonNode = %*{}): JsonNode =
  var newParams = params
  newParams["elementId"] = %element.id
  newParams["sessionId"] = %element.session.id
  try:
    result = element.session.driver.execute(command, newParams)
  except Exception as exc:
    echo "Unexpected exception caught. Closing session..."
    element.session.stop()
    raise exc

proc attribute*(element: Element, name: string): string =
  element.execute(Command.GetElementAttribute, %*{"name": name}).unwrap

proc property*(element: Element, name: string): string =
  element.execute(Command.GetElementProperty, %*{"name": name}).unwrap

proc findElement*(element: Element, selector: string, strategy = CssSelector): Option[Element] =
  try:
    let response = element.execute(Command.FindChildElement, getSelectorParams(element.session, selector, strategy))
    return some(response["value"].toElement(element.session))
  except NoSuchElementException:
    return none(Element)

proc findElements*(element: Element, selector: string, strategy = CssSelector): seq[Element] =
  try:
    let response = element.execute(Command.FindChildElements, getSelectorParams(element.session, selector, strategy))
    for elementNode in response["value"].to(seq[JsonNode]):
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

proc sendKeys*(element: Element, text: string) =
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
    discard element.execute(Command.SUBMIT_ELEMENT)

proc text*(element: Element): string =
  ## Returns the element's text, regardless of visibility
  element.property("innerText")

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

proc rect*(element: Element): tuple[x, y, width, height: float] =
  if element.w3c:
    element.execute(Command.GetElementRect).unwrap
  else:
    let size = element.size()
    let location = element.location()
    (x: location.x, y: location.y, width: size.width, height: size.height)

proc cssPropertyValue*(element: Element, name: string): string =
  element.execute(Command.GetElementValueOfCssProperty, %*{"name": name}).unwrap