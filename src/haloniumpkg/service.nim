import osproc, os, streams, strformat, sequtils, strtabs, httpclient, threadpool

import utils, exceptions, commands

when defined(windows):
  import winlean
  const
    ENOENT = ERROR_FILE_NOT_FOUND
    EACCES = ERROR_ACCESS_DENIED
else:
  import posix

type
  ServiceKind* {.pure.} = enum
    Chrome
    Chromium
    Firefox
    Edge
    InternetExplorer
    Opera
    Safari

  Service* = ref object
    path*: string
    args*: seq[string]
    port*: int
    logPath*: string
    logFile: File
    env*: StringTableRef
    case kind*: ServiceKind
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

proc getDriverExe(kind: ServiceKind): string =
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

proc getStartupMessage(kind: ServiceKind): string =
  case kind
  of Chrome, Chromium:
    "Please see https://chromedriver.chromium.org/home"
  of InternetExplorer:
    "Please download from http://selenium-release.storage.googleapis.com/index.html"
  else:
    ""

proc newService*(
  kind: ServiceKind,
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

proc commandLineArgs*(service: Service): seq[string] =
  case service.kind:
  of Firefox:
    result = @["--port", $service.port].concat(service.args)
    if service.logLevel.len > 0:
      result.add(@["--log", $service.logLevel])
    if service.host.len > 0:
      result.add(@["--host", service.host])
  of Chrome:
    result = service.args
  of Chromium:
    result = @["--port", $service.port].concat(service.args)
    if service.logPath.len > 0:
      result.add(@["--log-path", service.logPath])
  of InternetExplorer:
    result = @["--port", $service.port].concat(service.args)
    if service.logPath.len > 0:
      result.add(@["--log-file", service.logPath])
    if service.logLevel.len > 0:
      result.add(@["--log-level", service.logLevel])
    if service.host.len > 0:
      result.add(@["--host", service.host])
  else:
    result = service.args

proc url*(service: Service): string =
  let hostPort = joinHostPort(service.host, service.port)
  fmt"http://{hostPort}"

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
  try:
    service.process = startProcess(
      service.path,
      args=service.commandLineArgs(),
      env=service.env,
      options={
        poEchoCmd,
        poUsePath,
        poStdErrToStdOut
      }
    )
  except OSError as exc:
    if exc.errorCode == ENOENT:
      raise newException(WebDriverException, fmt"'{service.path}' needs to be in PATH. {service.startupMessage}")
    elif exc.errorCode == EACCES:
      raise newException(
        WebDriverException,
        fmt"'{service.path}' may have the wrong permissions. Please set binary as executable and readable by the current user."
      )
  except Exception as exc:
    raise newException(WebDriverException, fmt"'{service.path}' needs to be in PATH. {service.startupMessage}. Error: {exc.msg}")

  var count = 0
  while true:
    service.assertProcessIsStillRunning()

    if service.isConnectable():
      break
    count += 1
    sleep(1000)
    if count >= 30:
      raise newException(WebDriverException, fmt"Cannot connect to service {service.path}. \l{service.process.outputStream.readAll}")
  spawn service.watchOutput()