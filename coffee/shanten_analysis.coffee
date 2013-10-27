Pai = require("./pai")
PaiSet = require("./pai_set")
Util = require("./util")

NUM_PIDS = 9 * 3 + 7
CHOWS = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24]

class ShantenAnalysis

  constructor: (pids) ->
    if pids.length != 14
      throw "not supported"
    countVector = @pidsToCountVector(pids)
    targetVector = (0 for _ in [0...NUM_PIDS])
    @_goals = []
    @_shanten = @calculateShantensuInternal(countVector, targetVector, 0, 4, 0, 1 / 0, [], @_goals) - 1

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
          if vector0[i] >= vector1[i] + 2
            minDelta = 0
            jantoPidCands = [i]
            break
          else if vector0[i] == vector1[i] + 1
            minDelta = 1
            jantoPidCands.push(i)
        current += minDelta
        if current <= upperbound
          if current < upperbound
            goals.splice(0, goals.length)
          for pid in jantoPidCands
            goalVector = vector1.concat([])
            goalVector[pid] += 2
            goals.push({
                mentsus: mentsus.concat([{type: "toitsu", firstPid: pid}]),
                countVector: goalVector,
            })
          return current
        else
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
            if current1 <= upperbound
              vector1[i] += 3
              upperbound = @calculateShantensuInternal(
                  vector0, vector1, current1, numMeldsLeft - 1, i, upperbound,
                  mentsus.concat([{type: "kotsu", firstPid: i}]), goals)
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
          if current1 <= upperbound
            ++vector1[i]; ++vector1[i + 1]; ++vector1[i + 2]
            upperbound = @calculateShantensuInternal(
                vector0, vector1, current1, numMeldsLeft - 1, chowId + NUM_PIDS, upperbound,
                mentsus.concat([{type: "shuntsu", firstPid: i}]), goals)
            --vector1[i]; --vector1[i + 1]; --vector1[i + 2]
        return upperbound

Util.attrReader(ShantenAnalysis, ["shanten", "goals"])
module.exports = ShantenAnalysis
