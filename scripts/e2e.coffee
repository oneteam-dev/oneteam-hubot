# Description:
#   Start E2E tests
#
# Configuration
#   HUBOT_CIRCLECI_TOKEN
#
# Commands:
#   hubot e2e <env>

request = require 'request'


CIRCLE_TOKEN = process.env.HUBOT_CIRCLECI_TOKEN

url = (branch) ->
 "https://circleci.com/api/v1/project/oneteam-dev/comuque-e2e-test/tree/#{branch}?circle-token=#{CIRCLE_TOKEN}"

triggerBuild = (env, branch, msg) ->
  { room, user } = msg.envelope || {}
  userId = user?.id
  build_parameters = {
    SLACK_ROOM_ID: room
    SLACK_USER_ID: userId
  }
  request.post { url: url(branch), json: { build_parameters } }, (err, httpResponse, body) ->
    {message, build_url} = body
    if message
      msg.reply message
    else if err
      msg.reply 'Failed to trigger build'
    else
      msg.reply "Triggered E2E test on #{env} #{build_url}"

module.exports = (robot) ->
  robot.respond /\s*e2e\s+([^\s]+)/, (msg) ->
    [__, env] = msg.match

    switch env
      when 'production'
        triggerBuild(env, 'production', msg)
      when 'staging'
        triggerBuild(env, 'staging', msg)
      else
        msg.reply "I don't know such an environment: `#{env}`."
        return
