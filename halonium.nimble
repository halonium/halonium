# Package

version       = "0.2.7"
author        = "Joey Yakimowich-Payne"
description   = "A browser automation library written in Nim"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
# bin           = @["halonium"]



# Dependencies

requires "nim >= 1.0.6"
requires "tempfile >= 0.1.7"
requires "https://github.com/pragmagic/uuids#head"
requires "zippy"
requires "fusion >= 1.0.0"
