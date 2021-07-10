import std/unittest
import minestat

proc parseServerResponse(data: string): MineStat =
  parseServerResponse(data, result)

suite "server response is parsed correctly":
  const
    Data =
      "\xFF\x00\x21\x00\xA7\x00\x31\x00\x00" &
      "\x00\x31\x00\x32\x00\x37\x00\x00" &
      "\x00\x31\x00\x2E\x00\x31\x00\x36\x00\x2E\x00\x35\x00\x00" &
      "\x30\x53\x30\x93\x30\x6b\x30\x61\x30\x6f\x4e\x16\x75\x4c\x00\x00" &
      "\x00\x36\x00\x39\x00\x00" &
      "\x00\x34\x00\x32\x00\x30"
    DataAsciiMotd =
      "\xFF\x00\x21\x00\xA7\x00\x31\x00\x00" &
      "\x00\x31\x00\x32\x00\x37\x00\x00" &
      "\x00\x31\x00\x2E\x00\x31\x00\x36\x00\x2E\x00\x35\x00\x00" &
      "\x00\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00\x2c\x00\x20\x00\x57\x00\x6f\x00\x72\x00\x6c\x00\x64\x00\x21\x00\x00" &
      "\x00\x30\x00\x00" &
      "\x00\x31\x00\x30"
  
  test "basic fields":
    let ms = parseServerResponse(Data)
    check ms.version == "1.16.5"
    check ms.currentPlayers == 69
    check ms.maxPlayers == 420

  test "ASCII MOTD":
    let ms = parseServerResponse(DataAsciiMotd)
    check ms.motd == "Hello, World!"

  test "UTF-16 MOTD":
    let ms = parseServerResponse(Data)
    check ms.motd == "こんにちは世界"