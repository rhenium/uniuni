module Plum::Server
  class HTTPSServer
    def initialize
      tcp_server = TCPServer.new(Config.listen, Config.port)
      @ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, ssl_context)
    end

    def start
      loop do
        begin
          sock = @ssl_server.accept
          Logger.debug "#{sock.io.peeraddr.last}: accept"
        rescue => e
          Logger.warn e
          next
        end

        thread = Thread.new {
          begin
            if sock.alpn_protocol == "h2"
              session = Session.new(sock, Plum::HTTPSConnection)
              session.run
            else
              parser = HTTP::Parser.new
              parser.on_message_complete = proc do
                Logger.info "#{sock.io.peeraddr.last}: LegacyHTTP: #{parser.request_url.to_s}"
                data = "<!DOCTYPE html>\n" <<
                       "<title>HTTP/1.1 505 HTTP Version Not Supported</title>\n" <<
                       "<p>あなたのウェブブラウザは HTTP/2 に対応していません。</p>\n"

                resp = ""
                resp << "HTTP/1.1 505 HTTP Version Not Supported\r\n"
                resp << "Content-Type: text/html\r\n"
                resp << "Content-Length: #{data.bytesize}\r\n"
                resp << "Server: plum/#{Plum::VERSION}\r\n"
                resp << "\r\n"
                resp << data

                sock.write(resp)
                sock.close
              end

              while !sock.closed? && !sock.eof?
                parser << sock.readpartial(1024)
              end
            end
          rescue => e
            Logger.warn sock.io.peeraddr.last + ": " + e.to_s
          ensure
            sock.close
          end
        }
      end
    end

    private
    def ssl_context
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ssl_version = :TLSv1_2
      ctx.alpn_select_cb = -> protocols {
        Logger.debug "peer advertived: #{protocols}"
        if protocols.include?("h2")
          "h2"
        else
          "http/1.1"
        end
      }
      ctx.tmp_ecdh_callback = -> (sock, ise, keyl) {
        OpenSSL::PKey::EC.new("prime256v1")
      }

      ctx.cert = OpenSSL::X509::Certificate.new(File.read(Config.tls_certificate))
      ctx.key = OpenSSL::PKey::RSA.new(File.read(Config.tls_certificate_key))
      ctx
    end
  end
end
