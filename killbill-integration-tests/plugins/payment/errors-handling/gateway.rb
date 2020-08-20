# frozen_string_literal: true

require 'logger'
require 'socket'

class Gateway
  attr_reader :host, :port
  attr_accessor :next_response_code, :next_response, :trigger_eof_error

  def initialize(logger = Logger.new(STDOUT), host = 'localhost', port = 2000)
    @logger = logger
    @host = host
    @port = port
    reset
  end

  def start
    @server = TCPServer.new(@host, @port)
    Thread.new do
      while (client = @server.accept)
        headers = get_headers(client)
        get_request(client, headers['Content-Length'])
        write_response(client) unless @trigger_eof_error
        client.close
      end
    end
    @logger.info('Gateway initialized')
  end

  def stop
    @server.close
    @logger.info('Gateway shut down')
  end

  def reset
    @next_response_code = 200
    @next_response = 'OK'
    @trigger_eof_error = false
  end

  private

  def get_headers(stream)
    request = {}

    request_line = stream.readline("\r\n")
    return unless request_line.include?('HTTP/')

    stream.each_line("\r\n") do |header|
      if header.include?(': ') || header.include?(":\t")
        keys_and_values = header.split(':')
        request[keys_and_values.shift] = keys_and_values.join(':').strip
      elsif header == "\r\n"
        # End of the request
        break
      end
    end

    @logger.info "Processing request #{request_line.chomp} with headers #{request}"
    request
  rescue IOError, SystemCallError => e
    @logger.warn "Problem with request: #{e} #{request}"
    request
  end

  def get_request(stream, length)
    stream.read(length.to_i)
  end

  def write_response(stream)
    stream.print "HTTP/1.1 #{@next_response_code}/Nothing\r\nContent-type:text/plain\r\n\r\n#{@next_response}"
  end
end
