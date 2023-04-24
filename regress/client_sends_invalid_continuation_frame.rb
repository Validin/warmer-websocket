#!/usr/bin/env ruby

require_relative 'harness.rb'

Harness.run_test do
  scenario 'Client sends an invalid continuation frame'

  log 'Start websocket server'
  server = start_websocket_server
  log '+' * 80

  scenarios = [
    { code: 0, payload: '', first: true, last: true,
      description: 'Continuation, no payload, FIN set'},
    { code: 0, payload: '', first: true, last: false,
      description: 'Continuation, no payload, FIN NOT set'},
    { code: 0, payload: 'A' * 125, first: true, last: true,
      description: 'Continuation, with payload, FIN set'},
  ]

  scenarios.each do |tc|
    log 'Connect a client'
    client = connect_client
    client.serve!
    log tc[:description]
    # the server may close this before we finish sending on errors,
    # so we catch broken pipe exceptions here
    client.send_frame(tc[:code], tc[:payload], tc[:first], tc[:last]) rescue nil
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
