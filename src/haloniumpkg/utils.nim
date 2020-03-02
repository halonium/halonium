import net, strformat, strutils, json, regex, sequtils, strtabs, os
import nativesockets

import exceptions

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

proc toJson*[T, U](vals: openArray[(T, U)]): JsonNode =
  ## Generic constructor for JSON data. Creates a new ``JObject JsonNode``.
  result = newJObject()
  for val in vals:
    result[$val[0]] = %val[1]

proc toJson*(obj: object | tuple): JsonNode =
  ## Generic constructor for JSON data. Creates a new ``JObject JsonNode``.
  result = newJObject()
  for field, val in obj.fieldPairs:
    result[field] = %val

proc replace*(str: string, node: JsonNode): string =
  let matches = str.findAll(re"\$(\w+)")
  let keys = matches.mapIt(str[it.group(0)[0]])

  var vals: seq[(string, string)]

  for key in keys:
    if not node.hasKey(key):
      raise newException(URLTemplateException, fmt"Key '{key}' not found in JsonData")
    if node[key].kind != JString:
      raise newException(URLTemplateException, fmt"Key '{key}' is not a string")

    vals.add(("$" & key, node[key].getStr()))

  result = str.multiReplace(vals)

proc getDevNull*(): string =
  when defined(windows):
    "NUL"
  else:
    "/dev/null"

proc getAllEnv*(): StringTableRef =
  result = newStringTable()
  for key, val in envPairs():
    result[key] = val