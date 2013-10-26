Pai = require("./pai")

class Action

  # TODO fromJson, toJson

  constructor: (params) ->
    for k, v of params
      this[k] = v

  merge: (extraParams) ->
    params = {}
    for name, type of Action.FIELD_SPECS
      camelName = Action.camelCase(name)
      if camelName in this
        params[camelName] = this[camelName]
    for k, v of extraParams
      params[k] = v
    return new Action(params)

  toJson: ->
    hash = {}
    for name, type of Action.FIELD_SPECS
      obj = this[Action.camelCase(name)]
      if obj == undefined then continue
      switch type
        when "number", "string", "boolean", "numbers", "strings", "booleans", "yakus"
          plain = obj
        when "pai"
          plain = obj.toString()
        when "player"
          plain = obj.id
        when "pais"
          plain = (c.toString() for c in obj)
        when "pais_list"
          plain = ((g.toString() for g in c) for c in obj)
        else
          throw "unknown type"
      hash[name] = plain
    return JSON.stringify(hash)

Action.FIELD_SPECS = {
    type: "string",
    reason: "string",
    actor: "player",
    target: "player",
    pai: "pai",
    consumed: "pais",
    pais: "pais",
    tsumogiri: "boolean",
    id: "number",
    bakaze: "pai",
    kyoku: "number",
    honba: "number",
    kyotaku: "number",
    oya: "player",
    dora_marker: "pai",
    uradora_markers: "pais",
    tehais: "pais_list",
    uri: "string",
    names: "strings",
    hora_tehais: "pais",
    yakus: "yakus",
    fu: "number",
    fan: "number",
    hora_points: "number",
    tenpais: "booleans",
    deltas: "numbers",
    scores: "numbers",
    text: "string",
    message: "string",
}

Action.fromJson = (json, game) ->
  hash = JSON.parse(json)
  params = {}
  for name, plain of hash
    type = Action.FIELD_SPECS[name]
    if type
      params[Action.camelCase(name)] = Action.plainToObj(plain, type, game)
  return new Action(params)

Action.plainToObj = (plain, type, game) ->
  switch type
    when "number", "string", "boolean", "numbers", "strings", "booleans", "yakus"
      return plain
    when "player"
      return game.players()[plain]
    when "pai"
      return new Pai(plain)
    when "pais"
      return Action.plainsToObjs(plain, "pai", game)
    when "pais_list"
      return Action.plainsToObjs(plain, "pais", game)
    else
      throw "unknown type: #{type}"

Action.plainsToObjs = (plains, type, game) ->
  return (Action.plainToObj(plain, type, game) for plain in plains)

Action.camelCase = (name) ->
  return name.replace(/_(.)/, (_, ch) -> ch.toUpperCase())

module.exports = Action
