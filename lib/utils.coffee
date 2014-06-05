module.exports =

  botlog: (message) -> console.log ( new Date() ).toISOString() + " - #{message}"
  debuglog: (message) -> console.log 'DEBUG! ' + ( new Date() ).toISOString() + " - #{message}"
