require 'logger'
require 'digest'
require 'stringio'
require 'timeout'
require_relative '../websocket_client'
require_relative '../websocket_server'

class Harness
  PROJ_ROOT ||= File.dirname(File.dirname(File.expand_path(__FILE__)))

  attr_reader :websocket_log

  def initialize(opts = {})
    @port = opts[:port] || 9881
    @host = opts[:host] || 'localhost'
    @websocket_log = StringIO.new
    @log_mutex = Mutex.new
  end

  def self.run_test(opts = {}, &blk)
    harness = Harness.new(opts)
    begin
      harness.instance_exec(&blk)
    rescue => e
      harness.log "#{e.class}: #{e.message}"
      harness.log e.backtrace.join("\n")
    end
    harness.log
    harness.scenario 'Client and server logs:'
    harness.log(harness.websocket_log.string)
  end

  def start_websocket_server
    options = {
      port: @port,
      host: @host,
      logger: make_logger,
    }
    @socket_server = WebSocket::Server.new(options)
    @socket_server.run!
    Timeout::timeout(1) { @socket_server.running? }
    @socket_server
  end

  def stop_websocket_server
    @socket_server.stop! if @socket_server
  end

  def make_logger
    log = Logger.new(@websocket_log)
    log.formatter = proc { |sev, dt, name, msg|
      "#{sev.to_s.ljust(6, ' ')} #{name} #{msg.to_s.strip}\n"
    }
    log.level = Logger::INFO
    log
  end

  def connect_client(opts = {})
    Timeout::timeout(1) do
      WebSocket::Client.connect(@host, @port, opts.merge(logger: make_logger))
    end
  end

  def sanitize(line)
    line.gsub(/:#{@port}/, ':[WEBSOCKET_PORT]')
  end

  def log(line = '')
    @log_mutex.synchronize do
      puts sanitize(line)
      $stdout.flush
    end
  end

  def scenario(name)
    log '#' * 80
    log "# #{name}#{' ' * (76 - name.length)} #"
    log '#' * 80
    log
  end
end
