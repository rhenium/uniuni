module Plum::Server
  class HTTPServer
    def initialize
      @tcp_server = TCPServer.new(Config.listen, Config.port)
    end

    def start
      loop do
        begin
          sock = @tcp_server.accept
          Logger.debug "#{sock.peeraddr.last}: accept"

          session = Session.new(sock, Plum::HTTPConnection)

          thread = Thread.new {
            begin
              session.run
            rescue Plum::LegacyHTTPError => e
              session.close
              session = LegacySession.new(sock)
              session.run
            rescue => e
              Logger.warn sock.peeraddr.last + ": " + e.to_s
              Logger.warn sock.io.peeraddr.last + ": " + e.backtrace.join("\n")
            ensure
              session.close
            end
          }
        rescue => e
          Logger.warn e
          next
        end
      end
    end
  end
end
