# Description:
#   HTTP endpoint to say something

module.exports = (robot) ->
  robot.router.post "/hubot/say", (req, res) ->
    { channel, message } = req.body
    robot.messageRoom channel, message
    res.end "OK"
