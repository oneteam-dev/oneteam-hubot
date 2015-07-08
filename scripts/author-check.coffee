# Description:
#   ask authors to check deploy
#
# Configuration:
#   HUBOT_GITHUB_TOKEN (required)
#   HUBOT_GITHUB_ORG
#
# Commands:
#   hubot ask checking <repo> on {qa,production} - Please check operation of <env> env.

GitHub = require 'github'
CSON = require 'cson-parser'
path = require 'path'
fs = require 'fs'

handleMap = CSON.parse fs.readFileSync path.resolve '.', 'data', 'handle-map.cson'

convertHandle = (hn)->
  handleMap[hn.toLowerCase()] || hn

module.exports = (robot) ->

  token = process.env.HUBOT_GITHUB_TOKEN
  if !token
    return robot.logger.error """
      author-check is not loaded due to missing configuration!
      #{__filename}
      HUBOT_GITHUB_TOKEN: #{token}
    """

  robot.respond /ask\s+(?:to\s+)?check(?:ing)?\s+([^\s]+)\s+(?:on\s+)([^\s]+)\s*$/i, (msg) ->
    [__, repo, env] = msg.match
    [user, repo] = repo.split '/' if repo.indexOf('/') != -1
    user ||= process.env.HUBOT_GITHUB_ORG

    titleRE = /^\d{4}\.\d{2}\.\d{2}\sproduction\sdeployment/

    getRepoIssues = (callback)->
      state = if env is 'staging' then 'open' else 'closed'

      try
        github = new GitHub version: '3.0.0'
        github.authenticate type: 'oauth', token: token
        github.issues.repoIssues {
          user
          state
          repo: realRepo
          per_page: 100
          sort: 'created'
          direction: 'desc'
        }, callback
      catch e
        callback null, e

    pickIssue = (issues)->
      try
        issues = issues.sort (a, b)->
          b.number - a.number
        for issue in issues
          if titleRE.test issue.title
            return issue
      catch e
        msg.send e.message

    collectAuthors = (body)->
      re = new RegExp "<\\!\\-\\-\\s+begin\\s+ckeck\\s+list\\s+for\\s+#{env}\\s+\\-\\->([^]+)<\\!\\-\\-\\s+end\\s+ckeck\\s+list\\s+for\\s+#{env}\\s+\\-\\->", "mi"
      body = (body.match(re) || [])[1]
      return unless body
      matches = body.match(/\-\s+\[\s+\].+(?:\r?\n\s+\-\s*)?(@.+)/g) || []
      authors = matches.map (m)->
        m.match(/@([\w\d]+)/)[1]
      res = []
      for author in authors
        author = convertHandle author
        res.push author if res.indexOf(author) == -1
      res

    notifyComplete = (issueUrl)->
      msg.send {
        staging: 'Completed operation check in QA env.'
        production: 'Completed operation check in Production env.'
      }[env] + " #{issueUrl}"
      msg.send "cronbot remove job with message hubot ask checking #{repo} on #{env}"

    notifyAuthors = (authors, issueUrl)->
      msg.send {
        qa: 'Please check operation in QA env.'
        production: 'Please check operation in Production env.'
      }[env] + "<@#{authors.join '> <@'}> #{ issueUrl }"

    do ->
      getRepoIssues (err, res)->
        return msg.reply err.message if err
        try
          issue = pickIssue res
          authors = collectAuthors issue?.body || ''
          if authors?.length > 0
            notifyAuthors authors, issue?.html_url
          else
            notifyComplete issue?.html_url
        catch e
          msg.reply e.message
