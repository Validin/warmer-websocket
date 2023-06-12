#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Initiate a close from the client to the server'

  server_connected = server_disconnected = false

  log 'Start websocket server'
  server = start_websocket_server

  log 'Set a handler for receiving server connect and disconnect events'
  server.on_client_connect do |client|
    log 'Server has connected to a client'
    log "Client path: #{client.path}"
    log "Client host: #{client.host}"
    log "Client origin: #{client.origin}"
    server_connected = true
  end

  server.on_client_disconnect do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  log 'Initiate a connection with an invalid request verb'
  request = [
    'GET / HTTP/1.1',
    "Host: #{@host}:#{@port}",
    'Connection: Upgrade',
    'Upgrade: websocket',
    'Sec-WebSocket-Version: 13',
    'Sec-WebSocket-Key: abcdefghijklmnopqrstuv==',
    # tracked, but not used:
    'Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits',
    # optional
    'Origin: localhost',
    'User-Agent: test-client',
    '',
    '',
  ].join("\r\n")
  log 'Client request:'
  log '+' * 80
  log request
  log '+' * 80

  connection = TCPSocket.new(@host, @port.to_i)
  connection.write(request)
  content = connection.recv(1024)

  Timeout::timeout(1) do
    loop do
      break if server_connected
      sleep 0.1
    end
  end

  log 'Close the socket'
  connection.close

  # Wait for activity on both the client and the server to complete
  Timeout::timeout(1) do
    loop do
      break if server_disconnected
      sleep 0.1
    end
  end

  log 'Server response:'
  log '+' * 80
  log content
  log '+' * 80

  log 'Stop websocket server'
  server.stop!
end
