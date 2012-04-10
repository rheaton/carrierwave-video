# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "carrierwave-video/version"

Gem::Specification.new do |s|
  s.name        = "carrierwave-video"
  s.version     = Carrierwave::Video::VERSION
  s.authors     = ["rheaton"]
  s.email       = ["rachelmheaton@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Carrierwave extension that uses ffmpeg to transcode videos.}
  s.description = %q{Transcodes to html5-friendly videos.}

  s.rubyforge_project = "carrierwave-video"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"

  s.add_runtime_dependency 'streamio-ffmpeg'#, :git => 'git://github.com/stakach/streamio-ffmpeg.git'
  s.requirements << 'ffmpeg, version 0.10 or greater with libx256, libfaac, libtheora, libvorbid, libvpx enabled'
end
