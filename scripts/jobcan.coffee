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

TOP_URL = 'https://ssl.jobcan.jp/employee'
LOGIN_URL = 'https://ssl.jobcan.jp/login/pc-employee/old'
ADIT_URL = 'https://ssl.jobcan.jp/employee/index/adit'
CLIENT_ID = process.env.HUBOT_JOBCAN_CLIENT_ID

STATUS_MSG =
  working: '勤務中'
  resting: '退室中'

adit = (login, password, groupId, expected, callback) ->
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
    if httpResponse?.headers?.location?.indexOf('/login/pc-employee/old') >= 0
      callback 'Failed to login', no
      return
    console.info 'Login succeeded'
    request {
      url: TOP_URL
      jar: jar
    }, (err, res, body) ->
      currentStatus = body.match(/var current_status = "(working|resting)";/)?[1]
      token = body.match(/<input type="hidden" class="token" name="token" value="([^"]+)"/)?[1]
      if currentStatus is expected
        msg = STATUS_MSG[currentStatus]
        callback "既に#{msg}に設定されています", no
        return
      request.post { url: ADIT_URL, jar: jar, formData: {
          is_yakin: '0'
          adit_item: 'DEF'
          notice: ''
          token: token
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
        msg = STATUS_MSG[current_status]
        unless msg
          return callback 'Failed to update status', no
        callback "#{msg}に変更しました", yes

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

    adit login, password, groupId, null, (msg, success) ->
      res.reply msg

  [
    '/hooks/jobcan/:username/:expected'
    '/hooks/jobcan/:username'
  ].forEach (route) ->
    robot.router.post route, (req, res) ->
      {username, expected} = req.params
      envName = "HUBOT_JOBCAN_#{username.toUpperCase().replace(/([^0-9A-Z])/g, '_')}"
      password = process.env["#{envName}_PASSWORD"]
      room = process.env["#{envName}_ROOM"] || 'C0671U5V0'
      login = process.env["#{envName}_LOGIN"]
      groupId = process.env["#{envName}_GROUP_ID"]
      unless password and login and groupId
        res.status 400
        res.send 'Bad Request'
        return
      adit login, password, groupId, expected, (msg, success) ->
        res.send msg
        if success
          robot.send { room }, "<@#{username}> #{msg}"
