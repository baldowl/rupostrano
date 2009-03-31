require 'capistrano/recipes/deploy/scm'
require 'capistrano/recipes/deploy/strategy'

def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

_cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
_cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

# =========================================================================
# These variables may be set in the client capfile if their default values
# are not sufficient.
# =========================================================================

_cset :scm, :subversion
_cset :deploy_via, :copy
_cset :copy_strategy, :export
_cset :copy_compression, :bzip2
_cset :user, 'www-data'
_cset :group, 'www-data'

_cset(:deploy_to) { "/u/apps/#{application}" }
_cset(:revision)  { source.head }

# =========================================================================
# These variables should NOT be changed unless you are very confident in
# what you are doing. Make sure you understand all the implications of your
# changes if you do decide to muck with these!
# =========================================================================

_cset(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
_cset(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env('LC_ALL', 'C') { `#{cmd}` } } }

_cset(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }

_cset(:release_name)      { set :deploy_timestamped, true; Time.now.strftime('%Y%m%dT%H%M%S%z') }

_cset :version_dir,       'releases'
_cset :shared_dir,        'shared'
_cset :current_dir,       'current'

_cset(:releases_path)     { File.join(deploy_to, version_dir) }
_cset(:shared_path)       { File.join(deploy_to, shared_dir) }
_cset(:current_path)      { File.join(deploy_to, current_dir) }
_cset(:release_path)      { File.join(releases_path, release_name) }

_cset(:releases)          { capture("ls -x #{releases_path}").split.sort }
_cset(:current_release)   { File.join(releases_path, releases.last) }
_cset(:previous_release)  { File.join(releases_path, releases[-2]) }

