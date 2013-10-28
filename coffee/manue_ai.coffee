AI = require("./ai")
Pai = require("./pai")
PaiSet = require("./pai_set")
ShantenAnalysis = require("./shanten_analysis")
BitVector = require("./bit_vector")
Util = require("./util")

class ManueAI extends AI

  respondToAction: (action) ->

    #console.log(action, action.actor, @player, action.type)

    if action.actor == @player()
      switch action.type
        when "tsumo", "chi", "pon", "reach"
          # @_start = new Date()
          analysis = new ShantenAnalysis(
              pai.id() for pai in @player().tehais,
              {allowedExtraPais: 1})
          # console.log("analyzed", new Date() - @_start)
          if @game().canHora(@player(), analysis)
            return @createAction(
                type: "hora",
                target: action.actor,
                pai: action.pai)
          else if @game().canReach(@player(), analysis)
            return @createAction(type: "reach")
          else if @player().reachState == "accepted"
            return @createAction(type: "dahai", pai: action.pai, tsumogiri: true)
          else
            dahai = @decideDahai(analysis)
            return @createAction(
                type: "dahai",
                pai: dahai,
                tsumogiri: action.type == "tsumo" && dahai.equal(action.pai))
    else
      switch action.type
        when "dahai"
          if @game().canHora(@player())
            return @createAction(
                type: "hora",
                target: action.actor,
                pai: action.pai)

    return null

  decideDahai: (analysis) ->

    console.log("  shanten", analysis.shanten())
    currentVector = new PaiSet(@player().tehais).array()
    goals = []
    for goal in analysis.goals()
      # If it's tenpai, tenpai must be kept because it has reached.
      # If shanten > 3, including goals with extra pais is too slow.
      if (analysis.shanten() >= 1 && analysis.shanten() <= 3) ||
          goal.shanten == analysis.shanten()
        goal.requiredBitVectors = @countVectorToBitVectors(goal.requiredVector)
        @calculateFan(goal)
        goals.push(goal)
    console.log("  goals", goals.length)
    #console.log("requiredBitVectors", new Date() - @_start)

    # for goal in goals
    #   console.log("goalVector", @countVectorToStr(goal.countVector))
    #   console.log({fan: goal.fan, points: goal.points, yakus: goal.yakus})
      # console.log("goalRequiredVector", countVectorToStr(goal.requiredVector))
      # console.log("goalThrowableVector", countVectorToStr(goal.throwableVector))
      # console.log("goalMentsus", ([m.type, new Pai(m.firstPid).toString()] for m in goal.mentsus))

    visiblePaiSet = new PaiSet()
    visiblePaiSet.addPais(@game().doraMarkers())
    visiblePaiSet.addPais(@player().tehais)
    for player in @game().players()
      visiblePaiSet.addPais(player.ho)
      for furo in player.furos
        visiblePaiSet.addPais(furo.pais())
    invisiblePaiSet = PaiSet.getAll()
    invisiblePaiSet.removePaiSet(visiblePaiSet)
    invisiblePids = (pai.id() for pai in invisiblePaiSet.toPais())
    #console.log("  visiblePaiSet", visiblePaiSet.toString())
    #console.log("invisiblePids", Pai.paisToStr(new Pai(pid) for pid in invisiblePids))

    numTsumos = 18
    numTries = 1000
    totalHoraVector = (0 for _ in [0...Pai.NUM_IDS])
    totalPointsVector = (0 for _ in [0...Pai.NUM_IDS])
    for i in [0...numTries]
      @shuffle(invisiblePids, numTsumos)
      tsumoVector = new PaiSet(new Pai(pid) for pid in invisiblePids[0...numTsumos]).array()
      tsumoBitVectors = @countVectorToBitVectors(tsumoVector)
      horaVector = (0 for _ in [0...Pai.NUM_IDS])
      pointsVector = (0 for _ in [0...Pai.NUM_IDS])
      #goalVector = (null for _ in [0...Pai.NUM_IDS])
      for goal in goals
        achieved = true
        for i in [0...tsumoBitVectors.length]
          if !goal.requiredBitVectors[i].isSubsetOf(tsumoBitVectors[i])
            achieved = false
            break
        if achieved
          for pid in [0...Pai.NUM_IDS]
            if goal.throwableVector[pid] > 0
              horaVector[pid] = 1
              if goal.points > pointsVector[pid]
                pointsVector[pid] = goal.points
              #goalVector[pid] = goal
      for pid in [0...Pai.NUM_IDS]
        if horaVector[pid] == 1
          ++totalHoraVector[pid]
          totalPointsVector[pid] += pointsVector[pid]
    #console.log("monte carlo", new Date() - @_start)

    maxHoraProb = -1 / 0
    maxExpectedPoints = -1 / 0
    maxPid = null
    for pid in [0...Pai.NUM_IDS]
      if currentVector[pid] > 0
        horaProb = totalHoraVector[pid] / numTries
        expectedPoints = totalPointsVector[pid] / numTries
        if expectedPoints > maxExpectedPoints
          maxExpectedPoints = expectedPoints
          maxPid = pid

    for pai in @player().tehais
      pid = pai.id()
      console.log("  ", pai.toString(), {
        prob: totalHoraVector[pid] / numTries,
        avgPt: Math.round(totalPointsVector[pid] / totalHoraVector[pid]),
        expPt: Math.round(totalPointsVector[pid] / numTries),
      })

    # Just returning new Pai(maxPid) doesn't work because it may be a red pai.
    for pai in @player().tehais
      if pai.id() == maxPid
        console.log("  decidedDahai", pai.toString())
        return pai
    throw "should not happen"

  shuffle: (array, n = array.length) ->
    for i in [0...n]
      j = i + Math.floor(Math.random() * (array.length - i))
      tmp = array[i]
      array[i] = array[j]
      array[j] = tmp
    return array

  countVectorToStr: (countVector) ->
    return new PaiSet({array: countVector}).toString()

  countVectorToBitVectors: (countVector) ->
    bitVectors = []
    for i in [1...5]
      bitVectors.push(new BitVector(c >= i for c in countVector))
    return bitVectors

  calculateFan: (goal) ->

    allPais = []
    for mentsu in goal.mentsus
      mentsu.pais = (new Pai(pid) for pid in mentsu.pids)
      for pai in mentsu.pais
        allPais.push(pai)
    goal.yakus = []
    goal.fan = 0

    menzen = true  # TODO
    if menzen
      goal.yakus.push("reach")
      ++goal.fan

    tanyao = Util.all allPais, (pai) ->
        !pai.isYaochu()
    if tanyao
      goal.yakus.push("tanyao")
      ++goal.fan

    # TODO Add janto criteria
    pinfu = Util.all goal.mentsus, (mentsu) ->
      mentsu.type != "kotsu"
    if pinfu
      goal.yakus.push("pinfu")
      ++goal.fan

    doras = @game().doras()
    for pai in allPais
      for dora in doras
        if pai.hasSameSymbol(dora)
          goal.yakus.push("dora")
          ++goal.fan

    # TODO Discard 5m when it has both 5m and 5mr
    for pai in @player().tehais
      if pai.red() && pai.removeRed().isIn(allPais)
        goal.yakus.push("akadora")
        ++goal.fan

    # TODO Calculate fu more accurately
    if pinfu
      goal.points = ManueAI.PINFU_FAN_TO_POINTS[goal.fan]
    else
      goal.points = ManueAI.NON_PINFU_FAN_TO_POINTS[goal.fan]

ManueAI.getAllPids = ->
  allPids = []
  for pid in [0...Pai.NUM_IDS]
    for i in [0...4]
      allPids.push(pid)
  return allPids

ManueAI.ALL_PIDS = ManueAI.getAllPids()
ManueAI.PINFU_FAN_TO_POINTS =
    [0, 1000, 2000, 3900, 7700, 8000, 12000, 12000, 16000, 16000, 16000, 24000, 24000, 32000]
ManueAI.NON_PINFU_FAN_TO_POINTS =
    [0, 1300, 2600, 5200, 8000, 8000, 12000, 12000, 16000, 16000, 16000, 24000, 24000, 32000]

module.exports = ManueAI
