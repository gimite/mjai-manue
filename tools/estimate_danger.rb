# coding: utf-8

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "pp"
require "mjai/manue/danger_estimator"


include(Mjai::Manue)


class Interesting
    
    TSUPAI_CRITERIA = [
      
      {"tsupai" => true},
      {"tsupai" => true, "sangenpai" => true},
      {"tsupai" => true, "sangenpai" => false},
      {"tsupai" => true, "fanpai" => true},
      {"tsupai" => true, "fanpai" => false},
      {"tsupai" => true, "visible>=3" => true},
      {"tsupai" => true, "visible>=3" => false, "visible>=2" => true},
      {"tsupai" => true, "visible>=2" => false, "visible>=1" => true},
      {"tsupai" => true, "visible>=1" => false},
      
    ]
    
    SUPAI_CRITERIA = [
      
      {
        :base => {"tsupai" => false, "suji" => false},
        :test => [
          {"tsupai" => false, "suji" => true},
        ],
      },
      
      {
        :base => {"tsupai" => false, "suji" => false},
        :test => [
          {"tsupai" => false, "suji" => false, "weak_suji" => true},
          {"tsupai" => false, "suji" => false, "weak_suji" => false},
        ],
      },
      
      {
        :base => {"tsupai" => false, "suji" => true},
        :test => [
          {"tsupai" => false, "suji" => true, "4<=n<=6" => false},  # 表筋
          {"tsupai" => false, "suji" => true, "4<=n<=6" => true},  # 中筋
          {"tsupai" => false, "suji" => true, "reach_suji" => true},
          {"tsupai" => false, "suji" => true, "prereach_suji" => true},
          {"tsupai" => false, "suji" => true, "prereach_suji" => false},
        ],
      },
      
      {
        :base => {"tsupai" => false, "suji" => false},
        :test => [
          
          {"tsupai" => false, "suji" => false, "outer_early_sutehai" => true},
          {"tsupai" => false, "suji" => false, "outer_prereach_sutehai" => true},
          
          {"tsupai" => false, "suji" => false, "urasuji" => true},
          {"tsupai" => false, "suji" => false, "early_urasuji" => true},
          {"tsupai" => false, "suji" => false, "reach_urasuji" => true},
          {"tsupai" => false, "suji" => false, "urasuji_of_5" => true},
          {"tsupai" => false, "suji" => false, "aida4ken" => true},
          {"tsupai" => false, "suji" => false, "matagisuji" => true},
          {"tsupai" => false, "suji" => false, "early_matagisuji" => true},
          {"tsupai" => false, "suji" => false, "late_matagisuji" => true},
          {"tsupai" => false, "suji" => false, "reach_matagisuji" => true},
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
          
          {"tsupai" => false, "suji" => false, "suji_visible<=0" => true},
          {"tsupai" => false, "suji" => false, "suji_visible<=0" => false, "suji_visible<=1" => true},
          {"tsupai" => false, "suji" => false, "suji_visible<=1" => false, "suji_visible<=2" => true},
          {"tsupai" => false, "suji" => false, "suji_visible<=2" => false, "suji_visible<=3" => true},
          {"tsupai" => false, "suji" => false, "suji_visible<=3" => false},
          
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
          {"tsupai" => false, "suji" => false, "suji_in_tehais>=2" => false, "suji_in_tehais>=1" => true},
          {"tsupai" => false, "suji" => false, "suji_in_tehais>=1" => false},

          # same_type_in_prereach>=5 is too rare.
          {"tsupai" => false, "suji" => false,
              "same_type_in_prereach>=4" => true},
          {"tsupai" => false, "suji" => false,
              "same_type_in_prereach>=4" => false, "same_type_in_prereach>=3" => true},
          {"tsupai" => false, "suji" => false,
              "same_type_in_prereach>=3" => false, "same_type_in_prereach>=2" => true},
          {"tsupai" => false, "suji" => false,
              "same_type_in_prereach>=2" => false, "same_type_in_prereach>=1" => true},
          {"tsupai" => false, "suji" => false,
              "same_type_in_prereach>=1" => false},
          
        ],
      },
      
    ]
    
end


