TCPClientGame = require("./tcp_client_game")
TsumogiriAI = require("./tsumogiri_ai")
ManueAI = require("./manue_ai")

game = new TCPClientGame({
    url: process.argv[2],
    name: "Manue014",
    ai: new ManueAI(),
})
game.play()
