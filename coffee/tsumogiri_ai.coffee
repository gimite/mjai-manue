AI = require("./ai")

class TsumogiriAI extends AI

  respondToAction: (action) ->
    if action.actor == @player()
      switch action.type
        when "tsumo"
          return @createAction({
              type: "dahai",
              pai: action.pai,
              tsumogiri: true,
          })
    return null

module.exports = TsumogiriAI
