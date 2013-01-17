#!/usr/bin/env coffee
#
# Copyright 2013 Artillery Games, Inc.
# Licensed under the MIT license.
#
# Author: Ian Langworth
#
# Inspired strongly by
# https://github.com/jaredhanson/passport-github/blob/master/examples/login/app.js

GitHubAPI = require 'github'
GitHubStrategy = require('passport-github').Strategy
async = require 'async'
express = require 'express'
fs = require 'fs'
http = require 'http'
moment = require 'moment'
optimist = require 'optimist'
passport = require 'passport'
path = require 'path'
stylus = require 'stylus'

argv = optimist
  .usage('Usage: $0 settings.json')
  .options('-h', alias: 'host', default: 'localhost')
  .options('-p', alias: 'port', default: 8000)
  .demand(1)
  .argv

settings = JSON.parse fs.readFileSync argv._[0]

# -------------------------------------------------------------------------
# GITHUB OAUTH INITIALIZATION
# -------------------------------------------------------------------------

passport.use new GitHubStrategy({
  clientID: settings.github.clientID
  clientSecret: settings.github.clientSecret
  callbackURL: settings.github.callbackURL
}, (accessToken, refreshToken, profile, done) ->
  process.nextTick ->
    return done null, { profile: profile, accessToken: accessToken }
)

passport.serializeUser (user, done) -> done null, user
passport.deserializeUser (user, done) -> done null, user

# -------------------------------------------------------------------------
# EXPRESS INITIALIZATION
# -------------------------------------------------------------------------

app = express()

app.configure ->
  app.set 'port', argv.port
  app.set 'views', "#{ __dirname }/views"
  app.set 'view engine', 'hjs'
  app.use express.favicon()
  app.use express.logger 'dev'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser settings.cookieSecret
  app.use express.session secret: settings.sessionSecret
  app.use passport.initialize()
  app.use passport.session()
  app.use app.router
  app.use stylus.middleware "#{ __dirname }/public"
  app.use express.static path.join "#{ __dirname }/public"

app.configure 'development', ->
  app.use express.errorHandler()

# -------------------------------------------------------------------------
# AUTHENTICATION HANDLERS
# -------------------------------------------------------------------------

app.get '/auth/github', passport.authenticate 'github', scope: 'repo'

app.get '/auth/github/callback',
  passport.authenticate('github', failureRedirect: '/error'),
  (req, res) ->
    res.redirect '/'

app.get '/logout', (req, res) ->
  req.logout()
  res.redirect '/'

ensureAuthenticated = (req, res, next) ->
  if req.isAuthenticated()
    return next()
  else
    res.redirect '/auth/github'

# -------------------------------------------------------------------------
# DASHBOARD
# -------------------------------------------------------------------------

app.get '/', ensureAuthenticated, (req, res) ->
  github = new GitHubAPI(version: '3.0.0')
  github.authenticate type: 'oauth', token: req.user.accessToken

  username = req.user.profile.username

  async.waterfall [

    (cb) ->
      github.pullRequests.getAll {
        user: settings.github.user
        repo: settings.github.repo
      }, cb

    (pulls, cb) ->
      iterator = (pull, pullCb) ->

        async.parallel [

          (cb2) ->
            github.pullRequests.getComments {
              user: settings.github.user
              repo: settings.github.repo
              number: pull.number
            }, cb2

          (cb2) ->
            github.issues.getComments {
              user: settings.github.user
              repo: settings.github.repo
              number: pull.number
            }, cb2

        ], (err, results) ->
          return pullCb err if err

          # Combine issue comments and pull comments, then sort.
          comments = results[0].concat results[1]
          comments.sort (a, b) -> if a.updated_at < b.updated_at then -1 else 1

          # Record number of comments.
          pull.num_comments = comments.length

          # Show relative time for last update.
          pull.last_update = moment(pull.updated_at).fromNow()

          # Pull names from comments.
          reviewers = {}

          # Convert title to reviewers.
          if match = pull.title.match /^([\w\/]+): /
            pull.title = pull.title.substr match[0].length
            names = (n.toLowerCase() for n in match[1].split /\//)

            # Convert "IAN/MARK" to ['statico', 'mlogan']
            for name in names
              if name of settings.reviewers
                reviewers[settings.reviewers[name]] = true
              else
                reviewers[name] = true

          # Is this pull a Work In Progress?
          if 'wip' of reviewers
            pull.class = 'ignore'
            pull.title = "WIP: #{ pull.title }"
            delete reviewers.wip

          # Is this pull a proposal?
          if 'proposal' of reviewers
            pull.class = 'info'
            pull.title = "PROPOSAL: #{ pull.title }"
            delete reviewers.proposal

          # Check for my username in reviewers.
          if username of reviewers
            pull.class = 'warning'

          # Check for my username in any comments.
          if username in (c.user.login for c in comments)
            pull.class = 'warning'

          # Check for GLHF in last few comments.
          if comments.length
            body = comments[comments.length - 1].body
            for config in settings.statuses
              if new RegExp(config.regex, 'i').test body
                pull.statusClass = config.class
                pull.status = config.title
                break
          if not pull.status
            if comments.length
              pull.statusClass = 'default'
              pull.status = 'Discussing'
            else
              pull.statusClass = 'info'
              pull.status = 'New'

          # Add reviewers list to pull object.
          pull.reviewers = (k for k, v of reviewers)

          pullCb()

      async.forEach pulls, iterator, (err) ->
        cb err, pulls

    # Sort the pulls based on update time.
    # TODO: Doesn't quite work...
    (pulls, cb) ->

      pulls.sort (a, b) ->
        if a.class == 'info'
          return -1 # Always at top.
        else if a.class == b.class
          if moment(a.updated_at).unix() > moment(b.updated_at).unix()
            return -1
          else
            return 1
        else
          if a.class == 'warning'
            return -1
          else
            return 1

      pulls.sort (a, b) ->
        if a.class == 'ignore'
          return 1 # Always at bottom.
        else
          return -1

      cb null, pulls

  ], (err, pulls) ->
    if err
      res.send 500, "Error: #{ err }"
    else
      res.render 'index',
        settings: settings
        profile: req.user.profile
        pulls: pulls

# -------------------------------------------------------------------------
# SERVER STARTUP
# -------------------------------------------------------------------------

http.createServer(app).listen argv.port, argv.host, ->
  console.log "Pull Request Viewer listening on port http://#{ argv.host }:#{ argv.port }"

