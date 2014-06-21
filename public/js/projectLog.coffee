sidebarElement = document.getElementsByTagName('aside')[0]

logElement = sidebarElement.querySelector('.Log')

xhr = new XMLHttpRequest
xhr.open 'GET', "/p/#{app.project.id}/log.json"
xhr.responseType = 'json'

xhr.onload = (e) ->
  if @status == 200
    for logEntry in @response
      statusClass = if logEntry.success then 'Successful' else 'Failed'
      statusEmoji = if logEntry.success then '1f44d' else '26a0'
      logElement.insertAdjacentHTML 'beforeend', """<li class="#{statusClass}">#{logEntry.tweetHTML}<div class="Response"><img src="/images/emoji/#{statusEmoji}.png" alt="#{statusClass}:" class="Emoji"> #{logEntry.response}</div></li>"""
    twttr.widgets.load()

  return

xhr.send()