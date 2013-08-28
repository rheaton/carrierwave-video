# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "carrierwave-video/version"

Gem::Specification.new do |s|
  s.name        = "carrierwave-video"
  s.version     = Carrierwave::Video::VERSION
  s.authors     = ["rheaton"]
  s.email       = ["rachelmheaton@gmail.com"]
  s.homepage    = "https://github.com/rheaton/carrierwave-video"
  s.summary     = %q{Carrierwave extension that uses ffmpeg to transcode videos.}
  s.description = %q{Transcodes to html5-friendly videos.}

  s.rubyforge_project = "carrierwave-video"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec", ">= 2.10.0"
  s.add_development_dependency "rake"

  s.add_runtime_dependency 'streamio-ffmpeg'
  s.add_runtime_dependency 'carrierwave'
  s.requirements << 'ruby, version 1.9 or greater'
  s.requirements << 'ffmpeg, version 0.11.1 or greater with libx256, libfaac, libtheora, libvorbid, libvpx enabled'
end
