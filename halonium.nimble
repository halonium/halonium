# Package

version       = "0.2.4"
author        = "Joey Yakimowich-Payne"
description   = "A browser automation library written in Nim"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["halonium"]



# Dependencies

requires "nim >= 1.0.6"
requires "tempfile >= 0.1.7"
requires "uuids >= 0.1.10"
requires "zip >= 0.3.1"
requires "fusion >= 1.0.0"
