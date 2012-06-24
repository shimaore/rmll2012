#!/usr/bin/env coffee

esl = require 'esl'
pico = require 'pico'
uuid = require 'node-uuid'

db = pico 'http://127.0.0.1:5984/freeswitch'

server = esl.createCallServer()

server.on 'CONNECT', (call) ->

  # Insert call information in CouchDB.
  call._id = uuid()
  db.update call.body, (err) ->
    # Hangup the call if CouchDB insertion failed.
    if err
      call.exit()
    # Send to the conference
    call.command 'answer', (call) ->
      call.command 'conference', 'nodejs'

  call.on 'CHANNEL_HANGUP_COMPLETE', (call) ->
    db.retrieve call._id, (doc) ->
      db.remove doc

  # The other way around: beep on changes.
  db.monitor (doc) ->
    console.dir doc
    call.command 'gentones', '%(500,0,800)'

server.listen 7000
