import options, os
import halonium

proc main() =

  # hideDriverConsoleWindow and headless give a completely background execution on Windows
  let session = createSession(
    Chrome, browserOptions=chromeOptions(args=[]), hideDriverConsoleWindow=true
  )
  session.navigate("https://google.com")

  let searchBar = "textarea[aria-label=\"Search\"]"
  let element = session.waitForElement(searchBar).get()

  element.sendKeys("clowns", Key.Enter)

  let firstATag = session.waitForElement("#search a").get()
  firstATag.click()
  sleep(1000)

  session.stop()

main()
