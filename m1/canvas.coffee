#!/usr/bin/env coffee

require('zappajs') ->

  # Client-side
  @client '/index.js': ->

    @on connection: ->
      log "Connected as #{@id}"

    @on disconnect: ->
      log "Disconnected"

    @on log: ->
      log @data.text

    @on 'request nickname': ->
      @emit 'set nickname': {nickname: prompt 'Pick a nickname!'}

    @on roster: ->
      $('#roster').html '<ul>'+
        ("<li>#{nickname}</li>" for id, nickname of @data.roster).join('') +
        '</ul>'

    @on 'run commands': ->
      render command for command in @data.commands

    # Connect to socket.io
    @connect()

    $ =>
      # Map the whiteboard to the canvas element
      $('#canvas').draw (from,to) =>
        color = '1010ff'
        @emit 'canvas line': {from:from,to:to,color:color}
        render do:'line',from:from,to:to,color:color

      # Bind actions to the buttons
      $('#undo').click =>
        @emit 'canvas undo': {}
        false

      $('#redo').click =>
        @emit 'canvas redo': {}
        false

      $('#clear').click =>
        @emit 'canvas clear': {}
        false

    # Whiteboard interaction: the callback is called
    # with (last_point, new_point) every time a segment
    # is drawn using the mouse.
    $.fn.draw = (cb) ->
      precision = 1.7
      paint = false
      last_point = null

      start_point = (e) ->
        point =
          x: e.pageX - @offsetLeft
          y: e.pageY - @offsetTop

        paint = true
        cb point, point
        last_point = point

      move_point = (e) ->
        if paint
          point =
            x: e.pageX - @offsetLeft
            y: e.pageY - @offsetTop
          dx = point.x - last_point.x
          dy = point.y - last_point.y
          distance = dx*dx + dy*dy
          if distance <= precision
            return
          cb last_point, point
          last_point = point

      end_point = (e) ->
        paint = false

      @mousedown start_point
      @mousemove move_point
      @mouseup end_point
      @mouseleave end_point

    # Render one command on the whiteboard
    render = (command) ->

      if not render.canvas_ctx

        # Try to get the Whiteboard
        $('#canvas').each ->
          if @getContext
            render.canvas_ctx = @getContext '2d'
            if render.canvas_ctx
              log 'Canvas is ready'
            render.canvas_width = @width
            render.canvas_height = @height
          else
            log 'Canvas is not supported'

        return

      switch command.do
        when 'wipe'
          render.canvas_ctx.clearRect(0,0,render.canvas_width,render.canvas_height)

        when 'line'
          render.canvas_ctx.strokeStyle = '#' + command.color
          render.canvas_ctx.lineJoin = 'round'
          render.canvas_ctx.lineWidth = 5

          render.canvas_ctx.beginPath()
          render.canvas_ctx.moveTo command.from.x, command.from.y
          render.canvas_ctx.lineTo command.to.x,   command.to.y
          render.canvas_ctx.stroke()

    log = (text) ->
      console.log text
      $('#log').prepend "<p>#{text}</p>"


  # Canvas server: undo/redo management
  history = [{do:'wipe'}]
  redo = []
  roster = {}

  @on 'canvas clear': ->
    redo = history
    history = [{do:'wipe'}]
    @broadcast 'run commands': {commands:history}
    @emit      'run commands': {commands:history}
    @broadcast log: {text:"Cleared by #{@client.nickname}!"}
    @emit      log: {text:"Cleared by #{@client.nickname}!"}

  @on 'canvas line': ->
    command =
      do:'line'
      from:@data.from
      to:@data.to
      color:@data.color
      author:@client.nickname
    history.push command
    @broadcast 'run commands': {commands:[command]}

  @on 'canvas undo': ->
    if history.length <= 1
      @emit log: {text: "Nothing to undo"}
      return
    redo.push history.pop()
    @broadcast 'run commands': {commands:history}
    @emit      'run commands': {commands:history}

  @on 'canvas redo': ->
    if redo.length < 1
      @emit log: {text: "Nothing to redo"}
      return
    command = redo.pop()
    history.push command
    @broadcast 'run commands': {commands:[command]}
    @emit      'run commands': {commands:[command]}

  # Canvas server: connection/nickname management
  @on connection: ->
    console.log "Client #{@id} connected"
    if not @client.nickname?
      @emit 'request nickname': {}
    # Update the newly-connected client with history
    @emit 'run commands': {commands:history}

  @on 'set nickname': ->
    @client.nickname = @data.nickname
    roster[@id] = @data.nickname
    console.log "#{@client.nickname} connected"
    @broadcast roster: {roster:roster}
    @emit      roster: {roster:roster}

  @on disconnect: ->
    console.log "Client #{@id} disconnected"
    @broadcast log: {text:"#{@client.nickname} disconnected."}
    delete @client.nickname
    delete roster[@id]
    @broadcast roster: {roster:roster}

  # HTML and CSS
  @stylus '/index.css': '''
    canvas
      border: 1px solid black
    a, span#undo, span#redo
      margin: 2px
    .author
      font-style: italic
    .message
      font-weight: bold
    #roster
      float: right
      background-color: #f2ffe7
    #log p
      color: grey
    #log p:first-child
      color: black
  '''

  @view index: ->
    @title = 'Whiteboard!'
    @scripts = ['/socket.io/socket.io', '/zappa/jquery',
      '/zappa/zappa', '/index']
    @stylesheets = ['/index']

    h1 @title
    div class:'board', ->
      canvas width:1000, height:300, id:'canvas'

    button id:'clear', 'Clear'
    button id:'undo', 'Undo'
    button id:'redo', 'Redo'

    div id:'roster'
    div id:'log'

  # Get things rolling!
  @use 'zappa'
  @enable 'default layout'

  @get '/': ->
    @render 'index'
