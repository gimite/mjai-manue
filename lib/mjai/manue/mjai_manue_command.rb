require "optparse"

require "mjai/tcp_client_game"
require "mjai/manue/player"


module Mjai
  
  module Manue
    
    
    class MjaiManueCommand
        
        def self.execute(argv)
          Thread.abort_on_exception = true
          $stdout.sync = true
          opts = OptionParser.getopts(argv, "", "t:progress_prob", "name:")
          url = ARGV.shift()
          game = TCPClientGame.new({
              :player => Mjai::Manue::Player.new({:score_type => opts["t"].intern()}),
              :url => url,
              :name => opts["name"] || "manue",
          })
          game.play()
        end
        
    end
    
    
  end
  
end
