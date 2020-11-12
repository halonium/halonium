import options, os
import halonium

proc main() =
  var session = createSession(Firefox)
  session.navigate("https://google.com")

  let searchBar = "input[title=\"Αναζήτηση\"]"
  let element = session.waitForElement(searchBar).get()

  element.sendKeys("clowns", Key.Enter)

  let firstATag = session.waitForElement("#search a").get()
  firstATag.click()
  sleep(1000)

  session.stop()

main()
