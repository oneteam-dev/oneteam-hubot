# Description:
#   ask authors to check deploy
#
# Configuration:
#   HUBOT_GITHUB_ORG
#
# Commands:
#   hubot ask checking <repo> on {staging,production} - Please check operation of <env> env.

module.exports = (robot) ->

  robot.respond /ask\s+(?:to\s+)?check(?:ing)?\s+([^\s]+)\s+(?:on\s+)([^\s]+)\s*$/i, (msg) ->
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

    getPullRequests = (callback)->
      try
        robot.getGitHubApi().pullRequests.getAll {
          user
          repo
          head
          base
          sort: 'created'
          direction: 'desc'
          per_page: 1
          state: 'closed'
        }, callback
      catch e
        console.error e
        callback null, e

    collectAuthors = (body)->
      if matches = body.match /- \[ \]\s+.+\((@[^\)]+)\)/img
        authors = []
        for m in matches
          if hm = m.match /@([\w-]+)/g
            authors = authors.concat hm
        res = []
        for author in authors
          author = robot.convertHandle author
          res.push author if res.indexOf(author) == -1
        res

    notifyComplete = (issueUrl)->
      msg.send "<!here> Completed operation check in #{env} env :white_check_mark: #{issueUrl}"
      msg.send "cronbot remove job with message #{msg.message.text}"

    notifyAuthors = (authors, issueUrl)->
      msg.send "Please check operation in #{env} env :bow: <@#{authors.join '> <@'}> #{ issueUrl }"

    do ->
      getPullRequests (err, res)->
        return msg.reply err.message if err
        unless issue = res[0]
          msg.reply "No deploy pull request for #{env}."
          return
        try
          authors = collectAuthors issue?.body || ''
          if authors?.length > 0
            notifyAuthors authors, issue?.html_url
          else
            notifyComplete issue?.html_url
        catch e
          msg.reply e.message
