# halonium
A browser automation engine written in Nim translated from Python

## Usage

See examples for detailed usage.

```nim
import options, os
import halonium

proc main() =
  var session = createSession(Chrome)
  session.navigate("https://google.com")

  let searchBar = "input[title=\"Search\"]"
  let element = session.waitForElement(searchBar).get()

  element.sendKeys("clowns", Key.Enter)

  let firstATag = session.waitForElement("#search a").get()
  firstATag.click()
  sleep(1000)

  session.stop()

main()
```