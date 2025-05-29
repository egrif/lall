# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "lall"
  spec.version       = "0.1.0"
  spec.authors       = ["Eric Griffith"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "LOTUS environment comparison CLI using lotus."
  spec.description   = "A Ruby CLI tool for comparing LOTUS configuration values across multiple environments, using the lotus command to fetch environment data."
  spec.homepage      = "https://github.com/yourusername/lall"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"] + ["README.md", "bin/lall", "config/settings.yml"]
  spec.executables   = ["lall"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "yaml"
  spec.add_runtime_dependency "optparse"
  spec.add_runtime_dependency "open3"
  spec.add_development_dependency "rake"
end
