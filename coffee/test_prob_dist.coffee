assert = require("assert")
ProbDist = require("./prob_dist")
HashMap = require("./hash_map")

pb1 = new ProbDist(new HashMap([[0, 0.5], [8000, 0.5]]))
pb2 = new ProbDist(new HashMap([[0, 0.5], [-2000, 0.5]]))

console.log(ProbDist.add(pb1, pb1).toString())

console.log(ProbDist.merge([[pb1, 0.5], [pb2, 0.5]]).toString())
