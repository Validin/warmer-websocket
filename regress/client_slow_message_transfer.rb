#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Kill the client connecting during message transmission'

  server_disconnected = false
  log 'Start websocket server'
  server = start_websocket_server
  server.on_client_disconnect do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  server.on_text do |_client, body|
    log "Server received text from client: #{body.length} B"
  end

  body = '=<tt' * (8192 / 4)
  header = "\x81\xFE#{[body.length].pack('n')}UUUU"
  message = StringIO.new
  message.set_encoding('BINARY')
  message.write(header)
  message.write(body)
  message.rewind

  server_disconnected = false
  client = connect_client
  client.serve!

  # send the message one byte at a time
  message.each_char do |c|
    client.socket.send(c, 0)
  end
  client.socket.close

  # Wait for activity on both the client and the server to complete
  Timeout::timeout(1) do
    loop do
      break if server_disconnected
      sleep 0.1
    end
  end
end
