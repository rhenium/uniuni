module Uniuni
  class ProxyHandler
    def initialize(pconfig)
      @host = pconfig["host"]
      @port = pconfig["port"]
    end

    def handle(env, path)
      ppath = path
      ppath += "?" + env["QUERY_STRING"] unless env["QUERY_STRING"].empty?
      headers = { ":method" => env["REQUEST_METHOD"],
                  ":path" => ppath }
      env.each { |k, v|
        next unless k.start_with?("HTTP_")
        next if k == "HTTP_VERSION"
        next if k == "HTTP_CONNECTION"
        next if k == "HTTP_HOST"
        headers[k[5..-1].gsub("_", "-").downcase] = v
      }

      body = String.new
      env["rack.input"].each { |chunk|
        body << chunk
      }

      rhs = rcode = nil
      client = Plum::Client.start(@host, @port, http2: false, scheme: "http", auto_decode: false)
      res = client.request(headers, body) { |res|
        rhs = res.headers.dup
        rhs.delete(":status")
        rhs.delete("connection")
        rhs.delete("content-length")
        rhs["transfer-encoding"] = rhs["transfer-encoding"].gsub(/(, ?)?chunked/, "") if rhs["transfer-encoding"]
        rhs["x-proxy-server"] = "uniuni/#{Uniuni::VERSION} (plum/#{Plum::VERSION})"
        rcode = res.status
      }
      client.session.succ until res.failed? || res.headers

      [rcode.to_i, rhs, LazyClientResponse.new(client, res)]
    end
  end
end
