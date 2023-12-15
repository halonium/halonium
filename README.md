# halonium
A browser automation engine written in Nim translated from Python.

## Status

This library is mostly converted from the Python selenium codebase as of ~Dec 2019. There are no automated tests yet, but most webdrivers are working from basic testing (see src/halonium/browser.nim for supported browsers). Some things might not work yet which automated testing would catch. Feel free to file issues :)

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
