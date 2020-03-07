import os, json, options
import haloniumpkg/webdriver
import haloniumpkg/utils
import haloniumpkg/browser
import tables

proc main() =
  var session = createSession(Chrome)

  session.navigate("http://demo.guru99.com/test/upload/")
  let element = session.waitForElement("#uploadfile_0").get()

  element.uploadFile("/Users/joey/Downloads/Question-Checklist.pdf")

  session.actionChain()
         .click("#terms")
         .click("#submitbutton")
         .perform()
  # session.safariSetPermission("getUserMedia", false)
  # echo session.safariPermissions["getUserMedia"]
  # echo session.executeScript("return [1,2,3,4,5];")
  # echo session.allCookies()
  # echo session.newWindow(WindowKind.Window).kind
  # var rect = session.currentWindow.rect
  # rect.height = 1000;
  # session.currentWindow.rect = rect
  # echo session.currentWindow.size
  # session.currentWindow.maximize

  # discard session.actionChain()
  #                .sendKeys("#search-box", "hey", Key.Enter)
  #                .click(".post-main .post-title .thread-title a")
  #                .perform(debugMouseMove=true)

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