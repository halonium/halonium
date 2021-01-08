import net, strformat, strutils, json, strtabs, os
import nativesockets

import exceptions

const DEBUG_MOUSE_MOVE_SCRIPT* = """
  var id = "haloniumMouseDebugging";
  var dotID = "haloniumMouseDebuggingDot";
  var descID = "haloniumMouseDebuggingDescription";
  var element = arguments[0];
  var x = arguments[1];
  var y = arguments[2];
  var rect = element.getBoundingClientRect();

  var el, redDot, description;
  if (document.getElementById(id) == null) {
    el = document.createElement("div");
    redDot = document.createElement("div");
    description = document.createElement("div");
    el.appendChild(redDot);
    el.appendChild(description);

    el.id = id;
    redDot.id = dotID;
    description.id = descID;

    el.style.position = "absolute";
    el.style.zIndex = "100000000";
    el.style.display = "flex";
    el.style.pointerEvents = "none";

    redDot.style.borderRadius = "5px";
    redDot.style.border = "2px solid red";
    redDot.style.backgroundColor = "red";
    redDot.style.width = "5px";
    redDot.style.height = "5px";
    redDot.style.display = "inline-block";
    redDot.style.pointerEvents = "none";
    redDot.style.marginRight = "5px";

    description.style.display = "inline-block";
    description.style.border = "1px solid black";
    description.style.backgroundColor = "white";
    description.style.borderRadius = "3px";
    description.style.pointerEvents = "none";
    description.style.paddingLeft = "5px";
    description.style.paddingRight = "5px";

    document.body.appendChild(el);
  } else {
    el = document.getElementById(id);
    redDot = document.getElementById(dotID);
    description = document.getElementById(descID);
  }
  el.style.top = (rect.top + y) + "px";
  el.style.left = (rect.left + x) + "px";
  description.innerHTML = "Moved to (x: " + el.style.left + ", y: " + el.style.top + ")";
  console.log(x);
  console.log(y);
  console.log(element);
"""

proc freePort*(): int =
  ## Gets an open port on localhost
  var socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  socket.bindAddr()
  socket.listen(5)
  result = socket.getLocalAddr()[1].int
  socket.close()

proc createConnection*(address: tuple[host: string, port: int], timeout=1000): Socket =
  let info = getAddrInfo(address.host, address.port.Port)
  if info.isNil:
    raise newException(WebdriverException, "getAddrInfo returned nil!")
  var sock: Socket
  var err: ref Exception
  let
    family = info.ai_family
    socktype = info.ai_socktype
    proto = info.ai_protocol

  try:
    sock = newSocket(family, socktype, proto)
    sock.connect(address.host, address.port.Port, timeout)
    return sock
  except Exception as exc:
    err = exc
    if not sock.isNil:
      sock.close()
  finally:
    freeAddrInfo(info)

  if not err.isNil:
    raise err

proc isConnectable*(port: int, host="localhost"): bool =
  try:
    var sock = createConnection((host, port), 1000)
    result = true
    sock.close()
  except:
    discard

proc joinHostPort*(host: string, port: int): string =
  if ':' in host and not host.startsWith('['):
    return fmt"[{host}]:{port}"
  return fmt"{host}:{port}"

proc `%`*(obj: tuple): JsonNode =
  ## Generic constructor for JSON data. Creates a new ``JObject JsonNode``.
  result = newJObject()
  for field, val in obj.fieldPairs:
    result[field] = %val

proc replace*(str: string, node: JsonNode): string =
  var keyVals: seq[(string, string)]
  var isKey = false
  for x in tokenize(str, {'$', '/'}):
    if x.isSep and x.token.endsWith('$'):
      isKey = true
    elif isKey and not x.isSep:
      isKey = false
      if not node.hasKey(x.token):
        raise newException(URLTemplateException, fmt"Key '{x.token}' not found in JsonData")
      if node[x.token].kind != JString:
        raise newException(URLTemplateException, fmt"Key '{x.token}' is not a string")
      keyVals.add(("$" & x.token, node[x.token].getStr()))
  result = str.multiReplace(keyVals)

proc getDevNull*(): string =
  when defined(windows):
    "NUL"
  else:
    "/dev/null"

proc getAllEnv*(): StringTableRef =
  result = newStringTable()
  for key, val in envPairs():
    result[key] = val
