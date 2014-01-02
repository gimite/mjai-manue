fs = require("fs")
printf = require("printf")
Game = require("./game")

stats = JSON.parse(fs.readFileSync(process.argv[2]).toString("utf-8"))

ratiosMap = {}
for key, freqs of stats.scoreStats
  total = 0
  for scoreDiff, freq of freqs
    total += freq
  ratiosMap[key] = {}
  for scoreDiff, freq of freqs
    ratiosMap[key][scoreDiff] = freq / total

winProbsMap = {}
for kyokuName in ["E1", "E2", "E3", "E4", "S1", "S2", "S3", "S4"]
  for i in [0...4]
    for j in [0...4]
      if i == j then continue
      relativeScoreRatios = {}
      for scoreDiff1, ratio1 of ratiosMap["#{kyokuName},#{i}"]
        for scoreDiff2, ratio2 of ratiosMap["#{kyokuName},#{j}"]
          relativeScore = scoreDiff1 - scoreDiff2
          if !(relativeScore of relativeScoreRatios)
            relativeScoreRatios[relativeScore] = 0
          relativeScoreRatios[relativeScore] += ratio1 * ratio2
      relativeScores = (parseInt(s) for s of relativeScoreRatios)
      relativeScores.sort((a, b) -> b - a)
      accumProb = 0
      delta = (if i > j then 0 else 100)
      winProbs = {}
      for relativeScore in relativeScores
        accumProb += relativeScoreRatios[relativeScore]
        winProbs[delta - relativeScore] = accumProb
      winProbsMap["#{kyokuName},#{i},#{j}"] = winProbs
stats = {
  winProbsMap: winProbsMap,
}
console.log(JSON.stringify(stats))
