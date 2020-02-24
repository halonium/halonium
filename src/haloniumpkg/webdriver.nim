# For reference, this is brilliant: https://github.com/jlipps/simple-wd-spec

import httpclient, uri, json, tables, options, strutils, unicode, sequtils

import exceptions

type
  WebDriver* = ref object
    url*: Uri
    client*: HttpClient

  Session* = object
    driver: WebDriver
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
    CssSelector, LinkTextSelector, PartialLinkTextSelector, TagNameSelector,
    XPathSelector

proc `%`*(element: Element): JsonNode =
  result = %*{
    "ELEMENT": element.id,
    # This key is taken from the selenium python code. Not
    # sure why they picked it, but it works
    "element-6066-11e4-a52e-4f735466cecf": element.id
  }

proc toKeyword(strategy: LocationStrategy): string =
  case strategy
  of CssSelector: "css selector"
  of LinkTextSelector: "link text"
  of PartialLinkTextSelector: "partial link text"
  of TagNameSelector: "tag name"
  of XPathSelector: "xpath"

proc checkResponse(resp: string): JsonNode =
  result = parseJson(resp)
  if result{"value"}.isNil:
    raise newException(WebDriverException, $result)

proc newWebDriver*(url: string = "http://localhost:4444"): WebDriver =
  WebDriver(url: url.parseUri, client: newHttpClient())

proc createSession*(self: WebDriver): Session =
  ## Creates a new browsing session.

  # Check the readiness of the Web Driver.
  let resp = self.client.getContent($(self.url / "status"))
  let obj = parseJson(resp)
  let ready = obj{"value", "ready"}

  if ready.isNil():
    let msg = "Readiness message does not follow spec"
    raise newException(ProtocolException, msg)

  if not ready.getBool():
    raise newException(WebDriverException, "WebDriver is not ready")

  # Create our session.
  let sessionReq = %*{"capabilities": {"browserName": "firefox"}}
  let sessionResp = self.client.postContent($(self.url / "session"),
                                            $sessionReq)
  let sessionObj = parseJson(sessionResp)
  let sessionId = sessionObj{"value", "sessionId"}
  if sessionId.isNil():
    raise newException(ProtocolException, "No sessionId in response to request")

  return Session(id: sessionId.getStr(), driver: self)

proc close*(self: Session) =
  let reqUrl = $(self.driver.url / "session" / self.id)
  let resp = self.driver.client.request(reqUrl, HttpDelete)

  let respObj = checkResponse(resp.body)

proc navigate*(self: Session, url: string) =
  ## Instructs the session to navigate to the specified URL.
  let reqUrl = $(self.driver.url / "session" / self.id / "url")
  let obj = %*{"url": url}
  let resp = self.driver.client.postContent(reqUrl, $obj)

  let respObj = parseJson(resp)
  if respObj{"value"}.getFields().len != 0:
    raise newException(WebDriverException, $respObj)

proc getPageSource*(self: Session): string =
  ## Retrieves the specified session's page source.
  let reqUrl = $(self.driver.url / "session" / self.id / "source")
  let resp = self.driver.client.getContent(reqUrl)

  let respObj = checkResponse(resp)

  return respObj{"value"}.getStr()

proc findElement*(self: Session, selector: string,
                  strategy = CssSelector): Option[Element] =
  let reqUrl = $(self.driver.url / "session" / self.id / "element")
  let reqObj = %*{"using": toKeyword(strategy), "value": selector}
  let resp = self.driver.client.post(reqUrl, $reqObj)
  if resp.status == Http404:
    return none(Element)

  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  let respObj = checkResponse(resp.body)

  for key, value in respObj["value"].getFields().pairs():
    return some(Element(id: value.getStr(), session: self))

