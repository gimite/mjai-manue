TCPClientGame = require("./tcp_client_game")
TsumogiriPlayer = require("./tsumogiri_player")

game = new TCPClientGame({
    url: "mjsonp://localhost:19001/default",
    name: "tsumogiri",
    player: new TsumogiriPlayer(),
})
game.play()
