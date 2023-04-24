#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Initiate a close from the server to the client'

  server_received = false

  log 'Start websocket server'
  server = start_websocket_server

  log 'Set a handler for receiving close events from the server'
  server.on(:close) do |_c, payload|
    log "Received close with #{payload.string.inspect} as server"
    server_received = true
  end

  server.on(:ping) do |client|
    client.send_frame(:close)
  end

  log 'Connect a client'
  client = connect_client

  log 'Set a handler for receiving close events from the client'
  client.on(:close) do |_c, payload|
    log "Received close with #{payload.string.inspect} as client"
  end

  client.serve!

  client.send_frame(:ping)

  # Wait for activity on both the client and the server to complete
  Timeout::timeout(1) do
    loop do
      break if server_received
      sleep 0.1
    end
  end

  log 'Stop websocket server'
  server.stop!
end
