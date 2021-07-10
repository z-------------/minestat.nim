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
import std/encodings

const
  NumFields = 6 # number of values expected from server
  DefaultTimeout = 5000 # default TCP timeout in milliseconds

type
  MineStat* = object
    address*: string
    port*: int
    online*: bool # online or offline?
    version*: string # server version
    motd*: string # message of the day
    currentPlayers*: int # current number of players online
    maxPlayers*: int # maximum player capacity
    latency*: int64 # ping to to server in milliseconds

template clean(data: string): string =
  data.convert("UTF-8", "UTF-16BE")

proc withTimeout[T](fut: Future[T]; timeout: int): Future[Option[T]] {.async.} =
  ## If fut completes within timeout, returns some(fut.value).
  ## Else, returns none.
  if await asyncdispatch.withTimeout(fut, timeout):
    return some(fut.read)
  else:
    return none(T)

proc parseServerResponse*(data: string; result: var MineStat) =
  let infos = data.split("\x00\x00")
  if infos.len >= NumFields:
    result.online = true
    result.version = infos[2].clean
    result.motd = infos[3].clean
    result.currentPlayers = infos[4].clean.parseInt
    result.maxPlayers = infos[5].clean.parseInt

proc initMineStat*(address: string; port: int; timeout = DefaultTimeout): Future[MineStat] {.async.} =
  var result: MineStat

  result.address = address
  result.port = port

  let startTime = getTime()

  var socket = newAsyncSocket()
  await socket.connect(address, Port(port))

  result.latency = (getTime() - startTime).inMilliseconds

  await socket.send("\xFE\x01")

  let data = await socket.recv(512).withTimeout(timeout)
  if data.isSome and data.get.len > 0:
    parseServerResponse(data.get, result)
  
  socket.close()
  return result

proc initMineStatSync*(address: string; port: int; timeout = DefaultTimeout): MineStat =
  waitFor initMineStat(address, port, timeout)
