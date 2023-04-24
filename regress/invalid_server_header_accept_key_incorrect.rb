#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Server responds to a normal request with invalid accept key header'

  server_connected = server_disconnected = false

  log 'Start the server by listening over TCP'
  server = TCPServer.new(@host, @port.to_i)

  log 'Connect a client'
  client = exception = nil
  # this should happen in the background
  connect_thread = Thread.new do
    begin
      client = connect_client
    rescue => e
      exception = e
    end
  end

  log 'Respond to an initiated request'
  connection = server.accept
  request = ''
  while(line = connection.gets)
    request += line
    break if line.strip.empty?
  end

  key = ''
  key = $1 if request =~ /^Sec-WebSocket-Key: (\S+)\r$/i

  log 'Client request:'
  log '+' * 80
  log request.gsub(key, '[WebSocket Request Key]')
  log '+' * 80

  response_to_hash = key
  accept_key = Digest::SHA1.base64digest(response_to_hash)
  response = [
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    "Sec-WebSocket-Accept: #{accept_key}",
    '',
    '',
  ].join("\r\n")

  log
  log 'Server response:'
  log '+' * 80
  log response.gsub(accept_key, '[WebSocket Response Key]')
  log '+' * 80

  connection.write(response)

  joined_thread = connect_thread.join(1)

  if exception
    log 'Client exception raised during request:'
    log "  #{exception.class.to_s}: #{exception.message.inspect}"
  elsif client
    log 'Stop the connected client'
    client.stop!
  elsif joined_thread.nil?
    log 'Client never finished the connection, kill attempt'
    connect_thread.kill
  end

  log 'Close the socket'
  connection.close
end
