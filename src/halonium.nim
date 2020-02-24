import threadpool, os
import haloniumpkg/webdriver
import haloniumpkg/utils
import haloniumpkg/service

proc main() =
  var service = newService(ServiceKind.Firefox, logLevel="config")
  service.start()

  while true:
    sleep(10000)
    service.stop()
    break
main()