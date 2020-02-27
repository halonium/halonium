import os
import haloniumpkg/webdriver
import haloniumpkg/browser

proc main() =
  var session = createSession(Firefox)

  session.navigate("https://forum.nim-lang.org/")
  echo session.currentWindowHandle()

  sleep(5000)

  let elements = session.findElements(".thread-title")
  for element in elements:
    echo element.attribute("class")
    echo element.property("innerText")

  while true:
    sleep(10000)
    session.stop()
    break
main()