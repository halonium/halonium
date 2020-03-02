import os, json, options
import haloniumpkg/webdriver
import haloniumpkg/utils
import haloniumpkg/browser

proc main() =
  var session = createSession(Firefox)

  session.navigate("https://forum.nim-lang.org/")
  # echo session.executeScript("return [1,2,3,4,5];")
  # echo session.allCookies()
  # echo session.newWindow(WindowKind.Window).kind
  # var rect = session.currentWindow.rect
  # rect.height = 1000;
  # session.currentWindow.rect = rect
  # echo session.currentWindow.size
  # session.currentWindow.maximize

  discard session.actionChain()
                 .sendKeys("#search-box", "hey", Key.Enter)
                 .click(".post-main .post-title .thread-title a")
                 .perform(debugMouseMove=true)

  # echo session.log(ltBrowser)
  # echo session.log(ltDriver)
  # let elements = session.findElements(".thread-title")
  # for element in elements:
  #   echo element.attribute("class")
  #   echo element.property("innerText")
  #   echo element.rect

  while true:
    try:
      sleep(1000)
    except:
      session.stop()
      break
main()