proc findElements*(self: Session, selector: string,
                  strategy = CssSelector): seq[Element] =
  let reqUrl = $(self.driver.url / "session" / self.id / "elements")
  let reqObj = %*{"using": toKeyword(strategy), "value": selector}
  let resp = self.driver.client.post(reqUrl, $reqObj)
  if resp.status == Http404:
    return @[]

  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  let respObj = checkResponse(resp.body)

  for element in respObj["value"].to(seq[JsonNode]):
    for key, value in element.getFields().pairs():
      result.add(Element(id: value.getStr(), session: self))

proc getText*(self: Element): string =
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "text")
  let resp = self.session.driver.client.getContent(reqUrl)
  let respObj = checkResponse(resp)

  return respObj["value"].getStr()

proc getAttribute*(self: Element, name: string): string =
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "attribute" / name)
  let resp = self.session.driver.client.getContent(reqUrl)
  let respObj = checkResponse(resp)

  return respObj["value"].getStr()

proc getProperty*(self: Element, name: string): string =
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "property" / name)
  let resp = self.session.driver.client.getContent(reqUrl)
  let respObj = checkResponse(resp)

  return respObj["value"].getStr()

proc clear*(self: Element) =
  ## Clears an element of text/input
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "clear")
  let obj = %*{}
  let resp = self.session.driver.client.post(reqUrl, $obj)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  discard checkResponse(resp.body)

proc click*(self: Element) =
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "click")
  let obj = %*{}
  let resp = self.session.driver.client.post(reqUrl, $obj)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  discard checkResponse(resp.body)

# Note: There currently is an open bug in geckodriver that causes DOM events not to fire when sending keys.
# https://github.com/mozilla/geckodriver/issues/348
proc sendKeys*(self: Element, text: string) =
  let reqUrl = $(self.session.driver.url / "session" / self.session.id /
                 "element" / self.id / "value")
  let obj = %*{"text": text}
  let resp = self.session.driver.client.post(reqUrl, $obj)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  discard checkResponse(resp.body)

type
  # https://w3c.github.io/webdriver/#keyboard-actions
  Key* = enum
    Unidentified = 0,
    Cancel,
    Help,
    Backspace,
    Tab,
    Clear,
    Return,
    Enter,
    Shift,
    Control,
    Alt,
    Pause,
    Escape

proc toUnicode(key: Key): Rune =
  Rune(0xE000 + ord(key))

proc press*(self: Session, keys: varargs[Key]) =
  let reqUrl = $(self.driver.url / "session" / self.id / "actions")
  let obj = %*{"actions": [
    {
      "type": "key",
      "id": "keyboard",
      "actions": []
    }
  ]}
  for key in keys:
    obj["actions"][0]["actions"].elems.add(
      %*{
        "type": "keyDown",
        "value": $toUnicode(key)
      }
    )
    obj["actions"][0]["actions"].elems.add(
      %*{
        "type": "keyUp",
        "value": $toUnicode(key)
      }
    )

  let resp = self.driver.client.post(reqUrl, $obj)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  discard checkResponse(resp.body)

proc takeScreenshot*(self: Session): string =
  let reqUrl = $(self.driver.url / "session" / self.id / "screenshot")
  let resp = self.driver.client.getContent(reqUrl)
  let respObj = checkResponse(resp)

  return respObj["value"].getStr()

proc internalExecute(self: Session, code: string, args: varargs[JsonNode], kind: string): JsonNode =
  let reqUrl = $(self.driver.url / "session" / self.id / "execute" / kind)
  let obj = %*{
    "script": code,
    "args": []
  }
  for arg in args:
    obj["args"].elems.add arg

  let resp = self.driver.client.post(reqUrl, $obj)
  let respObj = checkResponse(resp.body)
  if respObj["value"].hasKey("error"):
    raise newException(JavascriptException, respObj["value"]["message"].getStr & "\n" & respObj["value"]["stacktrace"].getStr)

  return respObj["value"]

proc execute*(self: Session, code: string, args: varargs[JsonNode]): JsonNode =
  self.internalExecute(code, args, "sync")

