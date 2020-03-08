import json, options, os, base64, strformat, strutils

type
  PageLoadStrategy* = enum
    plsNone = "none"
    plsNormal = "normal"
    plsEager = "eager"

  ElementScrollBehavior* = enum
    esbTop
    esbBottom

proc chromeOptions*(
  args: seq[string] = @[],
  pageLoadStrategy: PageLoadStrategy = plsNormal,
  extensions: seq[string] = @[],
  binary = none(string),
  debuggerAddress = none(string),
  experimentalOptions = %*{}
): JsonNode =
  let opts = experimentalOptions.copy()
  opts["args"] = %args
  opts["pageLoadStrategy"] = %($pageLoadStrategy)
  opts["binary"] = %binary
  opts["debuggerAddress"] = %debuggerAddress

  var loadedExtensions = newSeqOfCap[string](extensions.len())
  for ext in extensions:
    let newPath = ext.expandTilde().expandFilename()
    if newPath.existsFile:
      loadedExtensions.add(base64.encode(newPath.readFile()))
    else:
      raise newException(IOError, &"Could not find extension at: '{newPath}'")

  opts["extensions"] = %loadedExtensions

  for key in opts.keys:
    if opts[key].kind == JNull:
      opts.delete(key)

  result = %*{"goog:chromeOptions": opts}

proc edgeOptions*(
  args: seq[string] = @[],
  pageLoadStrategy: PageLoadStrategy = plsNormal,
  isLegacy = false,
  customBrowserName = none(string)
): JsonNode =
  let opts = %*{}
  opts["args"] = %args
  if isLegacy:
    opts["pageLoadStrategy"] = %($pageLoadStrategy)
  else:
    opts["browserName"] = %customBrowserName

  for key in opts.keys:
    if opts[key].kind == JNull:
      opts.delete(key)
  result = %*{"ms:edgeOptions": opts}

proc firefoxOptions*(
  args: seq[string] = @[],
  pageLoadStrategy: PageLoadStrategy = plsNormal,
  binary = none(string),
  logLevel = none(string)
): JsonNode =
  ## TODO: Support firefox profile + addons
  let opts = %*{}
  opts["args"] = %args
  opts["pageLoadStrategy"] = %($pageLoadStrategy)
  opts["binary"] = %binary
  opts["log"] = %*{"level": logLevel}

  for key in opts.keys:
    if opts[key].kind == JNull:
      opts.delete(key)

  result = %*{"moz:firefoxOptions": opts}

proc ieOptions*(
  args: seq[string] = @[],
  browserAttachTimeout = none(int),
  elementScrollBehavior = none(ElementScrollBehavior),
  ensureCleanSession = none(bool),
  fileUploadDialogTimeout = none(int),
  forceCreateProcessApi = none(bool),
  forceShellWindowsApi = none(bool),
  fullPageScreenshot = none(bool),
  ignoreProtectedModeSettings = none(bool),
  ignoreZoomLevel = none(bool),
  initialBrowserUrl = none(string),
  nativeEvents = none(bool),
  persistentHover = none(bool),
  requireWindowFocus = none(bool),
  usePerProcessProxy = none(bool),
  validateCookieDocumentType = none(bool),
  additionalOptions = %*{}
): JsonNode =
  ## TODO: Support firefox profile + addons
  let opts = additionalOptions.copy()
  opts["ie.browserCommandLineSwitches"] = %args.join(" ")
  opts["browserAttachTimeout"] = %browserAttachTimeout
  opts["elementScrollBehavior"] = %elementScrollBehavior
  opts["ie.ensureCleanSession"] = %ensureCleanSession
  opts["ie.fileUploadDialogTimeout"] = %fileUploadDialogTimeout
  opts["ie.forceCreateProcessApi"] = %forceCreateProcessApi
  opts["ie.forceShellWindowsApi"] = %forceShellWindowsApi
  opts["ie.enableFullPageScreenshot"] = %fullPageScreenshot
  opts["ignoreProtectedModeSettings"] = %ignoreProtectedModeSettings
  opts["ignoreZoomSetting"] = %ignoreZoomLevel
  opts["initialBrowserUrl"] = %initialBrowserUrl
  opts["nativeEvents"] = %nativeEvents
  opts["enablePersistentHover"] = %persistentHover
  opts["requireWindowFocus"] = %requireWindowFocus
  opts["ie.usePerProcessProxy"] = %usePerProcessProxy
  opts["ie.validateCookieDocumentType"] = %validateCookieDocumentType

  for key in opts.keys:
    if opts[key].kind == JNull:
      opts.delete(key)

  result = %*{"se:ieOptions": opts}

proc wpeWebkitOptions*(
  args: seq[string] = @[],
  binary = none(string)
): JsonNode =
  let opts = %*{}
  opts["args"] = %args
  opts["binary"] = %binary

  for key in opts.keys:
    if opts[key].kind == JNull:
      opts.delete(key)
  result = %*{"wpe:browserOptions": opts}

# TODO: operaOptions, webkitGTKOptions, wpeWebkit