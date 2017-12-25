# Description:
#   Create daily report on Oneteam
#
# Configuration
#   HUBOT_ONETEAM_TEAM_NAME
#   HUBOT_ONETEAM_TEAM_KEY
#   HUBOT_ONETEAM_RECIPIENTS
#   HUBOT_ONETEAM_${USERNAME}_TOKEN
#   HUBOT_ONETEAM_${USERNAME}_RECIPIENTS
#
# Commands:
#   hubot nippo

request = require 'request'

{ HUBOT_ONETEAM_TEAM_NAME: TEAM_NAME, HUBOT_ONETEAM_TEAM_KEY: TEAM_KEY, HUBOT_ONETEAM_RECIPIENTS: DEFAULT_RECIPIENTS } = process.env
REQUEST_URL = "https://api.one-team.io/teams/#{TEAM_NAME}/topics"

execute = (token, requestBody) ->
  request
    url: REQUEST_URL
    method: 'POST'
    headers:
      Authorization: "Bearer #{token}"
      'Content-Type': 'application/json'
      'X-Auth-Team': TEAM_KEY
    body: requestBody
    (err, httpResponse, body) ->
      if err
        if err.errors
          msg.reply "Failed to create nippo, #{err.errors.map((e) -> e.message or '').join '\n'}"
        else
          msg.reply 'Failed to create nippo'
      else
        { number } = body
        msg.reply "Created NIPPO on Oneteam refer to https://#{TEAM_NAME}.one-team.io/topics/#{number}"

requestBodyTemplate = (data, name) ->
  { visibility, recipients, title, body } = data
  title: "Daily report: #{name} #{(d = new Date() && [d.getFullYear(), d.getMonth(), d.getDate].join('-'))}" or title
  recipients: DEFAULT_RECIPIENTS or recipients
  visibility: 'recipients' or visibility
  body: body

contentTemplate = ->
  """
  ## What I've done today

  ## TODOs

  ## Problems

  ## Comments
  """

module.exports = (robot) ->
  robot.respond /\s*nippo\s+([^\s]+)/, (msg) ->
    { envelope, match } = msg
    [_, draft] = match
    return unless username = envelope.user.name
    token = process.env["HUBOT_ONETEAM_#{username.toUpperCase().replace(/([^0-9A-Z])/g, '_')}_TOKEN"]
    data =
      body: contentTemplate()
      visibility: 'private'
    requestBody = requestBodyTemplate data, username
    execute token, requestBody