_cset(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
_cset(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
_cset(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp }

_cset(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

# some tasks, like symlink, need to always point at the latest release, but
# they can also (occassionally) be called standalone. In the standalone case,
# the timestamped release_path will be inaccurate, since the directory won't
# actually exist. This variable lets tasks like symlink work either in the
# standalone case, or during deployment.
_cset(:latest_release) { exists?(:deploy_timestamped) ? release_path : current_release }

# =========================================================================
# These are helper methods that will be available to your recipes.
# =========================================================================

# Auxiliary helper method for the `deploy:check' task. Lets you set up your
# own dependencies.
def depend(location, type, *args)
  deps = fetch(:dependencies, {})
  deps[location] ||= {}
  deps[location][type] ||= []
  deps[location][type] << args
  set :dependencies, deps
end

# Temporarily sets an environment variable, yields to a block, and restores
# the value when it is done.
def with_env(name, value)
  saved, ENV[name] = ENV[name], value
  yield
ensure
  ENV[name] = saved
end

# =========================================================================
# These are the tasks that are available to help with deploying web apps,
# and specifically, Rails applications. You can have cap give you a summary
# of them with `cap -T'.
# =========================================================================

namespace :deploy do
  desc <<-DESC
    Deploys your project. This calls both `setup' and `update'.
  DESC
  task :default do
    setup
    update
  end

  desc <<-DESC
    Prepares one or more servers for deployment. Before you can use any of \
    the Capistrano deployment tasks with your project, you will need to make \
    sure all of your servers have been prepared with `cap setup'. When you \
    add a new server to your cluster, you can easily run the setup task on \
    just that server by specifying the HOSTS environment variable:

      $ cap HOSTS=new.server.com setup

    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, releases_path, shared_path]
    dirs += %w(config).map { |d| File.join(shared_path, d) }
    cmd = "umask 02 && mkdir -p #{dirs.join(' ')}"
    invoke_command cmd, :via => run_method
    cmd = "chown -R #{user}:#{group} #{deploy_to}"
    invoke_command cmd, :via => run_method if fetch(:change_ownership, false)
  end

  desc <<-DESC
    Copies your project and updates the symlink. It does this in a \
    transaction, so that if either `update_code' or `symlink' fail, all \
    changes made to the remote servers will be rolled back, leaving your \
    system in the same state it was in before `update' was invoked.
  DESC
  task :update do
    transaction do
      update_code
      symlink
    end
  end

  desc <<-DESC
    Copies your project to the remote servers. This is the first stage of \
    any deployment; moving your updated code and assets to the deployment \
    servers. You will rarely call this task directly, however; instead, you \
    should call the `deploy' task (to do a complete deploy).

    You will need to make sure you set the :scm variable to the source \
    control software you are using (it defaults to :subversion), and the \
    :deploy_via variable to the strategy you want to use to deploy (it \
    defaults to :copy).
  DESC
  task :update_code, :except => { :no_release => true } do
    on_rollback { invoke_command "rm -rf #{release_path}; true", :via => run_method }
    strategy.deploy!
    share_resources
    finalize_update
  end

  desc <<-DESC
    [internal] Set up shared copies of key configuration files. This is \
    called by update_code after the basic deploy ends. config/environment.rb \
    is copied in the shared directory, if it's not already there.
  DESC
  task :share_resources, :except => { :no_release => true } do
    shared_config = File.join(shared_path, 'config')
    files = ['environment.rb']
    shared_files = files.map {|f| File.join(shared_config, f)}
    files.map! {|f| File.join(latest_release, "config/#{f}")}
    shared_files.each_with_index do |f, i|
      run "if [ ! -f #{f} ]; then cp #{files[i]} #{f}; fi"
    end
  end

  desc <<-DESC
    [internal] This task set up symlinks to the shared directory and then \
    will make the release group-writable (if the :group_writable variabile \
    is set to true).
  DESC
  task :finalize_update, :except => { :no_release => true } do
    cmd = "rm -f #{latest_release}/config/environment.rb && \
      ln -s #{shared_path}/config/environment.rb #{latest_release}/config/environment.rb"
    invoke_command cmd, :via => run_method
    cmd = "chmod -R g+w #{latest_release}"
    invoke_command cmd, :via => run_method if fetch(:group_writable, true)
    cmd = "chown -R #{user}:#{group} #{latest_release}"
    invoke_command cmd, :via => run_method if fetch(:change_ownership, true)
  end

  desc <<-DESC
    Updates the symlink to the most recently deployed version. Capistrano \
    works by putting each new release of your application in its own \
    directory. When you deploy a new version, this task's job is to update \
    the `current' symlink to point at the new version. You will rarely need \
    to call this task directly; instead, use the `deploy' task (which \
    performs a complete deploy) or the 'update' task (which does everything \
    except `setup').
  DESC
  task :symlink, :except => { :no_release => true } do
    on_rollback { invoke_command "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true", :via => run_method }
    cmd = "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
    invoke_command cmd, :via => run_method
  end

  desc <<-DESC
    Copy files to the currently deployed version. This is useful for \
    updating files piecemeal, such as when you need to quickly deploy only a \
    single file. Some files, such as updated templates, images, or \
    stylesheets, might not require a full deploy, and especially in \
    emergency situations it can be handy to just push the updates to \
    production, quickly.

    To use this task, specify the files and directories you want to copy as \
    a comma-delimited list in the FILES environment variable. All \
    directories will be processed recursively, with all files being pushed \
    to the deployment servers. Any file or directory starting with a '.' \
    character will be ignored.

      $ cap deploy:upload FILES=templates,controller.rb
  DESC
  task :upload, :except => { :no_release => true } do
    files = (ENV['FILES'] || '').
      split(',').
      map { |f| f.strip!; File.directory?(f) ? Dir["#{f}/**/*"] : f }.
      flatten.
      reject { |f| File.directory?(f) || File.basename(f)[0] == ?. }

    abort 'Please specify at least one file to update (via the FILES environment variable)' if files.empty?

    files.each do |file|
      content = File.open(file, 'rb') { |f| f.read }
      put content, File.join(current_path, file)
    end
  end

  desc <<-DESC
    Rolls back to the previously deployed version. The `current' symlink \
    will be updated to point at the previously deployed version, and then \
    the current release will be removed from the servers.
  DESC
  task :rollback, :except => { :no_release => true } do
    if releases.length < 2
      abort 'could not rollback the code because there is no prior release'
    else
      invoke_command "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}", :via => run_method
    end
  end

  desc <<-DESC
    Clean up old releases. By default, the last 5 releases are kept on each \
    server (though you can change this with the keep_releases variable). All \
    other deployed revisions are removed from the servers. By default, this \
    will use sudo to clean up the old releases, but if sudo is not available \
    for your environment, set the :use_sudo variable to false instead.
  DESC
  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 5).to_i
    if count >= releases.length
      logger.important 'no old releases to clean up'
    else
      logger.info "keeping #{count} of #{releases.length} deployed releases"

      directories = (releases - releases.last(count)).map { |release|
        File.join(releases_path, release) }.join(' ')

      invoke_command "rm -rf #{directories}", :via => run_method
    end
  end

  desc <<-DESC
    Test deployment dependencies. Checks things like directory permissions, \
    necessary utilities, and so forth, reporting on the things that appear \
    to be incorrect or missing. This is good for making sure a deploy has a \
    chance of working before you actually run `cap deploy'.

    You can define your own dependencies, as well, using the `depend' \
    method:

      depend :remote, :gem, 'tzinfo', '>=0.3.3'
      depend :local, :command, 'svn'
      depend :remote, :directory, '/u/depot/files'
  DESC
  task :check, :except => { :no_release => true } do
    dependencies = strategy.check!

    other = fetch(:dependencies, {})
    other.each do |location, types|
      types.each do |type, calls|
        if type == :gem
          dependencies.send(location).command(fetch(:gem_command, 'gem')).or("`gem' command could not be found. Try setting :gem_command")
        end

        calls.each do |args|
          dependencies.send(location).send(type, *args)
        end
      end
    end

    if dependencies.pass?
      puts 'You appear to have all necessary dependencies installed'
    else
      puts 'The following dependencies failed. Please check them and try again:'
      dependencies.reject { |d| d.pass? }.each do |d|
        puts "--> #{d.message}"
      end
      abort
    end
  end

  namespace :pending do
    desc <<-DESC
      Displays the `diff' since your last deploy. This is useful if you want \
      to examine what changes are about to be deployed. Note that this might \
      not be supported on all SCM's.
    DESC
    task :diff, :except => { :no_release => true } do
      system(source.local.diff(current_revision))
    end

    desc <<-DESC
      Displays the commits since your last deploy. This is good for a \
      summary of the changes that have occurred since the last deploy. Note \
      that this might not be supported on all SCM's.
    DESC
    task :default, :except => { :no_release => true } do
      from = source.next_revision(current_revision)
      system(source.local.log(from))
    end
  end
end
