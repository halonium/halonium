import options, os
import halonium

proc main() =

  # hideChromeDriverConsole and headless give a completely background execution on Windows
  let session = createSession(
    Chrome, browserOptions=chromeOptions(args=["--headless"]), hideChromeDriverConsole=true
  )
  session.navigate("https://google.com")

  let searchBar = "input[title=\"Search\"]"
  let element = session.waitForElement(searchBar).get()

  element.sendKeys("clowns", Key.Enter)

  let firstATag = session.waitForElement("#search a").get()
  firstATag.click()
  sleep(1000)

  session.stop()

main()
