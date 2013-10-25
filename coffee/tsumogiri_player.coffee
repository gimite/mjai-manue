Player = require("./player")

class TsumogiriPlayer extends Player

  respondToAction: (action) ->
    if action.actor == this
      switch action.type
        when "tsumo"
          return @createAction({
              type: "dahai",
              pai: action.pai,
              tsumogiri: true,
          })
    return null

module.exports = TsumogiriPlayer
