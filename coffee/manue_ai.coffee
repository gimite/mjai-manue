AI = require("./ai")
Pai = require("./pai")
PaiSet = require("./pai_set")
ShantenAnalysis = require("./shanten_analysis")

class ManueAI extends AI

  respondToAction: (action) ->

    #console.log(action, action.actor, @player, action.type)

    if action.actor == @player()
      switch action.type
        when "tsumo", "chi", "pon", "reach"
          analysis = new ShantenAnalysis(
              pai.id() for pai in @player().tehais,
              {allowedExtraPais: 1})
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
    goals = analysis.goals()
    console.log("  goals", goals.length)

    # console.log("goals", goals.length)
    # for goal in goals
      # console.log("goalVector", countVectorToStr(goal.countVector))
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
    #console.log("visiblePaiSet", visiblePaiSet.toString())
    #console.log("invisiblePids", Pai.paisToStr(new Pai(pid) for pid in invisiblePids))

    numTsumos = 18
    numTries = 1000
    totalHoraVector = (0 for _ in [0...Pai.NUM_IDS])
    for i in [0...numTries]
      @shuffle(invisiblePids, numTsumos)
      #invisiblePids = (pai.id() for pai in Pai.strToPais("1m 6m 4p"))
      tsumoVector = new PaiSet(new Pai(pid) for pid in invisiblePids[0...numTsumos]).array()
      #console.log("tsumoVector", @countVectorToStr(tsumoVector))
      horaVector = (0 for _ in [0...Pai.NUM_IDS])
      #goalVector = (null for _ in [0...Pai.NUM_IDS])
      for goal in goals
        achieved = true
        for pid in [0...Pai.NUM_IDS]
          if tsumoVector[pid] < goal.requiredVector[pid]
            achieved = false
        #console.log("goal", countVectorToStr(goal.requiredVector), achieved)
        if achieved
          for pid in [0...Pai.NUM_IDS]
            if goal.throwableVector[pid] > 0
              horaVector[pid] = 1
              #goalVector[pid] = goal
      for pid in [0...Pai.NUM_IDS]
        if horaVector[pid] == 1
          #console.log("  ", new Pai(pid).toString(), ":", countVectorToStr(goalVector[pid].countVector))
          ++totalHoraVector[pid];

    maxHoraProb = -1/0
    maxPid = null
    for pid in [0...Pai.NUM_IDS]
      if currentVector[pid] > 0
        horaProb = totalHoraVector[pid] / numTries
        console.log("  horaProb", new Pai(pid).toString(), horaProb)
        if horaProb > maxHoraProb
          maxHoraProb = horaProb
          maxPid = pid

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

ManueAI.getAllPids = ->
  allPids = []
  for pid in [0...Pai.NUM_IDS]
    for i in [0...4]
      allPids.push(pid)
  return allPids

ManueAI.ALL_PIDS = ManueAI.getAllPids()

module.exports = ManueAI
