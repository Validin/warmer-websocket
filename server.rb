#!/usr/bin/env ruby

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


# When this script is run directly, two servers are started with default args:
# - an HTTP server for serving static content
# - a WebSockets server for handling WebSocket requests
#
# For usage instructions, run this script with the '-?' flag
if $PROGRAM_NAME == __FILE__
  require 'optparse'
  require 'webrick'
  require 'logger'
  require_relative 'websocket_server'

  options = {
    host: '127.0.0.1',
    web_port: 8080,
    socket_port: 4568,
  }
  args = ARGV.dup
  opt_parse = OptionParser.new do |opts|
    opts.banner = "Usage: ./#{File.basename(__FILE__)} [options]"
    opts.on('-h', '--host=HOST', String, 'Host serving content') do |host|
      options[:host] = host
    end
    opts.on('-p', '--web-port=PORT', Integer, 'Port serving HTTP') do |port|
      options[:web_port] = port
    end
    opts.on('-s', '--socket-port=PORT', Integer, 'Port serving WebSocket') do |port|
      options[:socket_port] = port
    end
    opts.on_tail('-?', '--help', 'Display help') do
      puts opt_parse
      exit
    end
  end
  begin
    opt_parse.parse!(args)
  rescue OptionParser::InvalidOption => e
    $stderr.puts "Error - #{e.message}"
    $stderr.puts opt_parse
    exit -1
  end

  http_logger = Logger.new(STDOUT)
  http_logger.level = Logger::WARN

  http_opts = {
    :Host => options[:host],
    :Port => options[:web_port],
    :DocumentRoot => './',
    :Logger => Logger.new(STDOUT),
  }
  http_server = WEBrick::HTTPServer.new http_opts

  ws_logger = Logger.new(STDOUT)
  ws_logger.level = Logger::DEBUG
  sock_opts = {
    host: options[:host],
    port: options[:socket_port],
    logger: ws_logger,
  }
  websocket_server = WebSocket::Server.new sock_opts
  websocket_server.on(:text) do |client, payload, last_frame|
    client.send_frame(1, 'Hello!')
  end

  [:INT, :TERM].each do |sig|
    trap(sig) { http_server.stop; websocket_server.stop! }
  end
  # non-blocking
  websocket_server.run!
  # blocking
  http_server.start
end
