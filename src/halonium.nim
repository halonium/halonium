import threadpool, os
import haloniumpkg/webdriver
import haloniumpkg/utils
import haloniumpkg/service
import haloniumpkg/browser

proc main() =
  var service = newService(Firefox, logLevel="config")
  service.start()

  while true:
    sleep(10000)
    service.stop()
    break
main()