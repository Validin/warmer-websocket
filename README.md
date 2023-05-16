# warmer-websocket

This is a pure Ruby websocket implementation. It supports TLS (`wss://`)
clients and servers and requires no additional dependencies.

# Example Server

Echo messages received back to the client
```ruby
options = { :host => 'localhost', :port => '8088' }
socket_server = WebSocket::Server.new(options)
socket_server.run!
server.on(:text) do |conn, payload|
  conn.send_frame(1, payload.string)
end
```

# Testing

To run tests, run `make test`.
