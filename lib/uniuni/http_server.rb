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
              Logger.info "#{sock.peeraddr.last}: LegacyHTTP: #{e.parser.request_url.to_s}"
              path = "https://" + e.headers["host"].to_s + e.parser.request_url.to_s

              data = "<!DOCTYPE html>\n" <<
                     "<meta charset=\"UTF-8\">\n" <<
                     "<title>HTTP/1.1 505 HTTP Version Not Supported</title>\n" <<
                     "<p>あなたのウェブブラウザは http URI スキームでの HTTP/2 に対応していません。</p>\n" <<
                     "<p>いくつかのウェブブラウザは https URI スキームでのみ HTTP/2 に対応しています。</p>" <<
                     "<p>このページの HTTPS 版はこちらです: <a href=\"#{CGI.escapeHTML(path)}\">#{CGI.escapeHTML(path)}</a></p>"

              resp = ""
              resp << "HTTP/1.1 505 HTTP Version Not Supported\r\n"
              resp << "Content-Type: text/html\r\n"
              resp << "Content-Length: #{data.bytesize}\r\n"
              resp << "Server: plum/#{Plum::VERSION}\r\n"
              resp << "\r\n"
              resp << data

              sock.write(resp)
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
