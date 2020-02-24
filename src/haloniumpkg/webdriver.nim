# For reference, this is brilliant: https://github.com/jlipps/simple-wd-spec

import httpclient, uri, json, tables, options, strutils, sequtils, base64, strformat

import unicode except strip
import exceptions, service, errorhandler, version, commands, utils

type
  WebDriver* = ref object
    url*: Uri
    client*: HttpClient
    service*: Service
    keepAlive*: bool
    w3c*: bool

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
    CssSelector = "css selector"
    LinkTextSelector = "link text"
    PartialLinkTextSelector = "partial link text"
    TagNameSelector = "tag name"
    XPathSelector = "xpath"

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
    body = response.body
  var
    status = response.code.int

  if status >= Http300.int and status < Http304.int:
    return self.request(HttpGet, response.headers["location"])
  if status > 399 and status <= Http500.int:
    return %*{
      "status": status,
      "value": body
    }

  let contentTypes = response.headers.getOrDefault("Content-Type").split(';')
  var isPng = false

  for ct in contentTypes:
    if ct.startsWith("image/png"):
      isPng = true
      break

  if isPng:
    return %*{"status": ErrorCode.Success.int, "value": body}
  else:
    try:
      result = parseJson(body)
    except:
      if status > 199 and status < Http300.int:
        status = ErrorCode.Success.int
      else:
        status = ErrorCode.UnknownError.int
      return %*{"status": status, "value": body.strip()}

proc execute(self: WebDriver, command: Command, params: openArray[(string, string)]): JsonNode =
  var commandInfo: CommandEndpointTuple
  try:
    commandInfo = self.service.getCommandTuple(command)
  except:
    raise newWebDriverException(fmt"Command '{$command}' could not be found.")

  let filledUrl = commandInfo[1].multiReplace(params)

  var newParams: seq[(string, string)]
  if self.w3c:
    for param in params:
      if param[0] != "$sessionId":
        newParams.add(param)
  else:
    newParams = @params

  let
    data = newParams.toJson
    url = fmt"{self.service.url}{filledUrl}"

  result = self.request(commandInfo[0], url, data)