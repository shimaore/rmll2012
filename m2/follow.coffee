#!/usr/bin/env coffee

pico = require 'pico'

db = pico 'http://127.0.0.1:5984/foo'

db.monitor (doc) ->
  console.dir doc
