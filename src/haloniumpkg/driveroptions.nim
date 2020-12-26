import json, options, os, base64, strformat, strutils

type
  PageLoadStrategy* = enum
    plsNone = "none"
    plsNormal = "normal"
    plsEager = "eager"

  ElementScrollBehavior* = enum
    esbTop
    esbBottom

template assign(node: JsonNode, key: string, value: untyped) =
  when value is Option:
    if value.isSome:
      node[key] = %($value.get)
  else:
    node[key] = %value

proc chromeOptions*(
  args: openArray[string] = [],
  extensions: openArray[string] = [],
  binary = none(string),
  debuggerAddress = none(string),
  pageLoadStrategy = none(PageLoadStrategy),
  experimentalOptions = %*{},
  additionalCapabilities = %*{}
): JsonNode =
  let opts = experimentalOptions.copy
  opts.assign("args", args)
  opts.assign("binary", binary)
  opts.assign("debuggerAddress", debuggerAddress)

  var loadedExtensions = newSeqOfCap[string](extensions.len())
  for ext in extensions:
    let newPath = ext.expandTilde().expandFilename()
    if newPath.fileExists:
      loadedExtensions.add(base64.encode(newPath.readFile()))
    else:
      raise newException(IOError, &"Could not find extension at: '{newPath}'")

  opts.assign("extensions", loadedExtensions)

  result = additionalCapabilities.copy
  result.assign("goog:chromeOptions", opts)
  result.assign("pageLoadStrategy", pageLoadStrategy)

proc edgeOptions*(
  args: openArray[string] = [],
  extensions: openArray[string] = [],
  binary = none(string),
  debuggerAddress = none(string),
  pageLoadStrategy = option(plsNormal),
  experimentalOptions = %*{},
  useChromium = false,
  additionalCapabilities = %*{}
): JsonNode =
  if useChromium:
    result = chromeOptions(
      args, extensions, binary, debuggerAddress, pageLoadStrategy,
      experimentalOptions, additionalCapabilities
    )
  else:
    result = additionalCapabilities.copy
    result.assign("platform", "windows")

  result.assign("ms:edgeChromium", useChromium)

proc firefoxOptions*(
  args: openArray[string] = [],
  pageLoadStrategy = option(plsNormal),
  binary = none(string),
  acceptInsecureCerts = none(bool),
  logLevel = none(string),
  additionalCapabilities = %*{}
): JsonNode =
  ## TODO: Support firefox profile + addons
  let opts = %*{}
  opts.assign("args", args)
  opts.assign("binary", binary)
  opts.assign("log", %*{"level": logLevel})

  result = additionalCapabilities.copy
  result.assign("moz:firefoxOptions", opts)
  result.assign("pageLoadStrategy", pageLoadStrategy)
  result.assign("acceptInsecureCerts", acceptInsecureCerts)

proc ieOptions*(
  args: openArray[string] = [],
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
  let opts = additionalOptions.copy
  opts.assign("ie.browserCommandLineSwitches", args.join(" "))
  opts.assign("browserAttachTimeout", browserAttachTimeout)
  opts.assign("elementScrollBehavior", elementScrollBehavior)
  opts.assign("ie.ensureCleanSession", ensureCleanSession)
  opts.assign("ie.fileUploadDialogTimeout", fileUploadDialogTimeout)
  opts.assign("ie.forceCreateProcessApi", forceCreateProcessApi)
  opts.assign("ie.forceShellWindowsApi", forceShellWindowsApi)
  opts.assign("ie.enableFullPageScreenshot", fullPageScreenshot)
  opts.assign("ignoreProtectedModeSettings", ignoreProtectedModeSettings)
  opts.assign("ignoreZoomSetting", ignoreZoomLevel)
  opts.assign("initialBrowserUrl", initialBrowserUrl)
  opts.assign("nativeEvents", nativeEvents)
  opts.assign("enablePersistentHover", persistentHover)
  opts.assign("requireWindowFocus", requireWindowFocus)
  opts.assign("ie.usePerProcessProxy", usePerProcessProxy)
  opts.assign("ie.validateCookieDocumentType", validateCookieDocumentType)

  result = %*{"se:ieOptions": opts}

proc webkitGTKOptions*(
  args: openArray[string] = [],
  binary = none(string),
  pageLoadStrategy = option(plsNormal),
  overlayScrollbars = none(bool),
  additionalCapabilities = %*{}
): JsonNode =
  let opts = %*{}
  opts.assign("args", args)
  opts.assign("binary", binary)
  opts.assign("useOverlayScrollbars", overlayScrollbars)

  result = additionalCapabilities.copy
  result.assign("webkitgtk:browserOptions", opts)
  result.assign("pageLoadStrategy", pageLoadStrategy)

proc wpeWebkitOptions*(
  args: openArray[string] = [],
  binary = none(string),
  additionalCapabilities = %*{}
): JsonNode =
  let opts = %*{}
  opts.assign("args", args)
  opts.assign("binary", binary)

  result = additionalCapabilities.copy
  result.assign("wpe:browserOptions", opts)

proc operaOptions*(
  args: openArray[string] = [],
  pageLoadStrategy = option(plsNormal),
  androidPackageName = none(string),
  androidDeviceSocket = none(string),
  androidCommandLineFile = none(string),
  additionalCapabilities = %*{}
): JsonNode =
  let opts = %*{}
  opts.assign("args", args)
  opts.assign("androidPackage", androidPackageName)
  opts.assign("androidDeviceSocket", androidDeviceSocket)
  opts.assign("androidCommandLineFile", androidCommandLineFile)

  result = additionalCapabilities.copy
  result.assign("pageLoadStrategy", pageLoadStrategy)
  result.assign("operaOptions", opts)
