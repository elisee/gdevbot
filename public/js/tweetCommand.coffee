for tweet in document.querySelectorAll('.Tweet')
  commandTweet = tweet.parentElement.querySelector('.Command').innerHTML
  commandTweet = commandTweet.replace ///<mark>///g, ''
  commandTweet = commandTweet.replace ///</mark>///g, ''
  tweet.href = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(commandTweet)
