#!/usr/bin/env coffee

require('zappajs') 1337, ->

  @get '/': ->
    @send 'Hello World\n'

  @get '/json': ->
    @send [msg:'Hello World\n']
