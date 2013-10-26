url = require("url")
net = require("net")
Action = require("./action")
Pai = require("./pai")
Furo = require("./furo")
Util = require("./util")

class TCPClientGame

  constructor: (@_params) ->
    @_ai = @_params.ai
    @_urlFields = url.parse(@_params.url)

  play: ->
    @_buffer = ""
    @_socket = net.connect({host: @_urlFields.hostname, port: @_urlFields.port})
    @_socket.on "connect", =>
      console.log("connected")
    @_socket.on("data", (chunk) =>
      lines = chunk.toString().split(/\n/)
      lines[0] = @_buffer + lines[0]
      for i in [0...(lines.length - 1)]
        @onReceiveLine(lines[i])
      @_buffer = lines[lines.length - 1]
    @_socket.on "close", =>
      console.log("closed"))
    @_socket.on "error", (e) =>
      console.log("tcp error: #{e.message}")

  onReceiveLine: (line) ->
    console.log("<-\t#{line}")
    action = Action.fromJson(line, this)
    switch action.type
      when "hello"
        responseJson = JSON.stringify({
            type: "join", 
            name: @_params.name, 
            room: @_urlFields.path.substr(1),
        })
      when "error"
        @_socket.end()
        return
      else
        response = @doAction(action)
        if action.type == "end_game"
          @_socket.end()
          return
        responseJson =
            (if response then response.toJson() else JSON.stringify({type: "none"}))
    console.log("->\t#{responseJson}")
    @_socket.write("#{responseJson}\n")

  doAction: (action) ->
    @updateState(action)
    return @_ai.respondToAction(action)

  updateState: (action) ->

    if action.type == "start_game"
      @_myId = action.id
      @_players = ({id: i} for i in [0...4])
      @_ai.initialize(this, @_players[action.id])

    for player in @_players

      switch action.type
        when "start_game"
          if action.names
            player.name = action.names[player.id]
          player.score = 25000
          player.tehais = null
          player.furos = null
          player.ho = null
          player.sutehais = null
          player.reachState = null
          player.reachHoIndex = null
        when "start_kyoku"
          player.tehais = action.tehais[player.id]
          player.furos = []
          player.ho = []
          player.sutehais = []
          player.reachState = "none"
          player.reachHoIndex = null

      if action.actor == player
        switch action.type
          when "tsumo"
            player.tehais.push(action.pai)
          when "dahai"
            @deleteTehai(player, action.pai)
            player.tehais.sort(Pai.compare)
            player.ho.push(action.pai)
            player.sutehais.push(action.pai)
          when "chi", "pon", "daiminkan", "ankan"
            for pai in action.consumed
              @deleteTehai(player, pai)
            player.furos.push(new Furo({
                type: action.type,
                taken: action.pai,
                consumed: action.consumed,
                target: action.target,
            }))
          when "kakan"
            @deleteTehai(player, action.pai)
            ponIndex = null
            for i in [0...player.furos.length]
              if player.furos[i].type == "pon" && player.furos[i].taken().hasSameSymbol(action.pai)
                ponIndex = i
                break
            if ponIndex == null
              throw "should not happen"
            player.furos[ponIndex] = new Furo({
                type: "kakan",
                taken: player.furos[ponIndex].taken,
                consumed: player.furos[ponIndex].consumed.concat([action.pai]),
                target: player.furos[ponIndex].target,
            })
          when "reach"
            player.reachState = "declared"
          when "reach_accepted"
            player.reachState = "accepted"
            player.reachHoIndex = player.ho.length - 1

      if action.target == player
        switch action.type
          when "chi", "pon", "daiminkan"
            pai = player.ho.pop()
            if pai != action.pai
              throw "should not happen"

      if action.scores
        player.score = action.scores[player.id]

      console.log("[#{player.id}] tehai: " + Pai.paisToStr(player.tehais))
      console.log("       ho: " + Pai.paisToStr(player.ho))

  deleteTehai: (player, pai) ->
    paiIndex = null
    for i in [0...player.tehais.length]
      if player.tehais[i].equal(pai) || player.tehais[i].equal(Pai.UNKNOWN)
        paiIndex = i
        break
    if paiIndex == null
      throw "trying to delete #{pai} which is not in tehais: #{player.tehais}"
    player.tehais.splice(paiIndex, 1)

Util.attrReader(TCPClientGame, ["players"])

module.exports = TCPClientGame
