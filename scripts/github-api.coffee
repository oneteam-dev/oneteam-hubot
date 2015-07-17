GitHub = require 'github'

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
