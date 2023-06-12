#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Kill the client connecting during client frame header transmission'

  server_disconnected = false
  log 'Start websocket server'
  server = start_websocket_server
  server.on_client_disconnect do |_client|
    log 'Server has disconnected from a client'
    server_disconnected = true
  end

  test_cases = [
    # all frames in these tests start with \x81 - text frames with FIN set
    # they all also have the mask bit set
    {header: "\x81", description: 'Close after opcode'},
    {header: "\x81\xfe", description: 'Close between short and long length fields'},
    {header: "\x81\xfe\xff", description: 'Close during long length'},
    {header: "\x81\xfe\xff\xff", description: 'Close between long length and mask'},
    {header: "\x81\x81", description: 'Close between short length and mask fields'},
    {header: "\x81\x81U", description: 'Close during mask'},
    {header: "\x81\x81UUUU", description: 'Close after mask'},
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
