import net, strformat, strutils
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