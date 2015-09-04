# Description:
#   ask authors to check deploy
#
# Configuration:
#   HUBOT_GITHUB_ORG
#
# Commands:
#   hubot ask checking <repo> on {staging,production} - Please check operation of <env> env.

module.exports = (robot) ->
  robot.router.post '/webhooks/dockerhub', (req, res) ->
    {push_data} = {repository} = req.body
    {pusher} = push_data
    {repo_name} = repository
    robot.send { room: 'dev_infra' }, "New image for `#{repo_name}` was pushed by #{pusher}"
