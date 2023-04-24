#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Initiate a close from the client to the server'

  client_received = server_disconnected = false


  log 'Start websocket server'
  server = start_websocket_server

  log 'Set a handler for receiving close events from the server'
  server.on(:close) do |_c, payload|
    log "Received close with #{payload.string.inspect} as server"
  end

  server.on(:client_disconnect) do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  log 'Connect a client'
  client = connect_client
  client.serve!

  log 'Set a handler for receiving close events from the client'
  client.on(:close) do |_c, payload|
    client_received = "Received close with #{payload.string.inspect} as client"
  end

  log 'Send a close from the client to the server'
  client.send_frame(:close)

  # Wait for activity on both the client and the server to complete
  Timeout::timeout(1) do
    loop do
      break if client_received || server_disconnected
      sleep 0.1
    end
  end

  server.stop!
  log client_received

  log 'Stop websocket server'
  server.stop!
end