proc executeAsync*(self: Session, code: string, args: varargs[JsonNode]): JsonNode =
  self.internalExecute(code, args, "async")

proc execute*(self: Session, code: string, args: varargs[Element]): JsonNode =
  self.internalExecute(code, args.mapIt(%it), "sync")

proc executeAsync*(self: Session, code: string, args: varargs[Element]): JsonNode =
  self.internalExecute(code, args.mapIt(%it), "async")

proc addCookie*(self: Session, cookie: Cookie) =
  let reqUrl = $(self.driver.url / "session" / self.id / "cookie")
  let obj = %*  {
    "cookie": {
      "name": cookie.name,
      "value": cookie.value,
    }
  }
  if cookie.path.isSome:
    obj["path"] = cookie.path.get.newJString()
  if cookie.domain.isSome:
    obj["domain"] = cookie.domain.get.newJString()
  if cookie.secure.isSome:
    obj["secure"] = cookie.secure.get.newJBool()
  if cookie.httpOnly.isSome:
    obj["httpOnly"] = cookie.httpOnly.get.newJBool()
  if cookie.expiry.isSome:
    obj["expiry"] = cookie.expiry.get.newJInt()

  let resp = self.driver.client.post(reqUrl, $obj)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

proc getCookie*(self: Session, name: string): Cookie =
  let reqUrl = $(self.driver.url / "session" / self.id / "cookie" / name)

  let resp = self.driver.client.get(reqUrl)

  let cookie = checkResponse(resp.body)["value"]
  result = Cookie(name: cookie["name"].getStr, value: cookie["value"].getStr)
  if cookie.hasKey("path"):
    result.path = some(cookie["path"].getStr)
  if cookie.hasKey("domain"):
    result.domain = some(cookie["domain"].getStr)
  if cookie.hasKey("secure"):
    result.secure = some(cookie["secure"].getBool)
  if cookie.hasKey("httpOnly"):
    result.httpOnly = some(cookie["httpOnly"].getBool)
  if cookie.hasKey("expiry"):
    result.expiry = some(cookie["expiry"].getBiggestInt)

proc deleteCookie*(self: Session, name: string): Cookie =
  let reqUrl = $(self.driver.url / "session" / self.id / "cookie" / name)

  let resp = self.driver.client.delete(reqUrl)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

proc getAllCookies*(self: Session): seq[Cookie] =
  let reqUrl = $(self.driver.url / "session" / self.id / "cookie")

  let resp = self.driver.client.get(reqUrl)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

  let respObj = checkResponse(resp.body)
  for cookie in respObj["value"].items:
    var final = Cookie(name: cookie["name"].getStr, value: cookie["value"].getStr)
    if cookie.hasKey("path"):
      final.path = some(cookie["path"].getStr)
    if cookie.hasKey("domain"):
      final.domain = some(cookie["domain"].getStr)
    if cookie.hasKey("secure"):
      final.secure = some(cookie["secure"].getBool)
    if cookie.hasKey("httpOnly"):
      final.httpOnly = some(cookie["httpOnly"].getBool)
    if cookie.hasKey("expiry"):
      final.expiry = some(cookie["expiry"].getBiggestInt)

    result.add final

proc deleteAllCookies*(self: Session): Cookie =
  let reqUrl = $(self.driver.url / "session" / self.id / "cookie")

  let resp = self.driver.client.delete(reqUrl)
  if resp.status != Http200:
    raise newException(WebDriverException, resp.status)

when isMainModule:
  let webDriver = newWebDriver()
  let session = webDriver.createSession()
  let amazonUrl = "https://www.amazon.co.uk/Nintendo-Classic-Mini-" &
                  "Entertainment-System/dp/B073BVHY3F"
  session.navigate(amazonUrl)

  echo session.findElement("#priceblock_ourprice").get().getText()

  session.close()