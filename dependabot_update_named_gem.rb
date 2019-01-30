# This script is designed to be copied into an interactive Ruby session, to
# give you an idea of how the different classes in Dependabot Core fit together.
#
# It's used regularly by the Dependabot team to manually debug issues, so should
# always be up-to-date.

require 'pry'

require "dependabot/file_fetchers"
require "dependabot/file_parsers"
require "dependabot/update_checkers"
require "dependabot/file_updaters"
require "dependabot/pull_request_creator"

# GitHub credentials with write permission to the repo you want to update
# (so that you can create a new branch, commit and pull request).
# If using a private registry it's also possible to add details of that here.

credentials =
  [{
    "type" => "git_source",
    "host" => "github.com",
    "username" => "x-access-token",
    "password" => ENV['GITHUB_OAUTH_TOKEN']
  }]

# Full name of the GitHub repo you want to create pull requests for.
repo_name = "zooniverse/Ouroboros"

# Directory where the base dependency files are.
directory = "/"

# Name of the package manager you'd like to do the update for. Options are:
# - bundler
# - pip (includes pipenv)
# - npm_and_yarn
# - maven
# - cargo
# - hex
# - composer
# - submodules
# - docker
package_manager = "bundler"

source = Dependabot::Source.new(
  provider: "github",
  repo: repo_name,
  directory: directory
)

##############################
# Fetch the dependency files #
##############################
fetcher = Dependabot::FileFetchers.for_package_manager(package_manager).new(
  source: source,
  credentials: credentials,
  target_branch: nil,
)

files = fetcher.files
commit = fetcher.commit

##############################
# Parse the dependency files #
##############################
parser = Dependabot::FileParsers.for_package_manager(package_manager).new(
  dependency_files: files,
  source: source,
  credentials: credentials,
)

dependencies = parser.parse

# Name of the dependency you'd like to update. (Alternatively, you could easily
# modify this script to loop through all the dependencies returned by
# `parser.parse`.)

dependency_name = "rack-ssl"
dep = dependencies.find { |d| d.name == dependency_name }

#########################################
# Get update details for the dependency #
#########################################
checker = Dependabot::UpdateCheckers.for_package_manager(package_manager).new(
  dependency: dep,
  dependency_files: files,
  credentials: credentials,
)

checker.up_to_date?
can_update_package = checker.can_update?(requirements_to_unlock: :own)
unless can_update_package
  raise StandardError.new("#{dep.name} - Can not update the package deps without unlocking")
end

updated_deps = checker.updated_dependencies(requirements_to_unlock: :own)


#####################################
# Generate updated dependency files #
#####################################
updater = Dependabot::FileUpdaters.for_package_manager(package_manager).new(
  dependencies: updated_deps,
  dependency_files: files,
  credentials: credentials,
)

updated_files = updater.updated_dependency_files

########################################
# Create a pull request for the update #
########################################
pr_creator = Dependabot::PullRequestCreator.new(
  source: source,
  base_commit: commit,
  dependencies: updated_deps,
  files: updated_files,
  credentials: credentials
)
pr_creator.create
