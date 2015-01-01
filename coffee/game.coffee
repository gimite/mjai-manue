url = require("url")
net = require("net")
Action = require("./action")
Pai = require("./pai")
Furo = require("./furo")
Util = require("./util")
ShantenAnalysis = require("./shanten_analysis")

class Game

  updateState: (action) ->

    @_previousAction = (if action.type == "start_game" then null else @_currentAction)
    @_currentAction = action
    @_tenpais = (null for i in [0...4])

    switch action.type
      when "start_game"
        @_players = ({id: i} for i in [0...4])
        @_bakaze = null
        @_kyokuNum = null
        @_honba = null
        @_oya = null
        @_chicha = null
        @_doraMarkers = null
        @_numPipais = null
      when "start_kyoku"
        @_bakaze = action.bakaze
        @_kyokuNum = action.kyoku
        @_honba = action.honba
        @_oya = action.oya
        if !@_chicha then @_chicha = @_oya
        @_doraMarkers = [action.doraMarker]
        @_numPipais = Game.NUM_INITIAL_PIPAIS
      when "tsumo"
        --@_numPipais
      when "dora"
        @_doraMarkers.push(action.doraMarker)

    for player in @_players

      # This is specially handled here because it's not an anpai if the dahai is followed by
      # a hora.
      if @_previousAction &&
          @_previousAction.type == "dahai" &&
          @_previousAction.actor != player &&
          action.type != "hora"
        player.extraAnpais.push(@_previousAction.pai)

      switch action.type
        when "start_game"
          if action.names
            player.name = action.names[player.id]
          player.score = 25000
          player.tehais = null
          player.furos = null
          player.ho = null
          player.sutehais = null
          player.extraAnpais = null
          player.reachState = null
          player.reachHoIndex = null
          player.reachSutehaiIndex = null
        when "start_kyoku"
          player.tehais = action.tehais[player.id]
          player.furos = []
          player.ho = []
          player.sutehais = []
          player.extraAnpais = []
          player.reachState = "none"
          player.reachHoIndex = null
          player.reachSutehaiIndex = null

      if action.actor == player
        switch action.type
          when "tsumo"
            player.tehais.push(action.pai)
          when "dahai"
            @deleteTehai(player, action.pai)
            player.tehais.sort(Pai.compare)
            player.ho.push(action.pai)
            player.sutehais.push(action.pai)
            if player.reachState != "accepted" then player.extraAnpais = []
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
              if player.furos[i].type() == "pon" && player.furos[i].taken().hasSameSymbol(action.pai)
                ponIndex = i
                break
            if ponIndex == null
              throw new Error("should not happen")
            player.furos[ponIndex] = new Furo({
                type: "kakan",
                taken: player.furos[ponIndex].taken(),
                consumed: player.furos[ponIndex].consumed().concat([action.pai]),
                target: player.furos[ponIndex].target(),
            })
          when "reach"
            player.reachState = "declared"
          when "reach_accepted"
            player.reachState = "accepted"
            player.reachHoIndex = player.ho.length - 1
            player.reachSutehaiIndex = player.sutehais.length - 1

      if action.target == player
        switch action.type
          when "chi", "pon", "daiminkan"
            pai = player.ho.pop()
            if !pai.equal(action.pai)
              throw new Error("should not happen")

      if action.scores
        player.score = action.scores[player.id]

  printState: ->
    for player in @_players
      console.log("[#{player.id}] tehai: " + Pai.paisToStr(player.tehais))
      console.log("       ho: " + Pai.paisToStr(player.ho))
    console.log("")

  anpais: (player) ->
    return player.sutehais.concat(player.extraAnpais)

  visiblePais: (player) ->
    pais = []
    for pai in @_doraMarkers
      pais.push(pai)
    for pai in player.tehais
      pais.push(pai)
    for p in @_players
      for pai in p.ho
        pais.push(pai)
      for furo in p.furos
        for pai in furo.pais()
          pais.push(pai)
    return pais

  doras: ->
    if @_doraMarkers
      return (pai.nextForDora() for pai in @_doraMarkers)
    else
      return null

  jikaze: (player) ->
    if @_oya
      return new Pai("t", 1 + (4 + player.id - @_oya.id) % 4)
    else
      return null

  yakuhaiFan: (pai, player) ->
    fan = 0
    if pai.type() == "t" && pai.number() >= 5 && pai.number() <= 7
      ++fan
    if pai.hasSameSymbol(@_bakaze)
      ++fan
    if pai.hasSameSymbol(@jikaze(player))
      ++fan
    return fan

  deleteTehai: (player, pai) ->
    paiIndex = null
    for i in [0...player.tehais.length]
      if player.tehais[i].equal(pai) || player.tehais[i].equal(Pai.UNKNOWN)
        paiIndex = i
        break
    if paiIndex == null
      throw new Error("trying to delete #{pai} which is not in tehais: #{player.tehais}")
    player.tehais.splice(paiIndex, 1)

  turn: ->
    return (Game.NUM_INITIAL_PIPAIS - @numPipais()) / 4

  isTenpai: (player) ->
    if @_tenpais[player.id] == null
      analysis = new ShantenAnalysis(pai.id() for pai in player.tehais, {upperbound: 0})
      @_tenpais[player.id] = analysis.shanten() <= 0
    return @_tenpais[player.id]

  getDistance: (player1, player2) ->
    return (4 + player1.id - player2.id) % 4

  rankedPlayers: ->
    return @_players.sort (p1, p2) =>
      if p1.score > p2.score
        return -1
      else if p1.score < p2.score
        return 1
      else
        return @getDistance(p1, @_chicha) - @getDistance(p2, @_chicha)

  setState: (state) ->
    for k, v of state
      this["_#{k}"] = v

Game.NUM_INITIAL_PIPAIS = Pai.NUM_IDS * 4 - 13 * 4 - 14
Game.FINAL_TURN = Game.NUM_INITIAL_PIPAIS / 4

Game.getNextKyoku = (bakaze, kyokuNum) ->
  if kyokuNum == 4
    return {bakaze: bakaze.nextForDora(), kyokuNum: 1}
  else
    return {bakaze: bakaze, kyokuNum: kyokuNum + 1}
    
Game.getDefaultStateForTest = ->
  players = []
  for i in [0...4]
    players.push({
      id: i,
      tehais: (Pai.UNKNOWN for _ in [0...13])
      furos: [],
      ho: [],
      sutehais: [],
      extraAnpais: [],
      reachState: "none",
      reachHoIndex: null,
      reachSutehaiIndex: null,
      score: 25000,
    })
  return {
    players: players,
    bakaze: new Pai("E"),
    kyokuNum: 1,
    honba: 0,
    oya: players[0],
    chicha: players[0],
    doraMarkers: [],
    numPipais: Game.NUM_INITIAL_PIPAIS,
  }

Util.attrReader(Game, ["players", "doraMarkers", "bakaze", "kyokuNum", "oya", "chicha", "numPipais"])

module.exports = Game
