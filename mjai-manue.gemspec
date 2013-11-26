Gem::Specification.new do |s|
  
  s.name = "mjai-manue"
  s.version = "0.0.2"
  s.authors = ["Hiroshi Ichikawa"]
  s.email = ["gimite+github@gmail.com"]
  s.summary = "Japanese Mahjong AI."
  s.description = "Japanese Mahjong AI."
  s.homepage = "https://github.com/gimite/mjai-manue"
  s.license = "New BSD"
  s.rubygems_version = "1.2.0"
  
  s.files = Dir["bin/*"] + Dir["lib/**/*"] + Dir["share/**/*"]
  s.require_paths = ["lib"]
  s.executables = Dir["bin/*"].map(){ |pt| File.basename(pt) }
  s.has_rdoc = true
  s.extra_rdoc_files = []
  s.rdoc_options = []

  s.add_dependency("mjai", [">= 0.0.1"])
  
end
