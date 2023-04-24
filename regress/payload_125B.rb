#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Client and server both send text payloads of 125B'

  server_received = client_received = false

  log 'Start websocket server'
  server = start_websocket_server

  log 'Set a handler for receiving text on the server'
  server.on(:text) do |conn, payload|
    log "Received #{payload.string} as server"
    log 'Send text from the server back to the client'
    conn.send_frame(1, 'Hello' * 25)
    server_received = true
  end

  log 'Connect a client'
  client = connect_client
  client.serve!
  log 'Set a handler for receiving text on the client'
  client.on(:text) do |_conn, payload|
    log "Received #{payload.string} as client"
    client_received = true
  end
  log 'Send text from the client to the server'
  client.send_frame(1, 'HiHi?' * 25)

  # Wait for activity on both the client and the server to complete
  Timeout::timeout(1) do
    loop do
      break if server_received && client_received
      sleep 0.1
    end
  end

  log 'Stop the client'
  client.stop!
end
