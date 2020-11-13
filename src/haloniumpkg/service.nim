import osproc, os, streams, strformat, sequtils, strtabs, httpclient, strutils, tables, json
import options
import tempfile

import utils, exceptions, commands, browser

when defined(windows):
  import winlean
  const
    ENOENT = ERROR_FILE_NOT_FOUND
    EACCES = ERROR_ACCESS_DENIED
else:
  import posix

const SERVICE_CHECK_INTERVAL = 100
const SERVICE_RETRY_LIMIT = (30 * SERVICE_CHECK_INTERVAL/10).int

type
  Service* = ref object
    path*: string
    args*: seq[string]
    port*: int
    logPath*: string
    logFile: File
    env*: StringTableRef
    case kind*: BrowserKind
    of Firefox, InternetExplorer, Chrome, Chromium:
      logLevel*: string
    else:
      discard
    host: string
    startupMessage*: string
    process: Process

var backgroundThread: Thread[Service]

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
  of WPEWebkit:
    "WPEWebDriver"
  of Android:
    raise newWebdriverException(
      NoSuchServiceExecutableException,
      "There is no service executable for Android. Please use a remote webdriver instead."
    )

# TODO: Make this use Options or something
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
  of WPEWebkit:
    %*{
      "browserName": "MiniBrowser",
      "version": "",
      "platform": "ANY",
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
  path=none(string),
  port=freePort(),
  env=getAllEnv(),
  args=newSeq[string](),
  logPath=getDevNull(),
  startupMessage="",
  logLevel=""
): Service =
  result = Service(
    kind: kind,
    path: if path.isSome: path.get else: getDriverExe(kind),
    port: port,
    env: env,
    host: "127.0.0.1",
    args: args,
    logPath: logPath,
    startupMessage: if startupMessage.len > 0: startupMessage else: getStartupMessage(kind)
  )

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
    result = @[fmt"--port={$service.port}"].concat(service.args)
    if service.logPath.len > 0:
      result.add(fmt"--log-path={service.logPath}")
    if service.logLevel.len > 0:
      result.add(fmt"--log-level={service.logLevel}")
  of InternetExplorer:
    result = @[fmt"--port={$service.port}"].concat(service.args)
    if service.logPath.len > 0:
      result.add(fmt"--log-file={service.logPath}")
    if service.logLevel.len > 0:
      result.add(fmt"--log-level={service.logLevel}")
    if service.host.len > 0:
      result.add(fmt"--host={service.host}")
  of Safari:
    result = @["--port", $service.port].concat(service.args)
  of WebkitGTK, WPEWebkit:
    result = @["-p", $service.port].concat(service.args)
  of PhantomJs:
    result = @[fmt"--webdriver={$service.port}"].concat(service.args)
    let cookiesInArgs = result.anyIt(it.startsWith("--cookies-file"))
    if not cookiesInArgs:
      result.add(fmt"--cookies-file={mktempUnsafe()}")
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
  ## Returns the url that the service is running at
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

proc watchOutput(service: Service) {.thread.} =
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
      raise newWebDriverException(fmt"'{service.path}' could not be found in your PATH environment variable. {service.startupMessage}")
    elif exc.errorCode == EACCES:
      raise newWebDriverException(
        fmt"'{service.path}' may have the wrong permissions. Please set binary as executable and readable by the current user."
      )
    else:
      raise newWebDriverException(fmt"{exc.msg}. {service.startupMessage}")
  except Exception as exc:
    raise newWebDriverException(fmt"'{service.path}' could not be found in your PATH environment variable. {service.startupMessage}. Error: {exc.msg}")

  var count = 0
  while true:
    service.assertProcessIsStillRunning()

    if service.isConnectable():
      break
    count += 1
    sleep(SERVICE_CHECK_INTERVAL)
    if count >= SERVICE_RETRY_LIMIT:
      raise newWebDriverException(fmt"Cannot connect to service {service.path}. \l{service.process.outputStream.readAll}")
  createThread(backgroundThread, watchOutput, service)
