import osproc, os, streams, strformat, sequtils, strtabs, httpclient, threadpool, tables, json

import utils, exceptions, commands, browser

when defined(windows):
  import winlean
  const
    ENOENT = ERROR_FILE_NOT_FOUND
    EACCES = ERROR_ACCESS_DENIED
else:
  import posix

type
  Service* = ref object
    path*: string
    args*: seq[string]
    port*: int
    logPath*: string
    logFile: File
    env*: StringTableRef
    case kind*: BrowserKind
    of Firefox, InternetExplorer:
      logLevel*: string
    else:
      discard
    host: string
    startupMessage*: string
    process: Process
    pchannel: Channel[bool]

proc getDevNull*(): string =
  when defined(windows):
    "NUL"
  else:
    "/dev/null"

proc getAllEnv(): StringTableRef =
  result = newStringTable()
  for key, val in envPairs():
    result[key] = val

proc getDriverExe(kind: BrowserKind): string =
  case kind
  of Firefox:
    "geckodriver"
  of Chrome, Chromium:
    "chromedriver"
  of Edge:
    "MicrosoftWebDriver.exe"
  of InternetExplorer:
    "IEDriverServer.exe"
  of Opera:
    "operadriver"
  of Safari:
    "/usr/bin/safaridriver"
  of PhantomJs:
    "phantomjs"
  of WebkitGTK:
    "WebKitWebDriver"
  of Android:
    raise newWebdriverException(
      NoSuchServiceExecutableException,
      "There is no service executable for Android. Please use a remote webdriver instead."
    )

proc desiredCapabilities*(kind: BrowserKind): JsonNode =
  case kind
  of Firefox:
    %*{
      "browserName": "firefox",
      "acceptInsecureCerts": true
    }
  of Chrome, Chromium:
    %*{
      "browserName": "chrome",
      "version": "",
      "platform": "ANY"
    }
  of Edge:
    %*{
      "browserName": "MicrosoftEdge",
      "version": "",
      "platform": "ANY"
    }
  of InternetExplorer:
    %*{
      "browserName": "internet explorer",
      "version": "",
      "platform": "WINDOWS"
    }
  of Opera:
    %*{
      "browserName": "opera",
      "version": "",
      "platform": "ANY"
    }
  of Safari:
    %*{
      "browserName": "safari",
      "version": "",
      "platform": "MAC"
    }
  of PhantomJs:
    %*{
      "browserName": "phantomjs",
      "version": "",
      "platform": "ANY",
      "javascriptEnabled": true
    }
  of Android:
    %*{
      "browserName": "android",
      "version": "",
      "platform": "ANDROID"
    }
  of WebkitGTK:
    %*{
      "browserName": "MiniBrowser",
      "version": "",
      "platform": "ANY"
    }

proc getStartupMessage(kind: BrowserKind): string =
  case kind
  of Chrome, Chromium:
    "Please see https://chromedriver.chromium.org/home"
  of InternetExplorer:
    "Please download from http://selenium-release.storage.googleapis.com/index.html"
  else:
    ""

proc newService*(
  kind: BrowserKind,
  path="",
  port=freePort(),
  env=getAllEnv(),
  args=newSeq[string](),
  logPath=getDevNull(),
  startupMessage="",
  logLevel="fatal"
): Service =
  result = Service(
    kind: kind,
    path: if path.len > 0: path else: getDriverExe(kind),
    port: port,
    env: env,
    host: "127.0.0.1",
    args: args,
    logPath: logPath,
    startupMessage: if startupMessage.len > 0: startupMessage else: getStartupMessage(kind)
  )
  result.pchannel.open()

  if kind in {InternetExplorer, Firefox}:
    result.logLevel = logLevel

proc commandLineArgs(service: Service): seq[string] =
  ## Gets command line args for the service executable
  case service.kind:
  of Firefox:
    result = @["--port", $service.port].concat(service.args)
    if service.logLevel.len > 0:
      result.add(@["--log", $service.logLevel])
    if service.host.len > 0:
      result.add(@["--host", service.host])
  of Chromium, Chrome:
    result = @["--port", $service.port].concat(service.args)
    if service.logPath.len > 0:
      result.add(@["--log-path", service.logPath])
    if service.logLevel.len > 0:
      result.add(@["--log-level", service.logLevel])
  of InternetExplorer:
    result = @["--port", $service.port].concat(service.args)
    if service.logPath.len > 0:
      result.add(@["--log-file", service.logPath])
    if service.logLevel.len > 0:
      result.add(@["--log-level", service.logLevel])
    if service.host.len > 0:
      result.add(@["--host", service.host])
  of WebkitGTK:
    result = @["-p", $service.port].concat(service.args)
  of PhantomJs:
    result = @["--webdriver", $service.port].concat(service.args)
  else:
    result = service.args

