# Description:
#   jobcan
#
# Configuration:
#   HUBOT_JOBCAN_${USERNAME}_GROUP_ID
#   HUBOT_JOBCAN_${USERNAME}_LOGIN
#   HUBOT_JOBCAN_${USERNAME}_PASSWORD
#   HUBOT_JOBCAN_CLIENT_ID
#
# Commands:
#   hubot jobcan - update your timestamp on jobcan

request = require 'request'

LOGIN_URL = 'https://ssl.jobcan.jp/login/pc-employee/try'
ADIT_URL = 'https://ssl.jobcan.jp/employee/index/adit'
CLIENT_ID = process.env.HUBOT_JOBCAN_CLIENT_ID

adit = (login, password, groupId, callback) ->
  jar = do request.jar
  request.post { url: LOGIN_URL, jar: jar, formData: {
      client_id: CLIENT_ID
      email: login
      password: password
      save_login_info: 1
      url: '/employee'
      login_type: 1
    }
  }, (err, httpResponse, body) ->
    if httpResponse?.headers?.location is '/login/pc-employee/?back=1&err=1'
      callback 'Failed to login', no
      return
    console.info 'Login succeeded'
    request.post { url: ADIT_URL, jar: jar, formData: {
        is_yakin: '0'
        adit_item: 'DEF'
        notice: ''
        adit_group_id: groupId
      }
    }, (err, httpResponse, body) ->
      unless (json = try JSON.parse body)
        return callback 'Invalid response', no
      if json?.errors?.aditCount is 'duplicate'
        return callback '1分以内に打刻しています', no
      {result, current_status} = json
      unless result is 1
        return callback "Failed to update status #{ JSON.stringify(json.errors || 'Unknown error') }", no
       msg = {
        working: '勤務中に変更しました'
        resting: '退室中に変更しました'
      }[current_status]
      unless msg
        return callback 'Failed to update status', no
      callback msg, yes

module.exports = (robot) ->
  robot.respond /\s*(jobcan|打刻)(?:\s+([^\s]+))?/, (res) ->
    {envelope, match} = res
    return unless (username = match[2] || envelope.user.name)
    envName = "HUBOT_JOBCAN_#{username.toUpperCase().replace(/([^0-9A-Z])/g, '_')}"
    password = process.env["#{envName}_PASSWORD"]
    login = process.env["#{envName}_LOGIN"]
    groupId = process.env["#{envName}_GROUP_ID"]
    return res.reply """
    You need to configure your login, password, group id for Hubot.
    try:
    ```
    heroku config:set --app oneteam-hubot \\
      #{envName}_LOGIN=${YOUR_LOGIN} \\
      #{envName}_PASSWORD=${YOUR_PASSWORD} \\
      #{envName}_GROUP_ID=${YOUR_GROUP_ID}
    ```

    If you're not an engineer, please ask <@ngs>.
    """ unless password and login and groupId

    adit login, password, groupId, (msg, success) ->
      res.reply msg

  robot.router.post '/hooks/jobcan/:username', (req, res) ->
    {username} = req.params
    envName = "HUBOT_JOBCAN_#{username.toUpperCase().replace(/([^0-9A-Z])/g, '_')}"
    password = process.env["#{envName}_PASSWORD"]
    login = process.env["#{envName}_LOGIN"]
    groupId = process.env["#{envName}_GROUP_ID"]
    unless password and login and groupId
      res.status 400
      res.send 'Bad Request'
      return
    adit login, password, groupId, (msg, success) ->
      res.send msg
      robot.send { room: 'ngs-playground-privat' }, "#{username} #{msg}"
