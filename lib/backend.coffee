utils = require './utils'
fs = require 'fs'
path = require 'path'
request = require 'request'
gm = require 'gm'

try fs.mkdirSync path.join __dirname, '..', 'public'
try fs.mkdirSync path.join __dirname, '..', 'public', 'data'

module.exports = backend =

  nameRegex: /^[A-Za-z0-9_]{3,40}$/

  importAsset: (projectId, name, url, callback) ->
    return callback new Error "Invalid asset name" if ! backend.nameRegex.test name

    fs.mkdir path.join(__dirname, '..', 'public', 'data', projectId), (err) ->
      return callback new Error 'Unexpected error' if err? and err.code != 'EEXIST'

      # TODO: Abort request if size is too big
      request = request { url, encoding: null }, (err, response, body) ->
        return callback new Error 'Failed to download asset' if err? or response.statusCode != 200

        # TODO: Implement support for other asset types
        gm(body).resize(1024,1024).write path.join(__dirname, '..', 'public', 'data', projectId, "#{name}.png"), (err) ->
          if err?
            utils.botlog JSON.stringify err, null, 2
            callback new Error 'Failed to import asset'
            return

          callback null

  createObject: (projectId, name, assetName, callback) ->
    return callback new Error "Invalid object name" if ! backend.nameRegex.test name
    return callback new Error "Invalid asset name" if ! backend.nameRegex.test assetName

    # TODO: Implement creating an object
    callback null
