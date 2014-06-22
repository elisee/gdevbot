for tweet in document.querySelectorAll('.Tweet')
  commandTweet = tweet.parentElement.querySelector('.Command').innerHTML
  commandTweet = commandTweet.replace ///<mark>///g, '_'
  commandTweet = commandTweet.replace ///</mark>///g, '_'
  tweet.href = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(commandTweet)
