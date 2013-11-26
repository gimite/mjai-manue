assert = require("assert")
Pai = require("./pai")
PaiSet = require("./pai_set")
Util = require("./util")

NUM_PIDS = 9 * 3 + 7
CHOWS = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24]

class ShantenAnalysis

  constructor: (pids, params) ->
    assert.ok(Util.all(pids, ((pid) => typeof(pid) == "number")))
    @_params = {
        allowedExtraPais: 0,
        upperbound: Infinity,
    }
    for k, v of params
      @_params[k] = v
    currentVector = @pidsToCountVector(pids)
    targetVector = (0 for _ in [0...NUM_PIDS])
    numMentsus = Math.floor(pids.length / 3)
    goals = []
    shanten = @calculateShantensuInternal(
        currentVector, targetVector, -1, numMentsus, 0, @_params.upperbound, [], goals)
    upperbound = Math.min(shanten + @_params.allowedExtraPais, @_params.upperbound)
    @_goals = []
    for goal in goals
      if goal.shanten <= upperbound
        goal.requiredVector = for pid in [0...Pai.NUM_IDS]
          Math.max(goal.countVector[pid] - currentVector[pid], 0)
        goal.throwableVector = for pid in [0...Pai.NUM_IDS]
          Math.max(currentVector[pid] - goal.countVector[pid], 0)
        @_goals.push(goal)
    @_shanten = if goals.length == 0 then Infinity else shanten

  pidsToCountVector: (pids) ->
    countVector = (0 for _ in [0...NUM_PIDS])
    for pid in pids
      ++countVector[pid]
    return countVector

  calculateShantensuInternal:
    (vector0, vector1, current, numMeldsLeft, minMeldId, upperbound, mentsus, goals) ->

      if numMeldsLeft == 0

        minDelta = 2
        jantoPidCands = []
        for i in [0...NUM_PIDS]
          delta = Math.max((vector1[i] + 2) - vector0[i], 0)
          if delta >= 2 then continue
          newShanten = current + delta
          if newShanten <= upperbound + @_params.allowedExtraPais
            goalVector = vector1.concat([])
            goalVector[i] += 2
            goal = {
                shanten: newShanten,
                mentsus: mentsus.concat([{type: "toitsu", pids: [i, i]}]),
                countVector: goalVector,
            }
            goals.push(goal)
            if newShanten < upperbound then upperbound = newShanten
        return upperbound

      else

        if minMeldId < NUM_PIDS
          for i in [minMeldId...NUM_PIDS]
            if vector1[i] >= 2
              continue
            if vector0[i] <= vector1[i]
              current1 = current + 3
            else if vector0[i] < vector1[i] + 3
              current1 = current + (vector1[i] + 3) - vector0[i]
            else
              current1 = current
            if current1 < current + 3 && current1 <= upperbound + @_params.allowedExtraPais
              vector1[i] += 3
              upperbound = @calculateShantensuInternal(
                  vector0, vector1, current1, numMeldsLeft - 1, i, upperbound,
                  mentsus.concat([{type: "kotsu", pids: [i, i, i]}]), goals)
              vector1[i] -= 3

        startChowId = if minMeldId < NUM_PIDS then 0 else minMeldId - NUM_PIDS
        for chowId in [startChowId...CHOWS.length]
          i = CHOWS[chowId]
          if vector1[i] == 4 || vector1[i + 1] == 4 || vector1[i + 2] == 4
            continue
          current1 = current
          if vector0[i] <= vector1[i] then ++current1
          if vector0[i + 1] <= vector1[i + 1] then ++current1
          if vector0[i + 2] <= vector1[i + 2] then ++current1
          if current1 < current + 3 && current1 <= upperbound + @_params.allowedExtraPais
            ++vector1[i]; ++vector1[i + 1]; ++vector1[i + 2]
            upperbound = @calculateShantensuInternal(
                vector0, vector1, current1, numMeldsLeft - 1, chowId + NUM_PIDS, upperbound,
                mentsus.concat([{type: "shuntsu", pids: [i, i + 1, i + 2]}]), goals)
            --vector1[i]; --vector1[i + 1]; --vector1[i + 2]
        return upperbound

Util.attrReader(ShantenAnalysis, ["shanten", "goals"])
module.exports = ShantenAnalysis
