#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Kill the client connecting during message transmission'

  server_disconnected = false
  log 'Start websocket server'
  server = start_websocket_server
  server.on(:client_disconnect) do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  server.on(:text) do |_client, body|
    log "Server received text from client: #{body.string.inspect}"
  end

  test_cases = [
    # all frames in these tests start with \x81 - text frames with FIN set
    # They all also have the mask bit set

    # and use body length of 3 for these messages
    {header: "\x81\x83UUUU", description: 'Close after mask'},
    {header: "\x81\x83UUUU=", description: 'Close after first body byte'},
    {header: "\x81\x83UUUU=<", description: 'Close before last body byte'},
    {header: "\x81\x83UUUU=<t", description: 'Close immediately after last body byte'},
  ]

  test_cases.each do |tc|
    log
    log tc[:description]

    server_disconnected = false
    client = connect_client
    client.serve!

    header = tc[:header]
    client.socket.send(header.force_encoding('BINARY'), 0)
    client.socket.close

    # Wait for activity on both the client and the server to complete
    Timeout::timeout(1) do
      loop do
        break if server_disconnected
        sleep 0.1
      end
    end
  end
end
