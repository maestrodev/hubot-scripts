# Description:
#   Looks up jira issues when they're mentioned in chat
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_DOMAIN
#   HUBOT_JIRA_USERNAME (optional)
#   HUBOT_JIRA_PASSWORD (optional)
#   HUBOT_JIRA_IGNORECASE (optional; default is "true")
#
# Commands:
# 
# Author:
#   stuartf

module.exports = (robot) ->
  cache = []
  jiraDomain = process.env.HUBOT_JIRA_DOMAIN
  jiraUrl = "https://" + jiraDomain
  http = require 'https'

  jiraUsername = process.env.HUBOT_JIRA_USERNAME
  jiraPassword = process.env.HUBOT_JIRA_PASSWORD
  if jiraUsername != undefined && jiraUsername.length > 0
    auth = "#{jiraUsername}:#{jiraPassword}"

  http.get {host: jiraDomain, auth: auth, path: "/rest/api/2/project"}, (res) ->
    data = ''
    res.on 'data', (chunk) ->
      data += chunk.toString()
    res.on 'end', () ->
      json = JSON.parse(data)
      jiraPrefixes = ( entry.key for entry in json )
      reducedPrefixes = jiraPrefixes.reduce (x,y) -> x + "-|" + y
      jiraPattern = "/\\b(" + reducedPrefixes + "-)(\\d+)\\b/g"
      ic = process.env.HUBOT_JIRA_IGNORECASE
      if ic == undefined || ic == "true"
        jiraPattern += "i"

      robot.hear eval(jiraPattern), (msg) ->
        for i in msg.match
          issue = i.toUpperCase()
          now = new Date().getTime()
          if cache.length > 0
            cache.shift() until cache.length is 0 or cache[0].expires >= now
          if cache.length == 0 or (item for item in cache when item.issue is issue).length == 0
            cache.push({issue: issue, expires: now + 120000})
            msg.http(jiraUrl + "/rest/api/2/issue/" + issue)
              .auth(auth)
              .get() (err, res, body) ->
                try
                  json = JSON.parse(body)
                  key = json.key
                  msg.send "[" + key + "] " + json.fields.summary
                  urlRegex = new RegExp(jiraUrl + "[^\\s]*" + key)
                  if not msg.message.text.match(urlRegex)
                    msg.send jiraUrl + "/browse/" + key
                catch error
                  try
                    msg.send "[*ERROR*] " + json.errorMessages[0]
                  catch reallyError
                    msg.send "[*ERROR*] " + reallyError
