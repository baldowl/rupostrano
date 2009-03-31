set :application, 'wonderful_application'
set :repository,  'svn+ssh://me@example.com/path/to/repository/trunk'
set :deploy_to, "/home/me/#{application}"

set :use_sudo, false
set :group_writable, false
set :change_ownership, false

role :app, 'me@production.example.com'

depend :remote, :gem, 'ruport', '=1.2.3'
depend :remote, :gem, 'ruport-util', '=0.10.0'
depend :remote, :gem, 'activerecord', '>1.15.0'
