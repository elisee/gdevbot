config = require './config'

botlog = (message) -> console.log ( new Date() ).toISOString() + " - #{message}"
debuglog = (message) -> console.log 'DEBUG! ' + ( new Date() ).toISOString() + " - #{message}"

twitterAPI = require 'node-twitter-api'
twitter = new twitterAPI config.twitter


dataCallback = (err, data, chunk, response) ->
  return botlog JSON.stringify err, null, 2 if err?

  debuglog JSON.stringify data, null, 2

  # Ignore non-tweets
  return if ! data.text? or ! data.user?
  # Ignore tweets without a screen name (can that ever happen?) and tweets from the bot itself
  return if ! data.user.screen_name? or data.user.id == config.twitter.userId
  # Ignore tweets not mentioning the bot
  return if data.text.indexOf("@#{config.twitter.username}") == -1
  # Ignore retweets or tweets mentioning multiple users
  return if data.retweeted_status? or data.entities?.user_mentions?.length != 1
  # Ignore tweets not containing a single project hashtag
  return if data.entities?.hashtags?.length != 1

  # Ensure the tweet isn't trying to mess with us
  return if data.text.split('@').length - 1 > 1 or data.text.split('#').length - 1 > 1

  botlog "#{data.user.screen_name}: #{data.text}"

  command = data.text

  # Remove the bot mention
  botMention = data.entities.user_mentions[0]
  botMentionIndex = command.indexOf '@'
  command = command.slice(0, botMentionIndex) + command.slice(botMentionIndex + 1 + botMention.screen_name.length)

  # Remove the project name
  projectId = data.entities.hashtags[0].text
  projectHashtagIndex = command.indexOf '#'
  command = command.slice(0, projectHashtagIndex) + command.slice(projectHashtagIndex + 1 + projectId.length)

  command = command.trim().replace(/\s{2,}/g, ' ')

  botlog "[#{projectId}] #{data.user.screen_name}: #{command}"

endCallback = -> botlog "Stream ended, somehow."

twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback
botlog "Started."
