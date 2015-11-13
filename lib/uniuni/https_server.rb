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
          session = nil
          begin
            if sock.alpn_protocol == "h2" && sock.ssl_version >= "TLSv1.2"
              session = Session.new(sock, Plum::HTTPSConnection)
              session.run
            else
              session = LegacySession.new(sock)
              session.run
            end
          rescue => e
            Logger.warn sock.io.peeraddr.last + ": " + e.to_s
            Logger.warn sock.io.peeraddr.last + ": " + e.backtrace.join("\n")
          ensure
            sock.close
            session.close if session
          end
        }
      end
    end

    private
    def ssl_context
      ctx = OpenSSL::SSL::SSLContext.new
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
      ctx.extra_chain_cert = [OpenSSL::X509::Certificate.new(File.read(Config.tls_certificate_ca))] if Config.tls_certificate_ca
      ctx.key = OpenSSL::PKey::RSA.new(File.read(Config.tls_certificate_key))
      ctx
    end
  end
end
