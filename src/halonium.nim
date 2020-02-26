import os
import haloniumpkg/webdriver
import haloniumpkg/browser

proc main() =
  var session = createSession(Firefox)

  session.navigate("https://no.such.website.com/")

  sleep(5000)

  let element = session.findElement("#img-logo")
  echo element

  while true:
    sleep(10000)
    session.stop()
    break
main()