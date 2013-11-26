fs = require("fs")
ShantenAnalysis = require("./shanten_analysis")

fs.readFileSync("shanten_benchmark_data.num.txt").toString("utf-8").split(/\n/).forEach (line) ->
  if !line then return
  row = line.split(/\ /)
  pids = (parseInt(row[i]) for i in [0...(row.length - 1)])
  expectedShantensu = parseInt(row[row.length - 1])
  analysis = new ShantenAnalysis(pids)
  if analysis.shanten() != expectedShantensu
    throw new Error("Shantensu mismatch: #{analysis.shanten()} != #{expectedShantensu}")
