TCPClientGame = require("./tcp_client_game")
TsumogiriAI = require("./tsumogiri_ai")

game = new TCPClientGame({
    url: "mjsonp://localhost:19001/default",
    name: "tsumogiri",
    ai: new TsumogiriAI(),
})
game.play()
