Archive = require("./archive")
Game = require("./game")
ShantenAnalysis = require("./shanten_analysis")

playArchives = (onAction) ->
  paths = process.argv[2...]
  for i in [0...paths.length]
    console.error("#{i} / #{paths.length}")
    archive = new Archive(paths[i])
    archive.play (action) =>
      onAction(action, archive)

numKyokus = 0
numTurnsFreqs = (0 for _ in [0...18])
totalHoraPoints = 0
numHoras = 0
playArchives (action, game) =>
  switch action.type
    when "hora"
      ++numHoras
      totalHoraPoints += action.horaPoints
    when "end_kyoku"
      ++numKyokus
      ++numTurnsFreqs[Math.floor((Game.NUM_INITIAL_PIPAIS - game.numPipais()) / 4)]
    when "error"
      throw new Error("error in the log: #{path}")

yamitenStats = {}
playArchives (action, game) =>
  switch action.type
    when "dahai"
      if action.actor.reachState != "none"
        return
      numTurns = Math.floor(game.numPipais() / 4)
      numFuros = action.actor.furos.length
      key = "#{numTurns},#{numFuros}"
      if !(key of yamitenStats)
        yamitenStats[key] = {total: 0, tenpai: 0}
      ++yamitenStats[key].total
      if new ShantenAnalysis(pai.id() for pai in action.actor.tehais, {upperbound: 0}).shanten() <= 0
        ++yamitenStats[key].tenpai

stats = {
  numTurnsDistribution: (f / numKyokus for f in numTurnsFreqs),
  averageHoraPoints: totalHoraPoints / numHoras,
  yamitenStats: yamitenStats,
}
console.log(JSON.stringify(stats))
