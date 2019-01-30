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
require "dependabot/pull_request_updater"

# GitHub credentials with write permission to the repo you want to update
# (so that you can create a new branch, commit and pull request).
# If using a private registry it's also possible to add details of that here.

FORCE_PR_UPDATE = false

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

source = Dependabot::Source.new(
  provider: "github",
  repo: repo_name,
  directory: directory
)

# get our hands on raw github client
github_client = Dependabot::GithubClientWithRetries.new(
  access_token: credentials.first["password"],
  api_endpoint: source.api_endpoint
)

# list all the open PR's
github_client.pull_requests(repo_name, state: 'open')

# store the gh pr requests for all pages
repo_pull_requests = []

# deal with busted paging in octokit
# https://github.com/octokit/octokit.rb/issues/732#issuecomment-237794222
puts "Requesting all pull requests from #{repo_name}"
last_response = github_client.last_response
while true
  next_page_gh_pull_requests = last_response.data

  next_page = last_response.rels[:next]
  break unless next_page

  next_page_gh_pull_requests.each do |pr|

    # Add other checks here
    # like it failed the test suite?
    # https://developer.github.com/v3/checks/suites/#list-check-suites-for-a-specific-ref

    # only take the dependabot PRs that aren't up to date
    is_dependabot_pr = pr.head.label.include?("zooniverse:dependabot")
    latest_commit = pr.base.sha == base_commit
    is_master_branch = pr.base.ref == "master"
    up_to_date_with_master = latest_commit && is_master_branch

    if is_dependabot_pr && !up_to_date_with_master
      repo_pull_requests << pr
    end
  end

  # manual page handling - load the next page of data and loop
  last_response = next_page.get
end

##############################
# Fetch the dependency files #
##############################
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
fetcher = Dependabot::FileFetchers.for_package_manager(package_manager).new(
  source: source,
  credentials: credentials,
  target_branch: nil,
)

files = fetcher.files
base_commit = fetcher.commit

##############################
# Parse the dependency files #
##############################
parser = Dependabot::FileParsers.for_package_manager(package_manager).new(
  dependency_files: files,
  source: source,
  credentials: credentials,
)

dependencies = parser.parse

## only update the PR's for the outdated gems
outdated_gem_prs = []
PR_TITLE_GEM_NAME_REGEX = /\ABump\s(.+)\sfrom/i.freeze
repo_pull_requests.each do |pr|

  if title_gem_name = pr.title.match(PR_TITLE_GEM_NAME_REGEX)
    pr_gem_name = title_gem_name[1]
  else
    raise StandardError(
      "Can't find the gem name from the PR title - #{pr.title}" \
      "must be a non-gem update PR, this shouldn't happen!"
    )
  end

  # collect all the outdated gem PRs
  if outdated_gem_names.include?(pr_gem_name.downcase)
    unless dep = dependencies.find { |d| d.name == pr_gem_name }
      raise StandardError.new("Can't find the dep, for #{pr_gem_name}")
    end
    outdated_gem_prs << { pr: pr, dep: dep }
  end
end

# for each outdated gem PR object
outdated_gem_prs.each do |outdated_gem_pr|

  pr = outdated_gem_pr[:pr]
  dep = outdated_gem_pr[:dep]

  if FORCE_PR_UPDATE

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
      puts "#{dep.name} - Can not update the package deps without unlocking"
      next
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

    updater = Dependabot::PullRequestUpdater.new(
      source: source,
      base_commit: base_commit,
      files: updated_files,
      credentials: credentials,
      pull_request_number: pr.number
    )

    # seems some of these updates can result in no changes to the code
    # but will still leave a PR open
    pr_update_response = updater.update
    puts "Updated PR #{pr.html_url}"
  end
end

puts "Finished updating all the PR's for outdated gems: #{outdated_gem_names.join(',')}"