class DumpListener
    
    def initialize(filter_spec)
      @filter = {}
      for field in filter_spec.split(/&/)
        (k, v) = field.split(/:/)
        @filter[k] = v
      end
    end
    
    def on_dahai(params)
      #pp [:dahai, params]
      cands = params[:candidates].select(){ |c| meet_filter(c) }
      if !cands.empty?
        puts(params[:game].path)
        params[:game].dump_action(params[:action])
        puts("reacher: %d" % params[:reacher].id)
        for cand in cands
          puts("candidate %s: hit=%d, %s" % [
              cand[:pai],
              cand[:hit] ? 1 : 0,
              DangerEstimator.feature_vector_to_str(cand[:feature_vector])])
        end
        puts("=" * 80)
      end
    end
    
    def meet_filter(cand)
      for k, v in @filter
        if k == "hit"
          if cand[:hit] != (v == "1")
            return false
          end
        else
          if DangerEstimator.get_feature_value(cand[:feature_vector], k) != (v == "1")
            return false
          end
        end
      end
      return true
    end
    
end


def get_number_criteria(base_criterion)
  result = []
  for i in 1..5
    criterion = base_criterion
    if i > 1
      name = "%d<=n<=%d" % [i, 10 - i]
      if criterion.has_key?(name) && !criterion[name]
        criterion = nil
      else
        criterion = criterion.merge({name => true})
      end
    end
    if i < 5 && criterion
      name = "%d<=n<=%d" % [i + 1, 10 - (i + 1)]
      if criterion.has_key?(name) && criterion[name]
        criterion = nil
      else
        criterion = criterion.merge({name => false})
      end
    end
    result.push(criterion)
  end
  return result
end

def create_points_file(path, nodes, gap)
  open(path, "w") do |f|
    nodes.each_with_index() do |node, i|
      if node
        f.puts([i + 1 + gap, node.average_prob * 100.0, node.conf_interval[0] * 100.0, node.conf_interval[1] * 100.0].join("\t"))
      end
    end
  end
end

action = ARGV.shift()
@opts = OptionParser.getopts("v", "start:", "n:", "o:", "min_gap:", "filter:")

estimator = DangerEstimator.new()
estimator.verbose = @opts["v"]
estimator.min_gap = @opts["min_gap"].to_f() / 100.0

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
    estimator.extract_features_from_files(
        paths, @opts["o"], @opts["filter"] ? DumpListener.new(@opts["filter"] || "") : nil)

  when "single"
    estimator.calculate_single_probabilities(ARGV[0])
    
  when "interesting"
    
    criteria = []
    criteria += Interesting::TSUPAI_CRITERIA
    for entry in Interesting::SUPAI_CRITERIA
      criteria += [entry[:base]] + entry[:test]
    end
    for entry in Interesting::SUPAI_CRITERIA
      criteria += get_number_criteria(entry[:base])
      for test_criterion in entry[:test]
        criteria += get_number_criteria(test_criterion)
      end
    end
    
    result = estimator.calculate_probabilities(ARGV[0], criteria.select(){ |c| c })
    if @opts["o"]
      open(@opts["o"], "wb") do |f|
        Marshal.dump(result, f)
      end
    end
    
  when "interesting_graph"
    result = open(ARGV[0], "rb"){ |f| Marshal.load(f) }
    id = 0
    for entry in Interesting::SUPAI_CRITERIA
      for test_criterion in entry[:test]
        base_n_criteria = get_number_criteria(entry[:base])
        test_n_criteria = get_number_criteria(test_criterion)
        create_points_file("exp/graphs/#{id}.base.points", (0...5).map(){ |i| result[base_n_criteria[i]] }, 0.0)
        create_points_file("exp/graphs/#{id}.test.points", (0...5).map(){ |i| result[test_n_criteria[i]] }, 0.05)
        base_title = entry[:base].inspect.gsub(/["\\]/){ "\\" + $& }
        test_title = test_criterion.inspect.gsub(/["\\]/){ "\\" + $& }
        spec = <<-"EOS"
          set terminal png size 640,480 font "/usr/share/fonts/opentype/ipafont/ipag.ttf"
          set output "exp/graphs/#{id}.graph.png"
          set xrange [0:6]
          set yrange [0:25]
          set xlabel "牌の数字"
          set ylabel "放銃率 [%]"
          set xtics ("1,9" 1, "2,8" 2, "3,7" 3, "4,6" 4, "5" 5)
          plot  "exp/graphs/#{id}.base.points" using 1:2:3:4 with yerrorbars title "#{base_title}", \\
            "exp/graphs/#{id}.test.points" using 1:2:3:4 with yerrorbars title "#{test_title}"
        EOS
        open("exp/graphs/#{id}.plot", "w"){ |f| f.write(spec) }
        system("gnuplot exp/graphs/#{id}.plot")
        id += 1
      end
    end
    open("exp/graphs/graphs.html", "w") do |f|
      for i in 0...id
        f.puts("<div><img src='#{i}.graph.png'></div>")
      end
    end
    
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
