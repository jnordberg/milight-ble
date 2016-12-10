### Milight Bluetooth bulb control library. All credit for reverse engineering the protocol goes to
    @moosd - https://github.com/moosd/ReverseEngineeredMiLightBluetooth ###

async = require 'async'
noble = require 'noble'


noop = ->

getId = (name) ->
  num = (parseInt name[1...3], 16) & 0xff
  num = num << 8
  num = num | ((parseInt name[3...5], 16) & 0xff)
  return [num >> 8, num % 256]

createPacket = (input) ->
  k = input[0]
  i = j = 0

  while i <= 10
    j += input[i++] & 0xff

  checksum = (((k ^ j) & 0xff) + 131) & 0xff
  xored = input.map (v) -> (v & 0xff) ^ k

  rv = []
  for o, i in [0, 16, 24, 1, 129, 55, 169, 87, 35, 70, 23, 0]
    if xored[i]?
      rv.push xored[i] + o & 0xff

  rv[0] = k
  rv.push checksum

  return Buffer.from rv


class Bulb

  constructor: (@name, @tx) ->
    @id = getId @name

  send: (command, callback) ->
    rbit = Math.round Math.random() * 255
    data = createPacket [rbit, 161, @id[0], @id[1], command...]
    @tx.write data, false, callback

  turnOn: (callback=noop) ->
    ### Turn the lamp on. ###
    @send [2, 1, 0, 0, 0, 0, 0], callback

  turnOff: (callback=noop) ->
    ### Turn the lamp off. ###
    @send [2, 2, 0, 0, 0, 0, 0], callback

  setTemperature: (kelvin, brightness, callback=noop) ->
    ### Set color temperature to *kelvin* 0-100 with *brightness* 0-100. ###
    async.series [
      (callback) => @send [4, 4, kelvin, 255, 0, 0, 0], callback
      (callback) => @send [4, 5, kelvin, brightness, 0, 0, 0], callback
    ], callback

  setColor: (hue, brightness, callback=noop) ->
    ### Set color to *hue* 0-255 with *brightness* 0-100. ###
    async.series [
      (callback) => @send [2, 4, hue, 100, 0, 0, 0], callback
      (callback) => @send [2, 5, hue, brightness, 0, 0, 0], callback
    ], callback

  setMode: (mode, callback=noop) ->
    ### Set lamp to disco *mode* 0-10. ###
    @send [6, 4, mode, 0, 0, 0, 0], callback


Bulb.fromPeripheral = (peripheral, callback) ->
  ### Create a new Bulb instance from *peripheral*. ###

  connect = (callback) ->
    peripheral.connect callback

  discover = (callback) ->
    peripheral.discoverSomeServicesAndCharacteristics ['1000'], ['1001'], callback

  setup = (services, characteristics, callback) ->
    name = peripheral.advertisement.localName.trim()
    bulb = new Bulb name, characteristics[0]
    callback null, bulb

  async.waterfall [connect, discover, setup], callback

Bulb.discover = (timeout, callback) ->
  ### Discover bulbs, if they don't show up unpair them in the app and try increasing the *timeout*. ###

  if arguments.length is 1
    callback = timeout
    timeout = 2000

  bulbs = []
  peripherals = []

  ensurePoweredOn = (callback) ->
    if noble.state is 'poweredOn'
      do callback
    else
      noble.once 'stateChange', (state) ->
        unless state is 'poweredOn'
          error = new Error "Invalid bluetooth state: #{ state }"
        callback error

  startScanning = (callback) ->
    noble.on 'discover', onDiscover
    noble.startScanning ['1000'], false, callback

  onDiscover = (peripheral) ->
    if peripheral.advertisement?.localName?[0] is 'M'
      peripherals.push peripheral

  waitForResults = (callback) ->
    done = ->
      noble.stopScanning()
      do callback
    setTimeout done, timeout

  resolvePeripherals = (callback) ->
    async.map peripherals, Bulb.fromPeripheral, (error, results) ->
      unless error
        bulbs = results
      callback error

  async.series [
    ensurePoweredOn
    startScanning
    waitForResults
    resolvePeripherals
  ], (error) ->
    noble.removeListener 'discover', onDiscover
    callback error, bulbs


module.exports = Bulb
