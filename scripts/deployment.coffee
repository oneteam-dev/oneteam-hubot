# Description:
#   deploy <repo> to <env>
#
# Configuration:
#   HUBOT_GITHUB_TOKEN (required)
#   HUBOT_GITHUB_ORG
#
# Commands:
#   hubot deploy <repo> to <env> - deploy <repo> to the specified environment

require 'date-utils'
eco    = require 'eco'
fs     = require 'fs'
path   = require 'path'

module.exports = (robot) ->

  try
    template = eco.compile fs.readFileSync(path.resolve(__dirname, '..', 'templates/deployment.eco'), 'utf-8')
  catch e
    console.error e
    return

  compareCommits = (param, callback) ->
    robot.getGitHubApi().repos.compareCommits param, callback

  getIssue = (param, callback) ->
    robot.getGitHubApi().issues.getRepoIssue param, callback

  createPullRequest = (param, callback) ->
    robot.getGitHubApi().pullRequests.create param, callback

  hr = (length, char = '-') ->
    ret = ''
    while ret.length < length
      ret += char
    ret

  respondError = (msg, err) ->
    if err?.message
      errmsg = err.message
      try
        errmsg = JSON.parse(errmsg)?.message
      msg.reply errmsg
      return yes
    no

  robot.respond /\s*deploy\s+([^\s]+)\s+to\s+([^\s]+)/, (msg) ->
    [__, repo, env] = msg.match
    [user, repo] = repo.split '/' if repo.indexOf('/') != -1
    user ||= process.env.HUBOT_GITHUB_ORG

    if env is 'production'
      head = 'deployment/staging'
      base = 'deployment/production'
    else if env is 'staging'
      head = 'master'
      base = 'deployment/staging'
    else
      msg.reply "I don't know such an environment: `#{env}`."
      return

    compareCommits { user, repo, base, head }, (err, data) ->
      return if respondError msg, err
      {commits} = data
      unless commits?.length > 0
        msg.reply "#{env} environment is up to date."
        return
      issues = {}
      remainingIssueNums = []
      noIssueCommits = []

      getIssues = (callback) ->
        if remainingIssueNums.length == 0
          do callback
          return
        number = do remainingIssueNums.shift
        getIssue { repo, user, number }, (err, data) ->
          return if respondError msg, err
          issues[number].title = "##{number} #{data.title}"
          getIssues callback

      ignoreRE = new RegExp "^Merge pull request #\\d+ from #{user}/(deployment/staging|master)"
      messages = []

      for commit in commits
        commitMessage = commit?.commit?.message
        continue if ignoreRE.test commitMessage
        users = []
        if (login = commit?.author?.login) and users.indexOf(login) == -1
          users.push login
        if (login = commit?.committer?.login) and users.indexOf(login) == -1
          users.push login

        unless commit.parents.length > 1
          messages.push "- #{users[0] + ':' if users[0]} #{commitMessage}"

        if m = commitMessage?.match /GH\-(\d+)|#(\d+)/ig
          for i in m
            n = i.replace /[^\d]/g, ''
            issues[n] ||= { users: [] }
            issues[n].users = issues[n].users.concat users
            issues[n].users = issues[n].users.filter (e, i) ->
              users.indexOf(e) == i
            if remainingIssueNums.indexOf(n) == -1
              remainingIssueNums.push n
         else
           noIssueCommits.push { users, title: "#{commit.sha} #{commitMessage}" }
      msg.send """
      Creating pull request: `#{head}` to `#{base}` of https://github.com/#{user}/#{repo}
      #{messages.length} update#{ if messages.length then 's are' else ' is' } going to be deployed:
      #{messages.join '\n'}
      """

      getIssues ->
        {envelope} = msg
        title = "#{new Date().toYMD('.')} #{env} deployment by #{envelope.user.name}"
        ciURL = "https://circleci.com/gh/#{user}/#{repo}/tree/#{encodeURIComponent base}"
        checkList = []
        createListItem = (v) ->
          "- [ ] #{v.title} #{ if v.users?.length > 0 then "(@#{v.users.join(', @')})" else '' }"
        checkList.push createListItem v for k, v of issues
        checkList.push createListItem v for v in noIssueCommits
        body = template {
          checkList
          env
          user
          repo
          hr
          base
          envelope
          ciURL
        }
        createPullRequest {
          body
          title
          base
          head
          user
          repo
        }, (err, data) ->
          return if respondError msg, err
          msg.send """
          Created pull request #{data.html_url}
          Continue deployment by merging manually or close to cancel.
          You can check build status on #{ciURL}
          """

