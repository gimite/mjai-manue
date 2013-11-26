assert = require("assert")
ShantenAnalysis = require("./shanten_analysis")
Pai = require("./pai")

# Also run: shanten_analysis_benchmark.coffee

pids = (pai.id() for pai in Pai.strToPais("1m 2m 3m 7m 8m 9m 2s 3s 4s S S S W"))
assert.equal(new ShantenAnalysis(pids).shanten(), 0)
assert.equal(new ShantenAnalysis(pids, {upperbound: 0}). shanten(), 0)

pids = (pai.id() for pai in Pai.strToPais("1m 2m 3m 7m 8m 9m 2s 3s S S S W N"))
assert.equal(new ShantenAnalysis(pids).shanten(), 1)
assert.equal(new ShantenAnalysis(pids, {upperbound: 0}). shanten(), Infinity)
