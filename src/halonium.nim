import os, json, options
import haloniumpkg/webdriver
import haloniumpkg/browser

proc main() =
  var session = createSession(Firefox)

  session.navigate("https://forum.nim-lang.org/")
  # echo session.executeScript("return [1,2,3,4,5];")
  # echo session.allCookies()
  # echo session.newWindow(WindowKind.Window).kind

  sleep(5000)
  discard session.actionChain()
                 .sendKeys("#search-box", "hey", Key.Enter)
                 # Figure out how to make actions use future element queries
                 .click(".post-main .post-title .thread-title a")
                 .perform(debugMouseMove=true)

  # let elements = session.findElements(".thread-title")
  # for element in elements:
  #   echo element.attribute("class")
  #   echo element.property("innerText")
  #   echo element.rect

  while true:
    sleep(10000)
    session.stop()
    break
main()