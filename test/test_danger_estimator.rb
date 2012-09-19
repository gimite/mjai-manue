$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/manue/danger_estimator"


class TC_DangerEstimator < Test::Unit::TestCase
    
    include(Mjai)
    include(Mjai::Manue)
    
    def setup()
    end
    
    def get_scene(params)
      default_params = {
          :anpais => [],
          :prereach_sutehais => [],
          :visible => [],
          :tehais => [],
          :doras => [],
          :bakaze => nil,
          :reacher_kaze => nil,
      }
      return DangerEstimator::Scene.new(default_params.merge(params))
    end
    
    def test_features()
      
      scene = get_scene({})
      assert(scene.tsupai(Pai.new("E")))
      assert(!scene.tsupai(Pai.new("1p")))
      
      scene = get_scene({:anpais => Pai.parse_pais("4p")})
      assert(scene.suji(Pai.new("1p")))
      assert(scene.weak_suji(Pai.new("1p")))
      assert(scene.suji(Pai.new("7p")))
      assert(scene.weak_suji(Pai.new("7p")))
      assert(!scene.suji(Pai.new("2p")))
      assert(!scene.weak_suji(Pai.new("2p")))
      assert(!scene.suji(Pai.new("1m")))
      assert(!scene.weak_suji(Pai.new("1m")))
      
      scene = get_scene({:anpais => Pai.parse_pais("17p")})
      assert(scene.suji(Pai.new("4p")))
      assert(scene.weak_suji(Pai.new("4p")))
      
      scene = get_scene({:anpais => Pai.parse_pais("1p")})
      assert(!scene.suji(Pai.new("4p")))
      assert(scene.weak_suji(Pai.new("4p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("5p4p"),
          :prereach_sutehais => Pai.parse_pais("5p4p"),
      })
      assert(scene.reach_suji(Pai.new("1p")))
      assert(!scene.reach_suji(Pai.new("2p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p"),
          :prereach_sutehais => Pai.parse_pais("1p"),
      })
      assert(scene.reach_suji(Pai.new("4p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p"),
          :prereach_sutehais => Pai.parse_pais("1p"),
      })
      assert(scene.urasuji(Pai.new("2p")))
      assert(scene.urasuji(Pai.new("5p")))
      assert(!scene.urasuji(Pai.new("3p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1pESW2p"),
          :prereach_sutehais => Pai.parse_pais("1pESW2p"),
      })
      assert(scene.early_urasuji(Pai.new("5p")))
      assert(!scene.early_urasuji(Pai.new("3p")))
      assert(scene.reach_urasuji(Pai.new("3p")))
      assert(!scene.reach_urasuji(Pai.new("5p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p6p"),
          :prereach_sutehais => Pai.parse_pais("1p6p"),
      })
      assert(scene.aida4ken(Pai.new("2p")))
      assert(scene.aida4ken(Pai.new("5p")))
      assert(!scene.aida4ken(Pai.new("3p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("3p"),
          :prereach_sutehais => Pai.parse_pais("3p"),
      })
      assert(scene.matagisuji(Pai.new("1p")))
      assert(scene.matagisuji(Pai.new("2p")))
      assert(scene.matagisuji(Pai.new("4p")))
      assert(scene.matagisuji(Pai.new("5p")))
      assert(!scene.matagisuji(Pai.new("6p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("2p"),
          :prereach_sutehais => Pai.parse_pais("2p"),
      })
      assert(scene.matagisuji(Pai.new("1p")))
      assert(scene.matagisuji(Pai.new("4p")))
      assert(!scene.matagisuji(Pai.new("3p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("3pES7pW"),
          :prereach_sutehais => Pai.parse_pais("3pES7pW"),
      })
      assert(scene.late_matagisuji(Pai.new("9p")))
      assert(!scene.late_matagisuji(Pai.new("1p")))
      
      # TODO Add test for rest of features.
      
    end
    
    
end
