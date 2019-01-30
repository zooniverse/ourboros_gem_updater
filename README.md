## Ouroboros Gem Updater
Code responsible to update the Ouroboros API application using [Dependabot Core][dependabot-core] OSS library through some ruby scripts.

### Setup and usage

* `bundle install`
* Get a GITHUB access token and make it available via the `GITHUB_OAUTH_TOKEN` environment variable.

### The scripts

* `dependabot_update_all_gems.rb` Update all the gems
* `dependabot_update_existing_outdated_gem_prs.rb` Update outdated existing pull requests only (needs a rebase, etc)
* `dependabot_update_existing_prs.rb` Update all existing pull requests (Can be forced)
* `dependabot_update_named_gem.rb` Update a specific gem dependency.
