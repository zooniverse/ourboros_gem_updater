## Ouroboros Gem Updater
Code responsible to update the Ouroboros API application using [Dependabot Core][dependabot-core] OSS library through some ruby scripts.

Heavily inspired by https://github.com/dependabot/dependabot-script

### Setup and usage

* Get a GITHUB access token and make it available via the `GITHUB_OAUTH_TOKEN` environment variable.

##### Via Docker
* `docker-compose build`
* `docker-compose run --rm gem_updater bundle exec ruby script_name.rb`

##### With your own ruby install
* `bundle install` Then run the scripts yourself

### List known security issues with bundler audit
* `docker-compose run --rm gem_updater bash`
    + `bundle audit > outdated_gems.txt`

### The scripts

* `dependabot_update_named_gem.rb`
    + Update a specific gem dependency.

**Use these to update existing Pull Requests**
* `dependabot_update_existing_outdated_gem_prs.rb`
    + Update outdated existing pull requests only (needs a rebase, etc)
    + Requires `outdated_gems.txt` file with advisories
* `dependabot_update_existing_prs.rb`
    + Update all existing pull requests (Can be forced)

**Careful with this one**
* `dependabot_update_all_gems.rb`
    + Update all the gems literally!
    + Avoid running this one as it will update all libs on a non-maintained code base and open PR's for each one. + Best to target the known security issue gems only.
