# coding: utf-8

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "mjai/manue/danger_estimator"


@opts = OptionParser.getopts("v", "start:", "n:", "o:", "min_gap:")

estimator = Mjai::Manue::DangerEstimator.new()
estimator.verbose = @opts["v"]
estimator.min_gap = @opts["min_gap"].to_f() / 100.0

action = ARGV.shift()
case action
  
  when "extract"
    raise("-o is missing") if !@opts["o"]
    if ARGV.empty?
      paths = Dir["mjlog/mjlog_pf4-20_n?/*.mjlog"].sort().reverse()
    else
      paths = ARGV
    end
    paths = paths[paths.index(@opts["start"])..-1] if @opts["start"]
    paths = paths[0, @opts["n"].to_i()] if @opts["n"]
    estimator.extract_features_from_files(paths, @opts["o"])

  when "single"
    estimator.calculate_single_probabilities(ARGV[0])
    
  when "interesting"
    
    tsupai_criteria = [
      
      {"tsupai" => true},
      {"tsupai" => true, "sangenpai" => true},
      {"tsupai" => true, "sangenpai" => false},
      {"tsupai" => true, "fanpai" => true},
      {"tsupai" => true, "fanpai" => false},
      
    ]
    
    supai_criteria = [
      
      {"tsupai" => false},
      {"tsupai" => false, "suji" => true},
      {"tsupai" => false, "suji" => false},
      {"tsupai" => false, "suji" => false, "weak_suji" => true},
      {"tsupai" => false, "suji" => false, "weak_suji" => false},
      
      {"tsupai" => false, "suji" => true, "reach_suji" => true},
      
      {"tsupai" => false, "suji" => false, "outer_early_sutehai" => true},
      {"tsupai" => false, "suji" => false, "outer_prereach_sutehai" => true},
      
      {"tsupai" => false, "suji" => false, "urasuji" => true},
      {"tsupai" => false, "suji" => false, "early_urasuji" => true},
      {"tsupai" => false, "suji" => false, "reach_urasuji" => true},
      {"tsupai" => false, "suji" => false, "aida4ken" => true},
      {"tsupai" => false, "suji" => false, "matagisuji" => true},
      {"tsupai" => false, "suji" => false, "late_matagisuji" => true},
      {"tsupai" => false, "suji" => false, "senkisuji" => true},
      {"tsupai" => false, "suji" => false, "early_senkisuji" => true},
      
      {"tsupai" => false, "suji" => false, "chances<=0" => true},
      {"tsupai" => false, "suji" => false, "chances<=0" => false, "chances<=1" => true},
      {"tsupai" => false, "suji" => false, "chances<=1" => false, "chances<=2" => true},
      {"tsupai" => false, "suji" => false, "chances<=2" => false, "chances<=3" => true},
      {"tsupai" => false, "suji" => false, "chances<=3" => false},
      
      {"tsupai" => false, "suji" => false, "visible>=3" => true},
      {"tsupai" => false, "suji" => false, "visible>=3" => false, "visible>=2" => true},
      {"tsupai" => false, "suji" => false, "visible>=2" => false, "visible>=1" => true},
      {"tsupai" => false, "suji" => false, "visible>=1" => false},
      
      {"tsupai" => false, "suji" => false, "dora" => true},
      {"tsupai" => false, "suji" => false, "dora_suji" => true},
      {"tsupai" => false, "suji" => false, "dora_matagi" => true},
      
      {"tsupai" => false, "suji" => false, "in_tehais>=4" => true},
      {"tsupai" => false, "suji" => false, "in_tehais>=4" => false, "in_tehais>=3" => true},
      {"tsupai" => false, "suji" => false, "in_tehais>=3" => false, "in_tehais>=2" => true},
      {"tsupai" => false, "suji" => false, "in_tehais>=2" => false},
      
      {"tsupai" => false, "suji" => false, "suji_in_tehais>=4" => true},
      {"tsupai" => false, "suji" => false, "suji_in_tehais>=4" => false, "suji_in_tehais>=3" => true},
      {"tsupai" => false, "suji" => false, "suji_in_tehais>=3" => false, "suji_in_tehais>=2" => true},
      {"tsupai" => false, "suji" => false, "suji_in_tehais>=2" => false},

      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=8" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=8" => false, "same_type_in_prereach>=7" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=7" => false, "same_type_in_prereach>=6" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=6" => false, "same_type_in_prereach>=5" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=5" => false, "same_type_in_prereach>=4" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=4" => false, "same_type_in_prereach>=3" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=3" => false, "same_type_in_prereach>=2" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=2" => false, "same_type_in_prereach>=1" => true},
      {"tsupai" => false, "suji" => false,
          "same_type_in_prereach>=1" => false},
      
    ]
    
    criteria = []
    criteria += tsupai_criteria
    criteria += supai_criteria
    for criterion in supai_criteria
      for i in 1..5
        n_criterion = criterion
        if i > 1
          n_criterion = criterion.merge({"%d<=n<=%d" % [i, 10 - i] => true })
        end
        if i < 5
          n_criterion = n_criterion.merge({"%d<=n<=%d" % [i + 1, 10 - (i + 1)] => false })
        end
        criteria.push(n_criterion)
      end
    end
    
    estimator.calculate_probabilities(ARGV[0], criteria)
    
  when "benchmark"
    estimator.create_kyoku_probs_map(ARGV[0], INTERESTING_CRITERIA)
    
  when "tree"
    root = estimator.generate_decision_tree(ARGV[0])
    estimator.render_decision_tree(root, "all")
    if @opts["o"]
      open(@opts["o"], "wb"){ |f| Marshal.dump(root, f) }
    end
    
  when "dump_tree"
    root = open(ARGV[0], "rb"){ |f| Marshal.load(f) }
    estimator.render_decision_tree(root, "all")
    
  else
    raise("unknown action")

end