proc getCommandTuple*(kind: BrowserKind, command: Command): CommandEndpointTuple =
  case kind
  of Firefox:
    FirefoxCommandTable[command]
  of Chrome, Chromium:
    ChromiumCommandTable[command]
  of Safari:
    SafariCommandTable[command]
  else:
    BaseCommandTable[command]

proc getCommandTuple*(service: Service, command: Command): CommandEndpointTuple =
  return getCommandTuple(service.kind, command)

proc url*(service: Service): string =
  case service.kind
  of PhantomJs, Android:
    fmt"http://{joinHostPort(service.host, service.port)}/wd/hub"
  else:
    fmt"http://{joinHostPort(service.host, service.port)}"

proc isConnectable(service: Service): bool =
  result = utils.isConnectable(service.port)

proc sendRemoteShutdown(service: Service) =
  try:
    let client = newHttpClient()
    discard client.getContent(fmt"{service.url}/shutdown")
    client.close()
  except:
    return

  for _ in 0 ..< 30:
    if not service.isConnectable():
      break
    else:
      sleep(1000)

proc stop*(service: Service) =
  ## Stops the service sub-process and closes the log file
  runnableExamples:
    let service = newService(BrowserKind.Firefox)
    # do something with the service
    service.close()

  try:
    service.logFile.close()
  except Exception:
    discard

  if service.process.isNil:
    return

  service.sendRemoteShutdown()

  try:
    service.process.close()
    service.process.terminate()
    discard service.process.waitForExit(1)
    service.process.kill()
  except OSError:
    discard

proc watchOutput(service: Service) =
  let stream = service.process.outputStream

  try:
    case service.logPath
    of "stdout":
      service.logFile = stdout
    of "stderr":
      service.logFile = stderr
    else:
      service.logFile = open(service.logPath, fmReadWrite)

    while service.process.running and (not stream.atEnd):
      let line = stream.readLine()
      service.logFile.writeLine(line)
  finally:
    service.logFile.close()

proc assertProcessIsStillRunning(service: Service) =
  if not service.process.running:
    raise newException(WebDriverException, &"Service {service.path} unexpectedly exited. \n{service.process.outputStream.readAll}")

proc start*(service: Service) =
  ## Starts the driver service and logs the output to `service.logPath`.
  ##
  ## Raises a WebDriverException when the service could not be connected to
  runnableExamples:
    let service = newService(Firefox)
    service.start()

    let service2 = newService(
      Chrome,
      path="customchromedriver",
      port=55000,
      env={"PATH", "/my/env/path"}.newStringTable,
      args=@["--verbose", "--adb-port", "8980"],
      logPath="/my/log/path",
      startupMessage="This is a custom chrome driver",
      logLevel="ALL"
    )

    service2.start()

  try:
    service.process = startProcess(
      service.path,
      args=service.commandLineArgs(),
      env=service.env,
      options={
        poUsePath,
        poStdErrToStdOut
      }
    )
  except OSError as exc:
    if exc.errorCode == ENOENT:
      raise newWebdriverException(fmt"'{service.path}' needs to be in PATH. {service.startupMessage}")
    elif exc.errorCode == EACCES:
      raise newException(
        WebDriverException,
        fmt"'{service.path}' may have the wrong permissions. Please set binary as executable and readable by the current user."
      )
  except Exception as exc:
    raise newWebDriverException(fmt"'{service.path}' needs to be in PATH. {service.startupMessage}. Error: {exc.msg}")

  var count = 0
  while true:
    service.assertProcessIsStillRunning()

    if service.isConnectable():
      break
    count += 1
    sleep(1000)
    if count >= 30:
      raise newWebDriverException(fmt"Cannot connect to service {service.path}. \l{service.process.outputStream.readAll}")
  spawn service.watchOutput()