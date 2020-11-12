import exceptions, packedjson, strutils, strformat

type
  ErrorCode* = enum
    Success = 0
    NoSuchElement = (7, "no such element")
    NoSuchFrame = (8, "no such frame")
    UnknownCommand = (9, "unknown command")
    StaleElementReference = (10, "stale element reference")
    ElementNotVisible = (11, "element not visible")
    InvalidElementState = (12, "invalid element state")
    UnknownError = (13, "unknown error")
    ElementIsNotSelectable = (15, "element not selectable")
    JavascriptError = (17, "javascript error")
    XpathLookupError = (19, "invalid selector")
    Timeout = (21, "timeout")
    NoSuchWindow = (23, "no such window")
    InvalidCookieDomain = (24, "invalid cookie domain")
    UnableToSetCookie = (25, "unable to set cookie")
    UnexpectedAlertOpen = (26, "unexpected alert open")
    NoAlertOpen = (27, "no such alert")
    ScriptTimeout = (28, "script timeout")
    InvalidElementCoordinates = (29, "invalid element coordinates")
    ImeNotAvailable = (30, "ime not available")
    ImeEngineActivationFailed = (31, "ime engine activation failed")
    InvalidSelector = (32, "invalid selector")
    SessionNotCreated = (33, "session not created")
    MoveTargetOutOfBounds = (34, "move target out of bounds")
    InvalidXpathSelector = (51, "invalid selector")
    InvalidXpathSelectorReturnTyper = (52, "invalid selector")
    ElementNotInteractable = (60, "element not interactable")
    InvalidArgument = (61, "invalid argument")
    NoSuchCookie = (62, "no such cookie")
    UnableToCaptureScreen = (63, "unable to capture screen")
    ElementClickIntercepted = (64, "element click intercepted")
    InsecureCertificate = ("insecure certificate")
    InvalidCoordinates = ("invalid coordinates")
    InvalidSessionId = ("invalid session id")
    UnknownMethod = ("unknown method exception")
    MethodNotAllowed = (405, "unsupported operation")
    GenericError

proc getError(jsonNode: JsonNode): ErrorCode =
  if jsonNode.kind == JInt:
    result = jsonNode.getInt().ErrorCode
  elif jsonNode.kind == JString:
    for i in 0 ..< int(ErrorCode.high):
      if $cast[ErrorCode](i) == jsonNode.getStr(""):
        return cast[ErrorCode](i)
    result = GenericError
  else:
    result = GenericError

template createException(status: JsonNode): untyped =
  let error = getError(status)
  case error
  of NoSuchElement:
    newWebDriverException(NoSuchElementException)
  of NoSuchFrame:
    newWebDriverException(NoSuchFrameException)
  of StaleElementReference:
    newWebDriverException(StaleElementReferenceException)
  of ElementNotVisible:
    newWebDriverException(ElementNotVisibleException)
  of InvalidElementState:
    newWebDriverException(InvalidElementStateException)
  of ElementIsNotSelectable:
    newWebDriverException(ElementNotSelectableException)
  of JavascriptError:
    newWebDriverException(JavascriptException)
  of Timeout, ScriptTimeout:
    newWebDriverException(TimeoutException)
  of NoSuchWindow:
    newWebDriverException(NoSuchWindowException)
  of InvalidCookieDomain:
    newWebDriverException(InvalidCookieDomainException)
  of UnableToSetCookie:
    newWebDriverException(UnableToSetCookieException)
  of UnexpectedAlertOpen:
    newWebDriverException(UnexpectedAlertPresentException)
  of NoAlertOpen:
    newWebDriverException(NoAlertPresentException)
  of InvalidElementCoordinates:
    newWebDriverException(InvalidElementCoordinatesException)
  of ImeNotAvailable:
    newWebDriverException(ImeNotAvailableException)
  of ImeEngineActivationFailed:
    newWebDriverException(ImeActivationFailedException)
  of InvalidSelector, InvalidXpathSelector, InvalidXpathSelectorReturnTyper:
    newWebDriverException(InvalidSelectorException)
  of SessionNotCreated:
    newWebDriverException(SessionNotCreatedException)
  of MoveTargetOutOfBounds:
    newWebDriverException(MoveTargetOutofBoundsException)
  of ElementNotInteractable:
    newWebDriverException(ElementNotInteractableException)
  of InvalidArgument:
    newWebDriverException(InvalidArgumentException)
  of NoSuchCookie:
    newWebDriverException(NoSuchCookieException)
  of UnableToCaptureScreen:
    newWebDriverException(ScreenshotException)
  of ElementClickIntercepted:
    newWebDriverException(ElementClickInterceptedException)
  of InsecureCertificate:
    newWebDriverException(InsecureCertificateException)
  of InvalidCoordinates:
    newWebDriverException(InvalidCoordinatesException)
  of InvalidSessionId:
    newWebDriverException(InvalidSessionIdException)
  of UnknownMethod:
    newWebDriverException(UnknownMethodException)
  of MethodNotAllowed:
    newWebDriverException(MethodNotAllowedException)
  of UnknownError:
    newWebDriverException(DriverException)
  else:
    newWebDriverException()

proc checkResponse*(response: JsonNode) =
  var
    status = response{"status"}.copy
    message = response{"message"}.getStr("")
    screen: JsonTree
    value: JsonTree

  let
    isInt = (status.kind != JNull and status.kind == JInt)

  if status.kind != JNull or (isInt and status.getInt() == ErrorCode.Success.int):
    return

  if isInt:
    let valueJson = response{"value"}
    if valueJson.kind != JNull and valueJson.kind == JString:
      try:
        value = parseJson(valueJson.getStr(""))
      except JsonParsingError:
        discard
      if value.kind != JNull:
        if value.len == 1:
          value = value["value"].copy

        status = value{"error"}.copy
        if status.kind == JNull:
          status = value["status"].copy
          let nmessage = value["value"]
          if nmessage.kind != JString:
            value = nmessage.copy
            message = nmessage{"message"}.getStr("")

  var exception = createException(status)

  if value.kind == JNull or (value.kind == JString and value.getStr("").len == 0):
    value = response["value"].copy
  if value.kind == JString:
    exception.msg = value.getStr("")
    raise exception

  if message.len == 0 and value.hasKey("message"):
    message = value["message"].getStr("")

  screen = value{"screen"}.copy

  let stValue = if value.hasKey("stackTrace"): value["stackTrace"] else: value{"stacktrace"}
  var stacktrace: seq[string]

  if stValue.kind != JNull:
    if stValue.kind == JString:
      stacktrace = stValue.getStr("").split('\n')
    elif stValue.kind == JArray:
      for node in stValue.items():
        let line = node{"lineNumber"}.getStr("")
        var file = node{"fileName"}.getStr("<anonymous>")

        if line.len > 0:
          file = fmt"{file}:{line}"

        var meth = node{"methodName"}.getStr("<anonymous>")
        if node.hasKey("className"):
          let className = node["className"]
          meth = fmt"{className}.{meth}"

        stacktrace.add(fmt"    at {meth} ({file})")

  if getError(status) == UnexpectedAlertOpen:
    var alertText: string
    if value.hasKey("data"):
      alertText = value["data"]{"text"}.getStr("")
    elif value.hasKey("alert"):
      alertText = value["alert"]{"text"}.getStr("")

    exception.alertText = alertText
    raise exception

  exception.msg = message
  exception.screen = screen
  exception.stacktrace = stacktrace

  raise exception
