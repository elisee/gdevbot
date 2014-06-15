# @gdevbot

[@gdevbot](http://gdevbot.sparklinlabs.com/) is a Twitter bot for making games.

I'm making the source public in hopes that it can be useful to others trying to make their own Twitter bots.  
Feel free to look into how it's built.

## Getting started with development

 * Make sure you have the latest [Node.js](http://nodejs.org/) installed.
 * @gdevbot is written in CoffeeScript, Run ``npm install -g coffee-script`` to install it.
 * @gdevbot uses Gulp for building stuff. Run ``npm install -g gulp`` to install it.
 * Run ``npm install`` in the repository's root folder to install or update dependencies.
 * Run ``gulp watch`` in the repository's root folder. When you edit player files in ``public``, they'll automatically be rebuilt.

## Running the bot

 * Copy ``config.coffee.template`` to ``config.coffee`` and fill in the blanks
 * Run ``coffee app.coffee`` to start the bot.
 * If you make changes to ``app.coffee``, you'll need to stop and restart the process. (We might want to setup nodemon later?)