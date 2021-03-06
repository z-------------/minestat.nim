#
# minestat.nim - A Minecraft server status checker
# Copyright (C) 2021 Zack Guard
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

import std/asyncdispatch
import std/asyncnet
import std/times
import std/strutils
import std/options
import pkg/encode

const
  NumFields = 6 # number of values expected from server
  DefaultPort = 25565
  DefaultTimeoutMs = 5000 # default TCP timeout in milliseconds

type
  MineStat* = object
    address*: string
    port*: int
    online*: bool ## whether the server is online
    version*: string ## server version
    motd*: string ## message of the day
    currentPlayers*: int ## number of players currently online
    maxPlayers*: int ## maximum player capacity
    latencyMs*: int64 ## ping to server in milliseconds

template latency*(minestat: MineStat): int64 =
  minestat.latencyMs

template clean(data: string): string =
  data.fromUtf16Be()

proc withTimeout[T](fut: Future[T]; timeoutMs: int): Future[Option[T]] {.async.} =
  ## If fut completes within timeoutMs, returns some(fut.value).
  ## Else, returns none.
  if await asyncdispatch.withTimeout(fut, timeoutMs):
    return some(fut.read)
  else:
    return none(T)

func parseServerResponse*(data: string; result: var MineStat) =
  let infos = data.split("\x00\x00")
  if infos.len >= NumFields:
    result.online = true
    result.version = infos[2].clean
    result.motd = infos[3].clean
    result.currentPlayers = infos[4].clean.parseInt
    result.maxPlayers = infos[5].clean.parseInt

proc initMineStat*(address: string; port = DefaultPort; timeoutMs = DefaultTimeoutMs): Future[MineStat] {.async.} =
  var result: MineStat

  result.address = address
  result.port = port

  let startTime = getTime()

  var socket: AsyncSocket
  try:
    socket = newAsyncSocket()
    await socket.connect(address, Port(port))
    result.latencyMs = (getTime() - startTime).inMilliseconds

    await socket.send("\xFE\x01")
    let data = await socket.recv(512).withTimeout(timeoutMs)
    if data.isSome and data.get.len > 0:
      parseServerResponse(data.get, result)
  except OSError:
    discard
  finally:
    if not socket.isNil:
      socket.close()

  return result

proc initMineStatSync*(address: string; port = DefaultPort; timeoutMs = DefaultTimeoutMs): MineStat =
  waitFor initMineStat(address, port, timeoutMs)
