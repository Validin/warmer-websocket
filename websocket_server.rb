# MIT License
#
# Copyright (c) 2017 Kenneth Kinion
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This is a stand-alone WebSocket implementation that uses only Ruby sockets.
# The emphasis on this implementation is on understanding what is happening
# in the underlying requests, with a secondary goal of this being as concise
# as possible and being contained within a single source file.
#
# References used to build this server include:
# "Building a simple websockets server from scratch in Ruby"
# http://blog.honeybadger.io/building-a-simple-websockets-server-from-scratch-in-ruby/
#
# "RFC 6455 - The WebSocket Protocol"
# https://tools.ietf.org/html/rfc6455
#
# WebSocket Ruby Gem - "Universal Ruby library to handle WebSocket protocol"
# https://github.com/imanel/websocket-ruby
module WebSocket
  class Server
    require 'socket'
    require 'openssl'
    require 'logger'
    require 'digest'
    require_relative 'websocket_client'

    SERVER_ACTIONS = [
      :client_connect, :client_disconnect,
    ]

    # Configures the WebSocketServer, but does not start the server
    # @params [Hash] opts - options hash supporting:
    #   host: hostname from which to serve WebSockets
    #   port: port from which to serve WebSockets
    #   logger: logger override to use for log messages (defaults to STDOUT)
    def initialize(opts = {})
      @host = opts[:host]
      @port = opts[:port]
      @logger = opts[:logger]
      @ssl = opts[:ssl]
      @ssl_key = opts[:ssl_key]
      @ssl_cert = opts[:ssl_cert]
      @client_handlers = Hash.new{|h, v| h[v] = []}
      @server_handlers = Hash.new{|h, v| h[v] = []}
      @clients = {}
      @client_mutex = Mutex.new
      @server = nil
      @socket = nil
      @ctx = nil
      unless @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
      end
    end

    # Registers a custom action handler for client events
    # Executes the given code when the specified action occurs
    #
    # @param [Symbol] action - the name of the action
    # @param [Proc or lambda] func - a callable object
    # @param [Block] block - code block
    def on(action, func = nil, &block)
      func ||= block
      if SERVER_ACTIONS.include?(action)
        @server_handlers[action] << func
      else
        @client_handlers[action] << func
      end
    end

    # Starts the WebSocket server, spawns a new thread for every request
    def run!
      start_server!
      @server_thread = Thread.new do
        loop do
          # TODO handle OpenSSL::SSL::SSLError on SSL client accept from non-SSL client
          Thread.start(@server.accept) do |socket|
            begin
              handle_request(socket)
            rescue => e
              @logger.error "#{e.class}: #{e.message}"
              @logger.debug e.backtrace
            ensure
              closing_client = @client_mutex.synchronize do
                @clients.delete(socket)
              end
              # invoke callbacks for disconnect if there is a client to
              # disconnect
              emit(:client_disconnect, closing_client) if closing_client
              socket.close
            end
          end
        end
      end
    end

    # Stops the main WebSocket server thread
    def stop!
      return unless running?
      @logger.info 'Stopping WebSocket server'
      @client_mutex.synchronize do
        @clients.each do |socket, client|
          client.stop!
        end
      end
      @server_thread.kill if @server_thread
      @server.close
      @socket.close unless @socket.nil?
    end

    # Returns true only when the server is running
    def running?
      !(@server.nil? || @server.closed?)
    end

    # Returns an array of all connected clients
    #
    # @return [Array] all currently-connected clients
    def connected_clients
      @client_mutex.synchronize do
        @clients.values.dup
      end
    end

    private

    # Invoke any provided custom handlers for the given event type
    #
    # @param [Symbol] type - the event type
    # @param [Array] *args - arguments to provide to the block handler
    def emit(type, *args)
      @server_handlers[type].dup.each { |handler| handler.call(*args) }
    end

    # This handles reading the WebSocket request from a client, validating the
    # request, and then serving content if the request appears to be valid
    # TODO: server should respond to bad requests with "400 Bad Request"
    #
    # @param [TCPSocket] socket - the incoming socket from a WebSocket client
    def handle_request(socket)
      request = ''
      http_request = path = host = origin = nil
      # read the raw HTTP request, line by line, until through the headers
      while (line = socket.gets)
        # the HTTP request (verb, path, version) is the first line
        http_request ||= line
        request += line
        # end of the HTTP request
        break if line.strip.empty?
      end

      # get the requested path from the HTTP request
      if http_request =~ /^GET (\S+) HTTP\/1\.1\s*$/
        path = $1
      else
        respond_400 socket, 'Received unsupported request type'
        return
      end

      # requred headers

      unless request =~ /^Connection: Upgrade\s*$/i
        respond_400 socket, 'Received request without "Connection: Upgrade" header'
        return
      end

      unless request =~ /^Upgrade: websocket\s*$/i
        respond_400 socket, 'Received request without "Upgrade: websocket" header'
        return
      end

      if request =~ /^Host: (\S+)\s*$/i
        host = $1
      else
        respond_400 socket, 'Did not receive valid "Host" header'
        return
      end

      websocket_key = websocket_version = nil
      other_headers = []
      # inspect the WebSocket headers
      request.scan(/^(Sec-WebSocket-[^: ]+: [^\r]*)\r?$/i).flatten.each do |head|
        case head
        when /^Sec-WebSocket-Version: 13$/i
          websocket_version = 13
        when /^Sec-WebSocket-Key: (\S+)$/i
          websocket_key = $1
        else
          other_headers << head
        end
      end

      unless websocket_version
        respond_400 socket, 'Did not receive websocket version header value of 13'
        return
      end

      unless websocket_key
        respond_400 socket, 'Received invalid websocket request (missing key)'
        return
      end

      unless other_headers.empty?
        @logger.info "Additional WebSocket headers: #{other_headers.join('#')}"
      end

      # Optional header
      # See notes about "Origin Considerations" in the RFC:
      # https://tools.ietf.org/html/rfc6455#section-10.2
      origin = $1 if request =~ /^Origin: (\S+)\s*$/i

      @logger.info 'Received websocket key, establishing connection'
      response_to_hash = "#{websocket_key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
      websocket_accept = Digest::SHA1.base64digest(response_to_hash)
      response = <<-HEADER
        HTTP/1.1 101 Switching Protocols
        Upgrade: websocket
        Connection: Upgrade
        Sec-WebSocket-Accept: #{websocket_accept}

      HEADER
      response = response.split("\n", -1).map {|l| l.strip}
      response = response.join("\r\n")
      socket.write response
      client = WebSocket::Client.new(socket,
        path: path, host: host, origin: origin,
        handlers: @client_handlers,
        logger: @logger,
      )
      # start handling frames for the connection
      client_serve_thread = client.serve!
      @client_mutex.synchronize do
        # add to our awareness of connected clients
        @clients[socket] = client
      end
      # emit the corresponding handler
      emit(:client_connect, client)
      # serves until the underlying thread ends
      client_serve_thread.join
    end

    # Sends a valid 400 error to the connecting client
    #
    # @param [TCPSocket] socket - the TCP socket to the client
    # @param [String] message - the error message to send
    def respond_400(socket, message)
      @logger.warn message
      message = message.force_encoding('BINARY')
      response = <<-HEADER
        HTTP/1.1 400 Bad Request
        Content-Type: text/html
        Content-Length: #{message.length}
        Connection: close

      HEADER
      response = response.split("\n", -1).map {|l| l.strip}
      response = response.join("\r\n")
      socket.write response
      socket.write message
    end

    # Starts the listening TCPServer. Note that this is abstracted to allow
    # for overriding default behavior, like adding support for accepting
    # connections over SSL/TLS
    def start_server!
      @logger.info "Listening on #{@host}:#{@port}"
      @server = TCPServer.new(@host, @port)
      if @ssl
        @logger.info "Initializing SSL context"
        raise "Must provide SSL key" if @ssl_key.nil?
        raise "Must provide SSL certificate" if @ssl_cert.nil?

        @socket = @server
        @ctx = OpenSSL::SSL::SSLContext.new
        @ctx.cert = OpenSSL::X509::Certificate.new(File.open(@ssl_cert))
        @ctx.key = OpenSSL::PKey::RSA.new(File.open(@ssl_key))

        @server = OpenSSL::SSL::SSLServer.new(@socket, @ctx)
      end
    end
  end
end
