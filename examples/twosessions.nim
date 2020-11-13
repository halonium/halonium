import options, os
import halonium

proc main() =
  var session = createSession(Chrome)
  var fsession = createSession(Firefox)
  session.navigate("https://google.com")
  fsession.navigate("https://google.com")

  let searchBar = "input[title=\"Search\"]"

  let element = session.waitForElement(searchBar).get()
  let felement = fsession.waitForElement(searchBar).get()

  element.sendKeys("clowns", Key.Enter)
  felement.sendKeys("clowns", Key.Enter)

  let firstATag = session.waitForElement("#search a").get()
  firstATag.click()

  let ffirstATag = fsession.waitForElement("#search a").get()
  ffirstATag.click()
  sleep(1000)

  session.stop()
  fsession.stop()

main()
