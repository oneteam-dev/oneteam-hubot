# Description:
#   comuque e2e test
#
# Configuration
#   HUBOT_CIRCLE_CI_TOKEN
#
# Commands:
#   hubot comuque test <env>

request = require 'request'


CIRCLE_TOKEN = process.env.HUBOT_CIRCLE_CI_TOKEN

url = (branch) ->
 "https://circleci.com/api/v1/project/oneteam-dev/comuque-e2e-test/tree/#{branch}?circle-token=#{CIRCLE_TOKEN}"

triggerBuild = (branch, msg) ->
  request.post { url: url(branch) }, (err, httpResponse, body) ->
    if err
      msg.reply 'Failed to trigger build'
    else
      msg.reply "Triggered E2E test on #{branch}"

module.exports = (robot) ->
  robot.respond /\s*comuque\stest\s([^\s]+)/, (msg) ->
    [__, env] = msg.match

    switch env
      when 'production'
        triggerBuild('deployment/production', msg)
      when 'staging'
        triggerBuild('master', msg)
      else
        msg.reply "I don't know such an environment: `#{env}`."
        return
