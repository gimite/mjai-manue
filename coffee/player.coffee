Util = require("./util")
Action = require("./action")
Furo = require("./furo")
Pai = require("./pai")

class Player

  updateState: (action) ->

    switch action.type
      when "start_game"
        @_id = action.id
        if action.names then @_name = action.names[@_id]
        @_score = 25000
        @_tehais = null
        @_furos = null
        @_ho = null
        @_sutehais = null
        @_reachState = null
        @_reachHoIndex = null
      when "start_kyoku"
        @_tehais = action.tehais[@_id]
        @_furos = []
        @_ho = []
        @_sutehais = []
        @_reachState = "none"
        @_reachHoIndex = null

    if action.actor == this
      switch action.type
        when "tsumo"
          @_tehais.push(action.pai)
        when "dahai"
          @deleteTehai(action.pai)
          @_tehais.sort(Pai.compare)
          @_ho.push(action.pai)
          @_sutehais.push(action.pai)
        when "chi", "pon", "daiminkan", "ankan"
          for pai in action.consumed
            @deleteTehai(pai)
          @_furos.push(new Furo({
              type: action.type,
              taken: action.pai,
              consumed: action.consumed,
              target: action.target,
          }))
        when "kakan"
          @deleteTehai(action.pai)
          ponIndex = null
          for i in [0...@_furos.length]
            if @_furos[i].type == "pon" && @_furos[i].taken().hasSameSymbol(action.pai)
              ponIndex = i
              break
          if ponIndex == null
            throw "should not happen"
          @_furos[ponIndex] = new Furo({
              type: "kakan",
              taken: @_furos[ponIndex].taken,
              consumed: @_furos[ponIndex].consumed.concat([action.pai]),
              target: @_furos[ponIndex].target,
          })
        when "reach"
          @_reachState = "declared"
        when "reach_accepted"
          @_reachState = "accepted"
          @_reachHoIndex = @_ho.length - 1

    if action.target == this
      switch action.type
        when "chi", "pon", "daiminkan"
          pai = @_ho.pop()
          if pai != action.pai
            throw "should not happen"

    if action.scores
      @_score = action.scores[@_id]

  deleteTehai: (pai) ->
    paiIndex = null
    for i in [0...@_tehais.length]
      if @_tehais[i].equal(pai) || @_tehais[i].equal(Pai.UNKNOWN)
        paiIndex = i
        break
    if paiIndex == null
      throw "trying to delete #{pai} which is not in tehais: #{@_tehais}"
    @_tehais.splice(paiIndex, 1)

  createAction: (extraParams) ->
    params = {actor: this}
    for k, v of extraParams
      params[k] = v
    return new Action(params)

Util.attrReader(Player, [
  "id", "tehais", "furos", "ho", "sutehais", "extraAnpais", "reachState", "reachHoIndex",
  "attributes", "logText", "name", "game", "score"])
Util.attrAccessor(Player, ["game"])

module.exports = Player
