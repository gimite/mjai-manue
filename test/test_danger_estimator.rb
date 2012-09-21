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
          :anpais => Pai.parse_pais("4pE4s"),
          :prereach_sutehais => Pai.parse_pais("4pE"),
      })
      assert(scene.prereach_suji(Pai.new("1p")))
      assert(!scene.prereach_suji(Pai.new("1s")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p"),
          :prereach_sutehais => Pai.parse_pais("1p"),
      })
      assert(scene.urasuji(Pai.new("2p")))
      assert(scene.urasuji(Pai.new("5p")))
      assert(!scene.urasuji(Pai.new("3p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("5p"),
          :prereach_sutehais => Pai.parse_pais("5p"),
      })
      assert(scene.urasuji(Pai.new("1p")))
      assert(scene.urasuji(Pai.new("4p")))
      assert(scene.urasuji(Pai.new("6p")))
      assert(scene.urasuji(Pai.new("9p")))
      assert(!scene.urasuji(Pai.new("2p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p5p"),
          :prereach_sutehais => Pai.parse_pais("1p"),
      })
      assert(!scene.urasuji(Pai.new("2p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1pESW1s"),
          :prereach_sutehais => Pai.parse_pais("1pESW1s"),
      })
      assert(scene.early_urasuji(Pai.new("5p")))
      assert(!scene.early_urasuji(Pai.new("5s")))
      assert(scene.reach_urasuji(Pai.new("5s")))
      assert(!scene.reach_urasuji(Pai.new("5p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p5s"),
          :prereach_sutehais => Pai.parse_pais("1p5s"),
      })
      assert(scene.urasuji_of_5(Pai.new("1s")))
      assert(!scene.urasuji_of_5(Pai.new("2p")))
      
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
          :anpais => Pai.parse_pais("3p4p"),
          :prereach_sutehais => Pai.parse_pais("3p"),
      })
      assert(!scene.matagisuji(Pai.new("1p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("3pES7pW"),
          :prereach_sutehais => Pai.parse_pais("3pES7pW"),
      })
      assert(scene.late_matagisuji(Pai.new("9p")))
      assert(!scene.early_matagisuji(Pai.new("9p")))
      assert(scene.early_matagisuji(Pai.new("1p")))
      assert(!scene.late_matagisuji(Pai.new("1p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("3pES7p"),
          :prereach_sutehais => Pai.parse_pais("3pES7p"),
      })
      assert(scene.reach_matagisuji(Pai.new("9p")))
      assert(!scene.reach_matagisuji(Pai.new("1p")))
      
      scene = get_scene({
          :anpais => Pai.parse_pais("1p"),
          :prereach_sutehais => Pai.parse_pais("1p"),
      })
      assert(scene.senkisuji(Pai.new("3p")))
      assert(scene.senkisuji(Pai.new("6p")))
      assert(!scene.senkisuji(Pai.new("2p")))
      
      # 出そうとしている牌自身はカウントしない。
      scene = get_scene({
          :visible => Pai.parse_pais("1p1p"),
      })
      assert(scene.__send__(:"visible>=1", Pai.new("1p")))
      assert(!scene.__send__(:"visible>=2", Pai.new("1p")))
      
      scene = get_scene({
          :visible => Pai.parse_pais("1p1p1p"),
      })
      assert(scene.__send__(:"visible>=2", Pai.new("1p")))
      assert(!scene.__send__(:"visible>=3", Pai.new("1p")))
      
      scene = get_scene({
          :visible => Pai.parse_pais("4p"),
      })
      assert(scene.__send__(:"suji_visible<=1", Pai.new("1p")))
      assert(!scene.__send__(:"suji_visible<=0", Pai.new("1p")))
      
      scene = get_scene({
          :visible => Pai.parse_pais("4p4p"),
      })
      assert(scene.__send__(:"suji_visible<=2", Pai.new("1p")))
      assert(!scene.__send__(:"suji_visible<=1", Pai.new("1p")))
      
      # TODO Add test for rest of features.
      
    end
    
    
end
