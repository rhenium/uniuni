module Plum::Server
  class LegacySession
    def initialize(sock)
      @sock = sock

      if sock.respond_to?(:peeraddr)
        @logprefix = "#{sock.peeraddr.last}: "
      elsif sock.respond_to?(:io) && sock.io.respond_to?(:peeraddr)
        @logprefix = "#{sock.io.peeraddr.last}: "
      else
        @logprefix = ""
      end
    end

    def run
      if Config.legacy_backend
        legacy_response
      else
        not_supported
      end
    end

    def legacy_response
      _h, _p = Config.legacy_backend.split(":")
      upstream = TCPSocket.open(_h, _p.to_i)
      begin
        loop do
          ret = IO.select([@sock, upstream])
          ret[0].each do |s|
            a = s.readpartial(1024)
            (s == upstream ? @sock : upstream).write(a)
          end
        end
      rescue EOFError
      end
      upstream.close
    end

    def not_supported
      parser = HTTP::Parser.new
      parser.on_message_complete = proc do
        Logger.info "#{@sock.io.peeraddr.last}: LegacyHTTP: #{parser.request_url.to_s}"
        data = "<!DOCTYPE html>\n" <<
               "<meta charset=\"UTF-8\">\n" <<
               "<title>HTTP/1.1 505 HTTP Version Not Supported</title>\n" <<
               "<p>あなたのウェブブラウザは HTTP/2 に対応していません。</p>\n"

        resp = ""
        resp << "HTTP/1.1 505 HTTP Version Not Supported\r\n"
        resp << "Content-Type: text/html\r\n"
        resp << "Content-Length: #{data.bytesize}\r\n"
        resp << "Server: plum/#{Plum::VERSION}\r\n"
        resp << "\r\n"
        resp << data

        @sock.write(resp)
        @sock.close
      end

      while !@sock.closed? && !@sock.eof?
        parser << @sock.readpartial(1024)
      end
    end

    def session
      @sock.close
    end
  end
end
