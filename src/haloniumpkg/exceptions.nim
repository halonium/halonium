import packedjson

type
  WebDriverException* = object of CatchableError
    ## Base webdriver exception
    screen*: JsonNode
    stacktrace*: seq[string]
    alertText*: string

  DriverException* = object of WebDriverException
    ## Thrown when there is an error thrown by the driver itself.
    ## IE: An invalid web page is loaded

  URLTemplateException* = object of CatchableError
    ## Thrown when there are not enough parameters for a string
    ## substitution

  NoSuchServiceExecutableException* = object of WebDriverException

  ProtocolException* = object of WebDriverException

  InvalidSwitchToTargetException* = object of WebDriverException
    ## Thrown when frame or window target to be switched doesn't exist.

  NoSuchFrameException* = object of InvalidSwitchToTargetException
    ## Thrown when frame target to be switched doesn't exist.

  NoSuchWindowException* = object of InvalidSwitchToTargetException
    ## Thrown when window target to be switched doesn't exist.
    ## To find the current set of active window handles, you can get a list
    ## of the active window handles in the following way::
    ##     print driver.window_handles

  NoSuchElementException* = object of WebDriverException
    ## Thrown when element could not be found.
    ## If you encounter this exception, you may want to check the following:
    ##     * Check your selector used in your find_by...
    ##     * Element may not yet be on the screen at the time of the find operation,
    ##       (webpage is still loading) see selenium.webdriver.support.wait.WebDriverWait()
    ##       for how to write a wait wrapper to wait for an element to appear.

  NoSuchAttributeException* = object of WebDriverException
    ## Thrown when the attribute of element could not be found.
    ## You may want to check if the attribute exists in the particular browser you are
    ## testing against.  Some browsers may have different property names for the same
    ## property.  (IE8's .innerText vs. Firefox .textContent)

  StaleElementReferenceException* = object of WebDriverException
    ## Thrown when a reference to an element is now "stale".
    ## Stale means the element no longer appears on the DOM of the page.
    ## Possible causes of StaleElementReferenceException include, but not limited to:
    ##     * You are no longer on the same page, or the page may have refreshed since the element
    ##       was located.
    ##     * The element may have been removed and re-added to the screen, since it was located.
    ##       Such as an element being relocated.
    ##       This can happen typically with a javascript framework when values are updated and the
    ##       node is rebuilt.
    ##     * Element may have been inside an iframe or another context which was refreshed.

  InvalidElementStateException* = object of WebDriverException
    ## Thrown when a command could not be completed because the element is in an invalid state.
    ## This can be caused by attempting to clear an element that isn't both editable and resettable.

  InvalidElementCoordinatesException* = object of WebDriverException

  UnexpectedAlertPresentException* = object of WebDriverException
    ## Thrown when an unexpected alert has appeared.
    ## Usually raised when  an unexpected modal is blocking the webdriver from executing
    ## commands.

  NoAlertPresentException* = object of WebDriverException
    ## Thrown when switching to no presented alert.
    ## This can be caused by calling an operation on the Alert() class when an alert is
    ## not yet on the screen.

  ElementNotVisibleException* = object of InvalidElementStateException
    ## Thrown when an element is present on the DOM, but
    ## it is not visible, and so is not able to be interacted with.
    ## Most commonly encountered when trying to click or read text
    ## of an element that is hidden from view.

  ElementNotInteractableException* = object of InvalidElementStateException
    ## Thrown when an element is present in the DOM but interactions
    ## with that element will hit another element do to paint order

  ElementNotSelectableException* = object of InvalidElementStateException
    ## Thrown when trying to select an unselectable element.
    ## For example, selecting a 'script' element.

  InvalidCookieDomainException* = object of WebDriverException
    ## Thrown when attempting to add a cookie under a different domain
    ## than the current URL.

  UnableToSetCookieException* = object of WebDriverException
    ## Thrown when a driver fails to set a cookie.

  RemoteDriverServerException* = object of WebDriverException

  TimeoutException* = object of WebDriverException
    ## Thrown when a command does not complete in enough time.

  MoveTargetOutOfBoundsException* = object of WebDriverException
    ## Thrown when the target provided to the `ActionsChains` move()
    ## method is invalid, i.e. out of document.

  UnexpectedTagNameException* = object of WebDriverException
    ## Thrown when a support class did not get an expected web element.

  InvalidSelectorException* = object of NoSuchElementException
    ## Thrown when the selector which is used to find an element does not return
    ## a WebElement. Currently this only happens when the selector is an xpath
    ## expression and it is either syntactically invalid (i.e. it is not a
    ## xpath expression) or the expression does not select WebElements
    ## (e.g. "count(//input)").

  ImeNotAvailableException* = object of WebDriverException
    ## Thrown when IME support is not available. This exception is thrown for every IME-related
    ## method call if IME support is not available on the machine.

  ImeActivationFailedException* = object of WebDriverException
    ## Thrown when activating an IME engine has failed.

  InvalidArgumentException* = object of WebDriverException
    ## The arguments passed to a command are either invalid or malformed.

  JavascriptException* = object of WebDriverException
    ## An error occurred while executing JavaScript supplied by the user.

  NoSuchCookieException* = object of WebDriverException
    ## No cookie matching the given path name was found amongst the associated cookies of the
    ## current browsing context's active document.

  ScreenshotException* = object of WebDriverException
    ## A screen capture was made impossible.

  ElementClickInterceptedException* = object of WebDriverException
    ## The Element Click command could not be completed because the element receiving the events
    ## is obscuring the element that was requested clicked.

  InsecureCertificateException* = object of WebDriverException
    ## Navigation caused the user agent to hit a certificate warning, which is usually the result
    ## of an expired or invalid TLS certificate.

  InvalidCoordinatesException* = object of WebDriverException
    ## The coordinates provided to an interactions operation are invalid.

  InvalidSessionIdException* = object of WebDriverException
    ## Occurs if the given session id is not in the list of active sessions, meaning the session
    ## either does not exist or that it's not active.

  SessionNotCreatedException* = object of WebDriverException
    ## A new session could not be created.

  MethodNotAllowedException* = object of WebDriverException

  UnknownMethodException* = object of WebDriverException
    ## The requested command matched a known URL but did not match any methods for that URL.

template newWebDriverException*(
  exceptn: typedesc = WebDriverException,
  message: string = "",
  parentException: ref Exception = nil,
  scrn: JsonNode = newJNull(),
  stcktrace: seq[string] = @[]
): untyped =
  var res = newException(exceptn, message, parentException)
  res.screen = scrn
  res.stacktrace = stcktrace
  res

template newWebDriverException*(
  message: string = "",
  parentException: ref Exception = nil,
  scrn: JsonNode = newJNull(),
  stcktrace: seq[string] = @[]
): untyped =
  newWebDriverException(WebDriverException, message, parentException, scrn, stcktrace)
