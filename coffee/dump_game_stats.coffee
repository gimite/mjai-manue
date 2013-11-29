Archive = require("./archive")
Game = require("./game")
ShantenAnalysis = require("./shanten_analysis")

class BasicCounter

  constructor: ->
    @numKyokus = 0
    @numTurnsFreqs = (0 for _ in [0...18])
    @numRyukyokus = 0
    @totalHoraPoints = 0
    @numHoras = 0

  onAction: (action, game) ->
    switch action.type
      when "hora"
        ++@numHoras
        @totalHoraPoints += action.horaPoints
      when "ryukyoku"
        ++@numRyukyokus
      when "end_kyoku"
        ++@numKyokus
        ++@numTurnsFreqs[Math.floor((Game.NUM_INITIAL_PIPAIS - game.numPipais()) / 4)]

class YamitenCounter

  constructor: ->
    @stats = {}

  onAction: (action, game) ->
    switch action.type
      when "dahai"
        if action.actor.reachState != "none"
          return
        numTurns = Math.floor(game.numPipais() / 4)
        numFuros = action.actor.furos.length
        key = "#{numTurns},#{numFuros}"
        if !(key of @stats)
          @stats[key] = {total: 0, tenpai: 0}
        ++@stats[key].total
        if new ShantenAnalysis(pai.id() for pai in action.actor.tehais, {upperbound: 0}).shanten() <= 0
          ++@stats[key].tenpai

class RyukyokuTenpaiCounter

  constructor: ->
    @total = 0
    @tenpai = 0

  onAction: (action, game) ->
    switch action.type
      when "ryukyoku"
        for tenpai in action.tenpais
          ++@total
          if tenpai
            ++@tenpai

basic = new BasicCounter()
yamiten = new YamitenCounter()
ryukyokuTenpai = new RyukyokuTenpaiCounter()
counters = [basic, yamiten, ryukyokuTenpai]

paths = process.argv[2...]
for i in [0...paths.length]
  console.error("#{i} / #{paths.length}")
  archive = new Archive(paths[i])
  archive.play (action) =>
    if action.type == "error"
      throw new Error("error in the log: #{paths[i]}")
    for counter in counters
      counter.onAction(action, archive)

stats = {
  numTurnsDistribution: (f / basic.numKyokus for f in basic.numTurnsFreqs),
  ryukyokuRatio: basic.numRyukyokus / basic.numKyokus,
  averageHoraPoints: basic.totalHoraPoints / basic.numHoras,
  yamitenStats: yamiten.stats,
  ryukyokuTenpaiStat: {
    total: ryukyokuTenpai.total,
    tenpai: ryukyokuTenpai.tenpai,
  }
}
console.log(JSON.stringify(stats))
