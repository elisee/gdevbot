sidebarElement = document.getElementsByTagName('aside')[0]
iframeElement = document.getElementsByTagName('iframe')[0]

logElement = sidebarElement.querySelector('.Log')

formatLogEntry = (entry) ->
  statusClass = if entry.success then 'Successful' else 'Failed'
  statusEmoji = if entry.success then '1f44d' else '26a0'
  """<li class="#{statusClass}">#{entry.tweetHTML}<div class="Response"><img src="/images/emoji/#{statusEmoji}.png" alt="#{statusClass}:" class="Emoji"> #{entry.response}</div></li>"""

reloadGame = -> iframeElement.contentWindow.location.reload true

socket = io()

projectLogLength = null

socket.on 'projectLog', (log) ->
  html = ""
  html += formatLogEntry entry for entry in log
  logElement.innerHTML = html
  twttr.widgets.load()

  # Reload the game if the log length changed since last disconnection
  reloadGame() if projectLogLength? and projectLogLength != log.length
  projectLogLength = log.length
  return

socket.on 'projectLogEntry', (entry) ->
  logElement.insertAdjacentHTML 'afterbegin', formatLogEntry entry
  twttr.widgets.load()
  projectLogLength++
  reloadGame()

subscribeToProjectLog = ->
  socket.emit 'subscribeProjectLog', app.projectId

socket.on 'connect', subscribeToProjectLog