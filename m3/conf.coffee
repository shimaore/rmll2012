#!/usr/bin/env coffee

esl = require 'esl'
pico = require 'pico'

db = pico 'http://admin:admin@127.0.0.1:5984/freeswitch'

server = esl.createCallServer()

server.on 'CONNECT', (call) ->

  id = call.body['Channel-Call-UUID']

  # Insert call information in CouchDB.
  call.body._id = id
  db.update call.body, (err) ->

    # Hangup the call if CouchDB insertion failed.
    if err
      call.exit()

    else # Send to the conference
      call.command 'conference', 'nodejs@default'

  # The other way around: beep on changes.
  db.monitor (doc) ->
    call.command 'gentones', '%(250,400,1200)'

server.listen 7000
