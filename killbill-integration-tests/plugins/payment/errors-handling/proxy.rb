require 'logger'
require 'webrick/httpproxy'

class Proxy

  attr_reader :host, :port
  attr_accessor :uri_to_break, :min_data_chunk_nb_to_break

  def initialize(logger = Logger.new(STDOUT), host = 'localhost', port = 2500)
    @logger = logger
    @host = host
    @port = port
    reset
  end

  def start
    @server = HackedHTTPProxyServer.new(:Logger => @logger, :Port => @port, :proxy => self)
    Thread.new { @server.start }
    @logger.info('Proxy initialized')
  end

  def stop
    @server.shutdown
    @logger.info('Proxy shut down')
  end

  def reset
    @uri_to_break = nil
    @min_data_chunk_nb_to_break = nil
  end

  private

  class HackedHTTPProxyServer < WEBrick::HTTPProxyServer

    def do_CONNECT(req, res)
      # Proxy Authentication
      proxy_auth(req, res)

      ua = Thread.current[:WEBrickSocket]  # User-Agent
      raise WEBrick::HTTPStatus::InternalServerError,
            "[BUG] cannot get socket" unless ua

      host, port = req.unparsed_uri.split(":", 2)
      # Proxy authentication for upstream proxy server
      if proxy = proxy_uri(req, res)
        proxy_request_line = "CONNECT #{host}:#{port} HTTP/1.0"
        if proxy.userinfo
          credentials = "Basic " + [proxy.userinfo].pack("m").delete("\n")
        end
        host, port = proxy.host, proxy.port
      end

      begin
        @logger.debug("CONNECT: upstream proxy is `#{host}:#{port}'.")
        os = TCPSocket.new(host, port)     # origin server

        if proxy
          @logger.debug("CONNECT: sending a Request-Line")
          os << proxy_request_line << WEBrick::CRWEBrick::LF
          @logger.debug("CONNECT: > #{proxy_request_line}")
          if credentials
            @logger.debug("CONNECT: sending a credentials")
            os << "Proxy-Authorization: " << credentials << WEBrick::CRWEBrick::LF
          end
          os << WEBrick::CRWEBrick::LF
          proxy_status_line = os.gets(WEBrick::LF)
          @logger.debug("CONNECT: read a Status-Line form the upstream server")
          @logger.debug("CONNECT: < #{proxy_status_line}")
          if %r{^HTTP/\d+\.\d+\s+200\s*} =~ proxy_status_line
            while line = os.gets(WEBrick::LF)
              break if /\A(#{WEBrick::CRWEBrick::LF}|#{WEBrick::LF})\z/om =~ line
            end
          else
            raise WEBrick::HTTPStatus::BadGateway
          end
        end
        @logger.debug("CONNECT #{host}:#{port}: succeeded")
        res.status = WEBrick::HTTPStatus::RC_OK
      rescue => ex
        @logger.debug("CONNECT #{host}:#{port}: failed `#{ex.message}'")
        res.set_error(ex)
        raise WEBrick::HTTPStatus::EOFError
      ensure
        if handler = @config[:ProxyContentHandler]
          handler.call(req, res)
        end
        res.send_response(ua)
        access_log(@config, req, res)

        # Should clear request-line not to send the sesponse twice.
        # see: HTTPServer#run
        req.parse(WEBrick::NullReader) rescue nil
      end

      begin
        pipe_data(host, port, ua, os, req, res)
      rescue => ex
        os.close
        @logger.debug("CONNECT #{host}:#{port}: closed")
      end

      raise WEBrick::HTTPStatus::EOFError
    end

    def pipe_data(host, port, ua, os, req, res)
      data_chunk_nb = 0

      while fds = IO::select([ua, os])
        if fds[0].member?(ua)
          buf = ua.sysread(1024);
          @logger.debug("CONNECT: #{buf.bytesize} byte from User-Agent")
          os.syswrite(buf)
        elsif fds[0].member?(os)
          buf = os.sysread(1024);
          @logger.debug("CONNECT: #{buf.bytesize} byte from #{host}:#{port}")

          data_chunk_nb += 1
          if req.unparsed_uri == @config[:proxy].uri_to_break &&
              !@config[:proxy].min_data_chunk_nb_to_break.nil? &&
              data_chunk_nb >= @config[:proxy].min_data_chunk_nb_to_break
            @logger.warn("Skipping #{buf.bytesize} bytes")
          else
            @logger.debug("Sending chunk #{data_chunk_nb}")
            ua.syswrite(buf)
          end
        end
      end
    end
  end
end
