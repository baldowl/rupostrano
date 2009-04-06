--- !ruby/object:Gem::Specification 
name: rupostrano
version: !ruby/object:Gem::Version 
  version: 0.0.1
platform: ruby
authors: 
- Emanuele Vicentini
autorequire: 
bindir: bin

date: 2009-04-06 00:00:00 +02:00
default_executable: 
dependencies: 
- !ruby/object:Gem::Dependency 
  name: capistrano
  type: :runtime
  version_requirement: 
  version_requirements: !ruby/object:Gem::Requirement 
    requirements: 
    - - ">="
      - !ruby/object:Gem::Version 
        version: 2.4.0
    version: 
description: Ruport + Capistrano = Rupostrano :-)
email: emanuele.vicentini@gmail.com
executables: 
- rupostrano
extensions: []

extra_rdoc_files: 
- LICENSE.rdoc
- README.rdoc
files: 
- bin/rupostrano
- lib/rupostrano.rb
- LICENSE.rdoc
- Manifest
- Rakefile
- README.rdoc
- rupostrano.gemspec
- templates/Capfile
- templates/deploy.rb
- templates/environment.rb
has_rdoc: true
homepage: http://github.com/baldowl/rupostrano
post_install_message: 
rdoc_options: 
- --line-numbers
- --inline-source
- --title
- Rupostrano
- --main
- README.rdoc
require_paths: 
- lib
required_ruby_version: !ruby/object:Gem::Requirement 
  requirements: 
  - - ">="
    - !ruby/object:Gem::Version 
      version: "0"
  version: 
required_rubygems_version: !ruby/object:Gem::Requirement 
  requirements: 
  - - ">="
    - !ruby/object:Gem::Version 
      version: "1.2"
  version: 
requirements: []

rubyforge_project: rupostrano
rubygems_version: 1.3.1
specification_version: 2
summary: Ruport + Capistrano = Rupostrano :-)
test_files: []
