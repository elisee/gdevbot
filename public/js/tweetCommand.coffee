for tweet in document.querySelectorAll('.Tweet')
  console.log tweet
  tweet.addEventListener 'click', (event) ->
    for mark in event.currentTarget.parentElement.querySelectorAll('mark')
      if mark.textContent == ''
        mark.focus()
        event.preventDefault()
        event.stopPropagation()
        return

    commandTweet = event.currentTarget.parentElement.querySelector('.Command').textContent
    event.currentTarget.href = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(commandTweet)
