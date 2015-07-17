# Description:
#   Common GitHub API Getter
#
# Configuration:
#   HUBOT_GITHUB_TOKEN (required)

GitHub = require 'github'
CSON = require 'cson-parser'
path = require 'path'
fs = require 'fs'

module.exports = (robot) ->
  token = process.env.HUBOT_GITHUB_TOKEN
  github = null

  if !token
    return robot.logger.error """
      deployment is not loaded due to missing configuration!
      #{__filename}
      HUBOT_GITHUB_TOKEN: #{token}
    """

  robot.getGitHubApi = ->
    github ||= new GitHub version: '3.0.0'
    github.authenticate type: 'oauth', token: token
    github


  handleMap = CSON.parse fs.readFileSync path.resolve '.', 'data', 'handle-map.cson'

  robot.convertHandle = (hn)->
    hn = hn.substring(1) if hn[0] == '@'
    handleMap[hn.toLowerCase()] || hn

  robot.respondError = (msg, err) ->
    if err?.message
      errmsg = err.message
      try
        errmsg = JSON.parse(errmsg)?.message
      msg.reply errmsg
      return yes
    no


