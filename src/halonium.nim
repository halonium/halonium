import os
import haloniumpkg/webdriver
import haloniumpkg/browser

proc main() =
  var service = createSession(Firefox)

  while true:
    sleep(10000)
    service.stop()
    break
main()