import options, packedjson
import halonium

proc main() =
  echo "Please enter a file to upload: "
  let file = stdin.readLine()
  let session = createSession(Chrome, browserOptions=chromeOptions(args=["--headless"]))

  session.navigate("http://demo.guru99.com/test/upload/")
  let element = session.waitForElement("#uploadfile_0").get()

  element.uploadFile(file)

  session.actionChain()
         .click("#terms")
         .click("#submitbutton")
         .perform()
  echo "Success!"

main()
