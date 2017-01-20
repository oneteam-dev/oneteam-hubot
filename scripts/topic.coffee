module.exports = (robot) ->

  console.info robot.listeners

  robot.respond /create\s+topic\s+(.*)/im, (res) ->
    {message} = res
    body = message.text.replace(new RegExp("^#{robot.name}\\s+create\\s+topic\\s+", 'im'), '')
    title = body.split('\n')[0]
    {user_name} = message.user
    recipients = [{user_name}]
    robot.createTopic {title, body, recipients}, (err, req, topic) ->
      url = "https://#{topic.team.team_name}.#{process.env.ONETEAM_BASE_URL || 'one-team.io'}/topics/#{topic.number}"
      res.reply html: "Created topic #{url}\n<web-card url=\"#{url}\"></web-card>"

  robot.respond /update\s+topic\s+(.*)/im, (res) ->
    body = res.message.text.replace(new RegExp("^#{robot.name}\\s+update\\s+topic\\s+", 'im'), '')
    res.topic body

  robot.respond /update\s+page\s*views/im, (res) ->
    res.topic '![](https://comuque.s3.amazonaws.com/chart.png)'
