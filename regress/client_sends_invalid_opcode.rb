#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Client sends an unsupported opcode to the server'

  log 'Start websocket server'
  server = start_websocket_server

  unsupported_codes = (0..15).to_a - [0, 1, 2, 8, 9, 10]

  unsupported_codes.each do |code|
    log 'Connect a client'
    client = connect_client
    client.serve!
    log "Sending invalid opcode: #{code}"
    client.send_frame(code, '')
    log 'Waiting for client connection to close'
    still_serving = Timeout::timeout(1) do
      loop do
        break unless client.serving?
        sleep 0.1
      end
      false
    end rescue true

    if still_serving
      log 'Client is still serving!'
      client.stop!
    end

    log '+' * 80
  end
end
