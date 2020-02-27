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

  Element* = object
    session: Session
    id*: string

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

proc w3c*(element: Element): bool =
  return element.session.driver.w3c

proc `%`*(element: Element): JsonNode =
  result = %*{
    "ELEMENT": element.id,
    "element-6066-11e4-a52e-4f735466cecf": element.id
  }

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

proc stop*(session: Session)

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

proc execute(self: Session, command: Command, params = %*{}): JsonNode =
  params["sessionId"] = %self.id
  try:
    result = self.driver.execute(command, params)
  except Exception as exc:
    echo "Unexpected exception caught. Closing session..."
    self.stop()
    raise exc

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

proc text*(element: Element): string =
  element.execute(Command.GetElementText)["value"].getStr("")

proc attribute*(element: Element, name: string): string =
  element.execute(Command.GetElementAttribute, %*{"name": name})["value"].getStr("")

proc property*(element: Element, name: string): string =
  element.execute(Command.GetElementProperty, %*{"name": name})["value"].getStr("")

proc getDriverUri(kind: BrowserKind, url: string): Uri =
  case kind
  of Android, PhantomJs:
    if "wd/hub" notin url:
      parseUri(url) / "wd" / "hub"
    else:
      parseUri(url)
  else:
    parseUri(url)

proc newRemoteWebDriver*(kind: BrowserKind, url = "http://localhost:4444", keepAlive = true): WebDriver =
  result = WebDriver(url: getDriverUri(kind, url), browser: kind, client: newHttpClient(), keepAlive: keepAlive)

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

  if self.driver.w3c:
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
    for key, value in response["value"].getFields().pairs():
      return some(Element(id: value.getStr(), session: self))
  except NoSuchElementException:
    return none(Element)

proc findElements*(self: Session, selector: string, strategy = CssSelector): seq[Element] =
  try:
    let response = self.execute(Command.FindElements, getSelectorParams(self, selector, strategy))
    for element in response["value"].to(seq[JsonNode]):
      for key, value in element.getFields().pairs():
        result.add(Element(id: value.getStr(), session: self))
  except NoSuchElementException:
    return @[]

proc currentWindowHandle*(self: Session): string =
  if self.driver.w3c:
    self.execute(Command.W3CGetCurrentWindowHandle)["value"].getStr("")
  else:
    self.execute(Command.GetCurrentWindowHandle)["value"].getStr("")

proc navigate*(self: Session, url: string) =
  let response = self.execute(Command.Get, %*{"url": %url})
  if response{"value"}.getFields().len != 0:
    raise newWebDriverException($response)

proc clear*(element: Element) =
  discard element.execute(Command.ClearElement)

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