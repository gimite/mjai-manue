AI = require("./ai")
Pai = require("./pai")
PaiSet = require("./pai_set")
ShantenAnalysis = require("./shanten_analysis")
BitVector = require("./bit_vector")
DangerEstimator = require("./danger_estimator")
Util = require("./util")

class ManueAI extends AI

  constructor: ->
    @_dangerEstimator = new DangerEstimator()

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
    candDahais = @getSafestDahais(analysis)
    return @getDahaiToMaximizeHoraProb(analysis, candDahais)

  getSafestDahais: (analysis) ->

    possibleDahais = []
    for pai in @player().tehais
      if Util.all possibleDahais, ((p) -> !p.equal(pai))
        possibleDahais.push(pai)

    safeProbs = {}
    for pai in possibleDahais
      safeProbs[pai.toString()] = 1
    hasReacher = false
    for player in @game().players()
      if player != @player() && player.reachState == "accepted"
        hasReacher = true
        scene = @_dangerEstimator.getScene(@game(), @player(), player)
        probInfos = {}
        for pai in possibleDahais
          if scene.anpai(pai)
            probInfo = {anpai: true}
            safeProb = 1
          else
            probInfo = @_dangerEstimator.estimateProb(scene, pai)
            features2 = []
            for feature in probInfo.features
              features2.push("#{feature.name} #{feature.value}")
            probInfo.features = features2
            safeProb = 1 - probInfo.prob
          safeProbs[pai.toString()] *= safeProb
          probInfos[pai.toString()] = probInfo
        console.log("danger", probInfos)

    if hasReacher && analysis.shanten() > 0
      maxSafeProb = -1 / 0
      maxPai = null
      for pai in possibleDahais
        safeProb = safeProbs[pai.toString()]
        console.log("safeProb", pai.toString(), safeProb)
        if safeProb > maxSafeProb
          maxSafeProb = safeProb
      return (pai for pai in possibleDahais when safeProbs[pai.toString()] == maxSafeProb)
    else
      return possibleDahais

  getDahaiToMaximizeHoraProb: (analysis, candDahais) ->

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

    visiblePaiSet = new PaiSet(@game().visiblePais(@player()))
    invisiblePaiSet = PaiSet.getAll()
    invisiblePaiSet.removePaiSet(visiblePaiSet)
    invisiblePids = (pai.id() for pai in invisiblePaiSet.toPais())
    #console.log("  visiblePaiSet", visiblePaiSet.toString())
    #console.log("invisiblePids", Pai.paisToStr(new Pai(pid) for pid in invisiblePids))

    # TODO Estimate this more accurately.
    numTsumos = Math.floor(@game().numPipais() / 4)
    console.log("  numTsumos", numTsumos)
    numTries = 1000
    totalHoraVector = (0 for _ in [0...Pai.NUM_IDS])
    totalPointsVector = (0 for _ in [0...Pai.NUM_IDS])
    totalYakuToFanVector = ({} for _ in [0...Pai.NUM_IDS])
    for i in [0...numTries]
      @shuffle(invisiblePids, numTsumos)
      tsumoVector = new PaiSet(new Pai(pid) for pid in invisiblePids[0...numTsumos]).array()
      tsumoBitVectors = @countVectorToBitVectors(tsumoVector)
      horaVector = (0 for _ in [0...Pai.NUM_IDS])
      pointsVector = (0 for _ in [0...Pai.NUM_IDS])
      yakuToFanVector = ({} for _ in [0...Pai.NUM_IDS])
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
                yakuToFanVector[pid] = {}
                for yaku in goal.yakus
                  [name, fan] = yaku
                  yakuToFanVector[pid][name] = fan
              #goalVector[pid] = goal
      for pid in [0...Pai.NUM_IDS]
        if horaVector[pid] == 1
          ++totalHoraVector[pid]
          totalPointsVector[pid] += pointsVector[pid]
          for name, fan of yakuToFanVector[pid]
            if name of totalYakuToFanVector[pid]
              totalYakuToFanVector[pid][name] += fan
            else
              totalYakuToFanVector[pid][name] = fan
    #console.log("monte carlo", new Date() - @_start)

    maxHoraProb = -1 / 0
    maxHoraProbPid = null
    maxExpectedPoints = -1 / 0
    maxExpectedPointsPid = null
    for pai in candDahais
      pid = pai.id()
      horaProb = totalHoraVector[pid] / numTries
      expectedPoints = totalPointsVector[pid] / numTries
      if horaProb > maxHoraProb
        maxHoraProb = horaProb
        maxHoraProbPid = pid
      if expectedPoints > maxExpectedPoints
        maxExpectedPoints = expectedPoints
        maxExpectedPointsPid = pid
      stats = {
        prob: totalHoraVector[pid] / numTries,
        avgPt: Math.round(totalPointsVector[pid] / totalHoraVector[pid]),
        expPt: Math.round(totalPointsVector[pid] / numTries),
      }
      for name, fan of totalYakuToFanVector[pid]
        stats[name] = Math.floor(fan / totalHoraVector[pid] * 1000) / 1000
      console.log("  ", pai.toString(), stats)

    if maxHoraProbPid != maxExpectedPointsPid
      gain =
        (((totalPointsVector[maxExpectedPointsPid] / numTries) / (totalPointsVector[maxHoraProbPid] / numTries)) - 1) *
            (totalHoraVector[maxHoraProbPid] / numTries)
      if gain >= 0.01
        for name, fan of totalYakuToFanVector[maxExpectedPointsPid]
          testAvgFan = fan / totalHoraVector[maxExpectedPointsPid]
          baseAvgFan = (totalYakuToFanVector[maxHoraProbPid][name] || 0) / totalHoraVector[maxHoraProbPid]
          if testAvgFan >= baseAvgFan + 0.1
            testPaiStr = new Pai(maxExpectedPointsPid).toString()
            basePaiStr = new Pai(maxHoraProbPid).toString()
            console.log("  choice based on #{name}: #{testPaiStr} (#{testAvgFan}) vs #{basePaiStr} (#{baseAvgFan})")

    # Just returning new Pai(maxPid) doesn't work because it may be a red pai.
    for pai in candDahais
      if pai.id() == maxExpectedPointsPid
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

    @addYaku(goal, "reach", 1, 0)

    tanyaochu =
        Util.all allPais, (p) ->
          !p.isYaochu()
    if tanyaochu
      @addYaku(goal, "tyc", 1)

    chantaiyao =
        Util.all goal.mentsus, (m) ->
          Util.any m.pais, (p) ->
            p.isYaochu()
    if chantaiyao
      @addYaku(goal, "cty", 2, 1)

    # TODO Consider ryanmen criteria
    pinfu =
        Util.all goal.mentsus, (m) =>
          m.type =="shuntsu" ||
              (m.type == "toitsu" && @game().yakuhaiFan(m.pais[0], @player()) == 0)
    if pinfu
      @addYaku(goal, "pf", 1, 0)

    doras = @game().doras()
    numDoras = 0
    for pai in allPais
      for dora in doras
        if pai.hasSameSymbol(dora)
          ++numDoras
    @addYaku(goal, "dr", numDoras)

    # TODO Discard 5m when it has both 5m and 5mr
    numAkadoras = 0
    for pai in @player().tehais
      if pai.red() && pai.removeRed().isIn(allPais)
        ++numAkadoras
    @addYaku(goal, "adr", numAkadoras)

    yakuhaiFan = 0
    for mentsu in goal.mentsus
      if mentsu.type == "kotsu" || mentsu.type == "kantsu"
        yakuhaiFan += @game().yakuhaiFan(mentsu.pais[0], @player())
    @addYaku(goal, "ykh", yakuhaiFan)

    ipeko =
        Util.any goal.mentsus, (m1) ->
          m1.type == "shuntsu" &&
              Util.any goal.mentsus, (m2) ->
                m2 != m1 && m2.type == "shuntsu" && m2.pais[0].hasSameSymbol(m1.pais[0])
    if ipeko
      @addYaku(goal, "ipk", 1, 0)

    sanshokuDojun =
        Util.any goal.mentsus, (m1) ->
          m1.type == "shuntsu" &&
              Util.all ["m", "p", "s"], (t) ->
                Util.any goal.mentsus, (m2) ->
                  m2.type == "shuntsu" &&
                      m2.pais[0].type() == t &&
                      m2.pais[0].number() == m1.pais[0].number()
    if sanshokuDojun
      @addYaku(goal, "ssj", 2, 1)

    ikkiTsukan =
        Util.any ["m", "p", "s"], (t) ->
          Util.all [1, 4, 7], (n) ->
            Util.any goal.mentsus, (m) ->
              m.type == "shuntsu" && m.pais[0].type() == t && m.pais[0].number() == n
    if ikkiTsukan
      @addYaku(goal, "ikt", 2, 1)

    toitoiho =
        Util.all goal.mentsus, (m) ->
            m.type != "shuntsu"
    if toitoiho
      @addYaku(goal, "tth", 2)

    chiniso =
        Util.any ["m", "p", "s"], (t) ->
          Util.all goal.mentsus, (m) ->
            m.pais[0].type() == t
    honiso =
        Util.any ["m", "p", "s"], (t) ->
          Util.all goal.mentsus, (m) ->
            m.pais[0].type() == t || m.pais[0].type() == "t"
    if chiniso
      @addYaku(goal, "cis", 6, 5)
    else if honiso
      @addYaku(goal, "his", 3, 2)

    # TODO Calculate fu more accurately
    if pinfu
      goal.points = ManueAI.PINFU_FAN_TO_POINTS[goal.fan]
    else
      goal.points = ManueAI.NON_PINFU_FAN_TO_POINTS[goal.fan]

  addYaku: (goal, name, menzenFan, kuiFan = menzenFan) ->
    # TODO Consider kui
    fan = menzenFan
    if fan > 0
      goal.yakus.push([name, fan])
      goal.fan += fan

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
