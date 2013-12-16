fs = require("fs")
printf = require("printf")
Game = require("./game")

stats = JSON.parse(fs.readFileSync(process.argv[2]).toString("utf-8"))

if stats.numTurnsDistribution
  console.log("numTurnsDistribution:")
  for i in [0...18]
    console.log(printf("  %2d: %.3f", i, stats.numTurnsDistribution[i]))
  console.log("")

if stats.yamitenStats
  console.log("yamitenStats:")
  for i in [0...18]
    line = printf("  %2d: ", i)
    for j in [0...5]
      yamitenStat = stats.yamitenStats["#{i},#{j}"] || {tenpai: 0, total: 0}
      line += printf(
          "%.3f(%5d/%5d)  ",
          yamitenStat.tenpai / yamitenStat.total,
          yamitenStat.tenpai,
          yamitenStat.total)
    console.log(line)
  console.log("")

if stats.ryukyokuTenpaiStat
  console.log("ryukyokuTenpaiStat:")
  i = 0
  while i <= Game.FINAL_TURN
    console.log(printf(
        "  %5.2f: %.3f (%d)",
        i,
        stats.ryukyokuTenpaiStat.tenpaiTurnDistribution[i] / stats.ryukyokuTenpaiStat.total,
        stats.ryukyokuTenpaiStat.tenpaiTurnDistribution[i]))
    i += 1 / 4
  console.log(printf(
      "  noten: %.3f (%d)",
      stats.ryukyokuTenpaiStat.noten / stats.ryukyokuTenpaiStat.total,
      stats.ryukyokuTenpaiStat.noten))
  console.log("")

if stats.scoreStats
  console.log("scoreStats:")
  for i in [0...4]
    for j in [0...4]
      if i == j then continue
      for k in [-30...30]
        scoreDiff = k * 1000
        line = printf("  %d,%d %6d ", i, j, scoreDiff)
        for kyokuName in ["E1", "E2", "E3", "E4", "S1", "S2", "S3", "S4"]
          stat = stats.scoreStats["#{kyokuName},#{i},#{j},#{scoreDiff}"]
          if !stat
            stat = {total: 0, win: 0}
          line += printf("%.3f(%4d/%4d) ", stat.win / stat.total, stat.win, stat.total)
        console.log(line)
