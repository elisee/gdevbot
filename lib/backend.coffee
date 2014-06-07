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
      parentsByChildName: {}

  try assetEntries = fs.readdirSync path.join projectsPath, projectEntry, 'assets'

  if assetEntries?
    for assetEntry in assetEntries
      assetName = assetEntry.split('.')[0]
      project.assetNames.push assetName.toLowerCase()

  try actorsJSON = fs.readFileSync path.join(projectsPath, projectEntry, 'actors.json'), encoding: 'utf8'

  if actorsJSON?
    project.actorsTree.roots = JSON.parse actorsJSON

    walkActor = (actor, parent) ->
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parent
      project.actorsTree.byName[actor.name.toLowerCase()] = actor
      walkActor child, actor for child in actor.children
      return

    walkActor actor, null for actor in project.actorsTree.roots

writeActors = (projectId, actors, callback) ->
  fs.writeFile path.join(projectsPath, projectId.toLowerCase(), 'actors.json'), JSON.stringify(actors, null, 2), (err) ->
    if err?
      utils.botlog "[#{projectId}] Error saving actors.json:"
      utils.botlog JSON.stringify err, null, 2
      callback new Error 'Could not write actors file'

    callback null

module.exports = backend =

  nameRegex: /^[A-Za-z0-9_]{1,40}$/

  createProject: (projectId, callback) ->
    return process.nextTick( -> callback new Error "Invalid project name" ) if ! backend.nameRegex.test projectId
    return process.nextTick( -> callback new Error "Project name is already used" ) if projectsById[projectId]?

    fs.mkdir path.join(projectsPath, projectId.toLowerCase()), (err) ->
      if err?
        return callback new Error 'Project name is already used'  if err.code == 'EEXIST'
        utils.botlog "[#{projectId}] Unexpected error creating project folder:"
        utils.botlog JSON.stringify err, null, 2
        return callback new Error 'Unexpected error'

      projectsById[projectId.toLowerCase()] = project =
        assetNames: []
        actorsTree:
          roots: []
          byName: {}

      mkdirp path.join(projectsPath, projectId.toLowerCase(), 'assets'), (err) ->
        if err? and err.code != 'EEXIST'
          utils.botlog "[#{projectId}] Unexpected error creating assets folder:"
          utils.botlog JSON.stringify err, null, 2
          return callback new Error 'Unexpected error' if err? 

        writeActors projectId, project.actorsTree.roots, callback

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
        gm(body).resize(1024,1024,'>').write path.join(projectsPath, projectId.toLowerCase(), 'assets', "#{name}.png"), (err) ->
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
    return process.nextTick( -> callback new Error "Invalid actor name" ) if name == 'root' or ! backend.nameRegex.test name
    return process.nextTick( -> callback new Error "Actor name is already used" ) if project.actorsTree.byName[name.toLowerCase()]?

    actor = { name, children: [], components: [] }

    if parentName? and parentName != 'root'
      return process.nextTick( -> callback new Error "Invalid parent name" ) if ! backend.nameRegex.test parentName

      parentActor = project.actorsTree.byName[parentName.toLowerCase()]
      return process.nextTick( -> callback new Error "No such parent actor" ) if ! parentActor?

      parentActor.children.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parentActor
    else
      project.actorsTree.roots.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = null

    project.actorsTree.byName[actor.name.toLowerCase()] = actor
    writeActors projectId, project.actorsTree.roots, callback

  reparentActor: (projectId, name, parentName, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid actor name" ) if ! backend.nameRegex.test name

    actor = project.actorsTree.byName[name.toLowerCase()]
    return process.nextTick( -> callback new Error "No such actor" ) if ! actor?

    # Remove from old parent
    oldParent = project.actorsTree.parentsByChildName[actor.name.toLowerCase()]
    if oldParent?
      oldParent.children.splice oldParent.children.indexOf(actor), 1
    else
      project.actorsTree.roots.splice project.actorsTree.roots.indexOf(actor), 1

    # Add to new parent
    if parentName? and parentName != 'root'
      return process.nextTick( -> callback new Error "Invalid parent name" ) if ! backend.nameRegex.test parentName

      parentActor = project.actorsTree.byName[parentName.toLowerCase()]
      return process.nextTick( -> callback new Error "No such parent actor" ) if ! parentActor?

      ancestorActor = parentActor
      while ancestorActor?
        ancestorActor = project.actorsTree.parentsByChildName[ancestorActor.name.toLowerCase()]
        return process.nextTick( -> callback new Error "Cannot reparent an actor to one of its descendant" ) if ancestorActor == actor

      parentActor.children.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = parentActor
    else
      project.actorsTree.roots.push actor
      project.actorsTree.parentsByChildName[actor.name.toLowerCase()] = null

    writeActors projectId, project.actorsTree.roots, callback

  addComponent: (projectId, actorName, assetName, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid asset name" ) if ! backend.nameRegex.test assetName
    return process.nextTick( -> callback new Error "Invalid actor name" ) if ! backend.nameRegex.test actorName

    actor = project.actorsTree.byName[actorName.toLowerCase()]
    return process.nextTick( -> callback new Error "No such actor" ) if ! actor?

    for component in actor.components
      if component.name.toLowerCase() == assetName.toLowerCase()
        return process.nextTick( -> callback new Error "Component already exists" )

    actor.components.push name: assetName
    writeActors projectId, project.actorsTree.roots, callback

  removeComponent: (projectId, actorName, assetName, callback) ->
    project = projectsById[projectId.toLowerCase()]
    return process.nextTick( -> callback new Error "No such project" ) if ! project?
    return process.nextTick( -> callback new Error "Invalid asset name" ) if ! backend.nameRegex.test assetName
    return process.nextTick( -> callback new Error "Invalid actor name" ) if ! backend.nameRegex.test actorName

    actor = project.actorsTree.byName[actorName.toLowerCase()]
    return process.nextTick( -> callback new Error "No such actor" ) if ! actor?

    for component, i in actor.components
      if component.name.toLowerCase() == assetName.toLowerCase()
        actor.components.splice i, 1
        return writeActors projectId, project.actorsTree.roots, callback

    return process.nextTick( -> callback new Error "No such asset" )

