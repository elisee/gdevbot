utils = require './utils'
parseScript = require './parseScript'
mkdirp = require 'mkdirp'
path = require 'path'
request = require 'request'
gm = require 'gm'
fs = require 'fs'

projectsPath = path.join __dirname, '..', 'public', 'projects'

try mkdirp.sync projectsPath

projectsById = {}

for projectEntry in fs.readdirSync path.join projectsPath
  projectsById[projectEntry] = project =
    assetNames: []
    actorsTree:
      roots: []
      byName: {}

  try assetEntries = fs.readdirSync path.join projectsPath, projectEntry, 'assets'

  if assetEntries?
    for assetEntry in assetEntries
      assetName = assetEntry.split('.')[0]
      project.assetNames.push assetName.toLowerCase()

  try actorsJSON = fs.readFileSync path.join(projectsPath, projectEntry, 'actors.json'), encoding: 'utf8'

  if actorsJSON?
    project.actorsTree.roots = JSON.parse actorsJSON

    walkActor = (actor) ->
      project.actorsTree.byName[actor.name.toLowerCase()] = actor
      walkActor child for child in actor.children
      return

    walkActor actor for actor in project.actorsTree.roots

module.exports = backend =

  nameRegex: /^[A-Za-z0-9_]{3,40}$/

  createProject: (projectId, callback) ->
    return process.nextTick( -> callback new Error "Invalid project name" ) if ! backend.nameRegex.test projectId
    return process.nextTick( -> callback new Error "Project name is already used" ) if projectsById[projectId]?

    fs.mkdir path.join(projectsPath, projectId.toLowerCase()), (err) ->
      if err?
        return callback new Error 'Project name is already used'  if err.code == 'EEXIST'
        utils.botlog "[#{projectId}] Unexpected error creating project folder:"
        utils.botlog JSON.stringify err, null, 2
        return callback new Error 'Unexpected error'

      projectsById[projectId] =
        assetNames: []
        actorsTree:
          roots: []
          byName: {}

      callback null

  importAsset: (projectId, name, url, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid asset name" ) if ! backend.nameRegex.test name
    return process.nextTick( -> callback new Error "Asset name is already used" ) if project.assetNames.indexOf(name.toLowerCase()) != -1

    mkdirp path.join(projectsPath, projectId.toLowerCase(), 'assets'), (err) ->
      if err? and err.code != 'EEXIST'
        utils.botlog "[#{projectId}] Unexpected error creating assets folder:"
        utils.botlog JSON.stringify err, null, 2
        return callback new Error 'Unexpected error' if err? 

      # TODO: Abort request if size is too big
      request { url, encoding: null }, (err, response, body) ->
        return callback new Error 'Failed to download asset' if err? or response.statusCode != 200

        # TODO: Implement support for other asset types
        gm(body).resize(1024,1024).write path.join(projectsPath, projectId.toLowerCase(), 'assets', "#{name}.png"), (err) ->
          if err?
            utils.botlog "[#{projectId}] Error processing import of #{url}:"
            utils.botlog JSON.stringify err, null, 2
            return callback new Error 'Failed to import asset'

          callback null

      return

  addScript: (projectId, name, content, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid script name" ) if ! backend.nameRegex.test name
    return process.nextTick( -> callback new Error "Script name is already used" ) if project.assetNames.indexOf(name.toLowerCase()) != -1

    parseScript name, content, (err, script) ->
      if err?
        utils.botlog "[#{projectId}] Error parsing script #{name}:"
        utils.botlog JSON.stringify err, null, 2
        callback new Error 'Failed to parse script'
        return

      assetsPath = path.join(projectsPath, projectId.toLowerCase(), 'assets')
      mkdirp assetsPath, (err) ->
        return callback new Error 'Unexpected error' if err? and err.code != 'EEXIST'

        fs.writeFile path.join(assetsPath, name + ".js"), script, (err) ->
          if err?
            utils.botlog "[#{projectId}] Error writing script #{name}:"
            utils.botlog JSON.stringify err, null, 2
            callback new Error 'Failed to save script'
            return

          callback null

  createActor: (projectId, name, parentName, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid actor name" ) if ! backend.nameRegex.test name
    return process.nextTick( -> callback new Error "Actor name is already used" ) if project.actorsTree.byName[name.toLowerCase()]?

    actor = { name, children: [] }

    if parentName?
      return process.nextTick( -> callback new Error "Invalid parent name" ) if ! backend.nameRegex.test parentName

      parentActor = project.actorsTree.byName[parentName.toLowerCase()]
      return process.nextTick( -> callback new Error "No such parent actor" ) if ! parentActor?

      project.actorsTree.byName[parentName.toLowerCase()].children.push actor
    else
      project.actorsTree.roots.push actor

    project.actorsTree.byName[actor.name.toLowerCase()] = actor

    fs.writeFile path.join(projectsPath, projectId.toLowerCase(), 'actors.json'), JSON.stringify(project.actorsTree.roots, null, 2), (err) ->
      if err?
        utils.botlog "[#{projectId}] Error saving actors.json:"
        utils.botlog JSON.stringify err, null, 2
        callback new Error 'Actor created but file could not be written'

      callback null
