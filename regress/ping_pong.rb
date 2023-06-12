#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Send a ping from the client to the server'

  client_received = server_received = false

  log 'Start websocket server'
  server = start_websocket_server

  log 'Connect a client'
  client = connect_client
  client.serve!

  log 'Set a handler for receiving pongs on the client'
  client.on_pong do |_c, payload|
    log "Received pong with #{payload.string} as client"
    client_received = true
  end

  log 'Send a ping from the client to the server'
  client.send_frame(:ping, 'Hello?')

  # Wait for activity on the client to complete
  Timeout::timeout(1) do
    loop do
      break if client_received
      sleep 0.1
    end
  end

  scenario 'Send a ping from the server to the client'

  log 'Set a handler for receiving pongs on the server'
  server.on_pong do |_c, payload|
    log "Received pong with #{payload.string} as server"
    server_received = true
  end

  server.connected_clients.each do |server_client|
    server_client.send_frame(:ping, 'ServerHello?')
  end

  # Wait for activity on the server to complete
  Timeout::timeout(1) do
    loop do
      break if server_received
      sleep 0.1
    end
  end

  log 'Stop the client'
  client.stop!
end
