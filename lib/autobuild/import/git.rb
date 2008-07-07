require 'fileutils'
require 'autobuild/subcommand'
require 'autobuild/importer'
require 'utilrb/module/attr_predicate'

module Autobuild
    class Git < Importer
        # Creates an importer which tracks the given repository
        # and branch. +source+ is [repository, branch]
        #
        # This importer uses the 'git' tool to perform the
        # import. It defaults to 'svn' and can be configured by
        # doing 
	#   Autobuild.programs['git'] = 'my_git_tool'
        def initialize(repository, branch = nil, options = {})
            @repository = repository.to_str
            @branch     = branch || 'master'
            super(options)
        end

        attr_accessor :repository
        attr_accessor :branch
        attr_predicate :merge?

        def update(package)
            Dir.chdir(package.srcdir) do
                if !File.directory?('.git')
                    raise "#{package.srcdir} is not a git repository"
                end

                # Fetch and merge if the merge leads to a fast-forward
                Subprocess.run(package.name, :import, Autobuild.tool('git'), 'fetch')
                common_commit = `git merge-base HEAD FETCH_HEAD`.chomp
                head_commit   = `git rev-parse HEAD`.chomp
                fetch_commit  = `git rev-parse FETCH_HEAD`.chomp

                if common_commit != fetch_commit
                    if merge? || common_commit == head_commit
                        Subprocess.run(package.name, :import, Autobuild.tool('git'), 'merge', 'FETCH_HEAD')
                    else
                        raise "importing the current version would lead to a non fast-forward"
                    end
                end
            end
        end

        def checkout(package)
            base_dir = File.expand_path('..', package.srcdir)
            if !File.directory?(base_dir)
                FileUtils.mkdir_p base_dir
            end

            Subprocess.run(package.name, :import,
                Autobuild.tool('git'), 'clone', '-o', 'autobuild',
                repository, package.srcdir)

            Dir.chdir(package.srcdir) do
                Subprocess.run(package.name, :import, Autobuild.tool('git'),
                    'reset', '--hard', "autobuild/#{branch}")
            end
        end
    end

    # Creates a git importer which gets the source for the given repository and branch
    # URL +source+. The allowed values in +options+ are described in SVN.new.
    def self.git(repository, branch, options = {})
        Git.new(repository, branch, options)
    end
end

