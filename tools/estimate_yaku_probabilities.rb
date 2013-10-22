$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")
require "pp"
require "mjai/archive"


include(Mjai)


verbose = false

archive = Archive.load(ARGV[0])
player_to_attrs = {}
archive.each_action() do |action|
  archive.dump_action(action) if verbose
  case action.type
    
    when :start_kyoku
      for player in archive.players
        player_to_attrs[player] = []
      end
    
    when :end_kyoku
    
    when :dahai
      pais = action.actor.tehais + action.actor.furos.map(){ |f| f.pais[0, 3] }.flatten()
      attr = {:num_yaochus => pais.count(){ |pai| pai.yaochu? }}
      player_to_attrs[action.actor].push(attr)

    when :hora
      p action.yakus
      pp player_to_attrs[action.actor]
      
  end
end
