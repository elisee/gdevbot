sidebarElement = document.getElementsByTagName('aside')[0]

logElement = sidebarElement.querySelector('.Log')

formatLogEntry = (entry) ->
  statusClass = if entry.success then 'Successful' else 'Failed'
  statusEmoji = if entry.success then '1f44d' else '26a0'
  """<li class="#{statusClass}">#{entry.tweetHTML}<div class="Response"><img src="/images/emoji/#{statusEmoji}.png" alt="#{statusClass}:" class="Emoji"> #{entry.response}</div></li>"""

socket = io()

socket.on 'projectLog', (log) ->
  logElement.insertAdjacentHTML 'beforeend', formatLogEntry entry for entry in log
  twttr.widgets.load()

socket.on 'projectLogEntry', (entry) ->
  logElement.insertAdjacentHTML 'afterbegin', formatLogEntry entry
  twttr.widgets.load()

socket.emit 'subscribeProjectLog', app.project.id