#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Initiate a close from the client to the server'

  server_connected = server_disconnected = false

  log 'Start websocket server'
  server = start_websocket_server

  log 'Set a handler for receiving server connect and disconnect events'
  server.on_client_connect do |_client|
    log 'Server has connected to a client'
    server_connected = true
  end

  server.on_client_disconnect do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  log 'Initiate a connection with an invalid request verb'
  request = [
    'GET / HTTP/1.1',
    # missing:
    #"Host: #{@host}:#{@port}",
    'Connection: Upgrade',
    'Upgrade: websocket',
    'Sec-WebSocket-Version: 13',
    'Sec-WebSocket-Key: abcdefghijklmnopqrstuv==',
    'User-Agent: test-client',
    '',
    '',
  ].join("\r\n")
  log
  log 'Client request:'
  log '+' * 80
  log request
  log '+' * 80

  connection = TCPSocket.new(@host, @port.to_i)
  connection.write(request)
  response = ''
  while(content = connection.recv(1024)) do
    break if content.empty?
    response += content
  end

  Timeout::timeout(0.5) do
    loop do
      break if server_connected
      sleep 0.1
    end
  end rescue nil
  log "Server connected: #{server_connected}"

  log 'Close the socket'
  connection.close

  log
  log 'Server response:'
  log '+' * 80
  log response
  log '+' * 80

  log 'Stop websocket server'
  server.stop!
end
