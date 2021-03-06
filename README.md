# Pull Request Viewer

This application provides an alternative interface to viewing pull requests on GitHub. It sorts, highlights and categorizes pull requests based on our workflow.

![screenshot](http://i.imgur.com/Bcg4aaP.png)

## Notable features

* Uses GitHub for authentication & authorization
* Highlights PRs involving you
* Parses the last comment of a PR to set a status label
* If PR titles begin with reviewer usernames `foo:` or `foo/bar/baz:`, those GitHub usernames will become the reviewers. (See also GITHUB_USERNAME_ALIASES below.)
* If PR titles begin with `everyone` or `all`, all reviewers will be added
* PR titles beginning with `WIP` are considered Works In Progress and are greyed out
* PRs older than a month are hidden
* Lists everyone involved in commenting in a PR
* Shows and sorts by last update time
* Shows the source branch name
* Shows CI build status

## Getting started

1. Follow the [Heroku Getting Started guide](https://devcenter.heroku.com/articles/quickstart) if you haven't already.
1. Create an app on the [GitHub authorized applications page](https://github.com/settings/applications)
1. Clone this repo and `cd` to it.
1. Run `npm install` and then `npm install -g nodemon coffee-script`
1. Create a `.env` file that looks like the sample below.
1. Run `npm run dev`

### Sample `.env` file

    GITHUB_REPOS=artillery/awesomesauce,artillery/spacelaser
    GITHUB_CLIENT_ID=NNNNNNNNNNNNNNNNNNNN
    GITHUB_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    GITHUB_CALLBACK_URL=http://localhost:8000/auth/github/callback

### Optional additional env vars

#### `GITHUB_FORCE_REVIEWERS`

This is a list of GitHub usernames who should always review PRs from certain repos. This is in a comma-separated list in the format `<user>/<repo>:reviewer`. For multiple forced reviewers on the same repo, repeat the `<user>/<repo>` tuple with different usernames. For example:

    GITHUB_FORCE_REVIEWERS=foo/bar:user1,foo/bar:user2,baz/quux:user3

#### `GITHUB_USERNAME_ALIASES`

If your development group uses real names instead of GitHub usernames then it's easier to prefix a PR title with "Bob:" instead of "superl33th4ck3r:". `GITHUB_USERNAME_ALIASES` is a comma-separated list in the format `<alias>:<username>`. Any alias will be substituted for the GitHub username. For example:

    GITHUB_USERNAME_ALIASES=joe:superl33th4ck3r,bob:megauser

And your PR title could be "JOE/BOB: Fixes the thing."

### Deploying to Heroku

1. If creating a new app, run `heroku create` and then set each config var using `heroku config` (read docs [here](https://devcenter.heroku.com/articles/config-vars)]
1. Make sure the app runs locally with Foreman: `foreman start web`
1. To deploy, run `git push heroku`

### Credits

* Favicon from [Octicons by GitHub](https://www.iconfinder.com/icons/298789/git_pull_request_icon#size=128)

--------------------------------------------------------------------
Copyright 2013 Artillery Games, Inc. Licensed under the MIT license.
