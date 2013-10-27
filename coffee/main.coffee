TCPClientGame = require("./tcp_client_game")
TsumogiriAI = require("./tsumogiri_ai")
ManueAI = require("./manue_ai")

game = new TCPClientGame({
    url: "mjsonp://localhost:19001/default",
    name: "Manue",
    ai: new ManueAI(),
})
game.play()
