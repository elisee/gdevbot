config = require './config'

botlog = (message) -> console.log ( new Date() ).toISOString() + " - #{message}"
debuglog = (message) -> console.log 'DEBUG! ' + ( new Date() ).toISOString() + " - #{message}"

twitterAPI = require 'node-twitter-api'
twitter = new twitterAPI config.twitter

baseURL = "http://#{config.domain}"
baseURL += ":#{config.publicPort}" if config.publicPort != 80


parseCommand = (text, projectId, callback) ->
  # TODO: Parse the text into a command description
  command = {}

  callback null, command


logTweetFail = (err) ->
  return if ! err?
  botlog "Could not tweet:\n#{JSON.stringify(err, null, 2)}"

replyCommandTweet = (status, replyTweetId, callback) ->
  twitter.statuses 'update', { status: status, in_reply_to_status_id: replyTweetId }, config.twitter.accessToken, config.twitter.accessTokenSecret, (err) ->
    err.tweet = { status, replyTweetId } if err?
    callback err

dataCallback = (err, data, chunk, response) ->
  return botlog JSON.stringify err, null, 2 if err?

  debuglog JSON.stringify data, null, 2

  # Ignore non-tweets
  return if ! data.text? or ! data.user?
  # Ignore tweets without a screen name (can that ever happen?) and tweets from the bot itself
  return if ! data.user.screen_name? or data.user.id_str == config.twitter.userId
  # Ignore tweets not mentioning the bot
  return if data.text.indexOf("@#{config.twitter.username}") == -1
  # Ignore retweets or tweets mentioning multiple users
  return if data.retweeted_status? or data.entities?.user_mentions?.length != 1
  # Ignore tweets not containing a single project hashtag
  return if data.entities?.hashtags?.length != 1

  # Ensure the tweet isn't trying to mess with us
  return if data.text.split('@').length - 1 > 1 or data.text.split('#').length - 1 > 1

  botlog "#{data.user.screen_name}: #{data.text}"

  commandText = data.text

  # Remove the bot mention
  botMention = data.entities.user_mentions[0]
  botMentionIndex = commandText.indexOf '@'
  commandText = commandText.slice(0, botMentionIndex) + commandText.slice(botMentionIndex + 1 + botMention.screen_name.length)

  # Remove the project name
  projectId = data.entities.hashtags[0].text
  projectHashtagIndex = commandText.indexOf '#'
  commandText = commandText.slice(0, projectHashtagIndex) + commandText.slice(projectHashtagIndex + 1 + projectId.length)

  commandText = commandText.trim().replace(/\s{2,}/g, ' ')
  botlog "[#{projectId}] #{data.user.screen_name}: #{commandText}"

  replyTweetId = data.id_str

  parseCommand commandText, projectId, (err, command) ->
    if err?
      status = "@#{data.user.screen_name} ERR #{err.message}"
      replyCommandTweet status, replyTweetId, logTweetFail
      return

    # TODO: Apply command

    if ! command.silent
      status = "@#{data.user.screen_name} OK #{baseURL}/p/#{projectId}"
      replyCommandTweet status, replyTweetId, logTweetFail

    return

endCallback = -> botlog "Stream ended, somehow."

twitter.getStream 'userstream', {}, config.twitter.accessToken, config.twitter.accessTokenSecret, dataCallback, endCallback
botlog "Started."
