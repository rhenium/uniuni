require "http_parser"
require "uri"

module Plum::Server
  class Responder
    def initialize(stream, headers, data, plum, logprefix)
      @stream = stream
      @headers = headers
      @data = data
      @plum = plum
      @logprefix = logprefix
    end

    def respond_request
      Config.servers.each do |reg, options|
        match = Regexp.new(reg).match(@headers[":path"])
        if match
          origin = options["origin"].gsub(/$(\d+)/) {|m| match[m[0].to_i] }
          return respond_proxy(@stream, origin, @headers)
        end
      end
      respond_local
    end

    def respond_proxy(stream, upstream, headers)
      request = "#{headers[":method"].upcase} #{headers[":path"]} HTTP/1.1\r\n"
      request << "Host: #{headers[":authority"]}\r\n"
      request << headers.reject {|k, v| k.start_with?(":") }.map {|k, v| "#{k}: #{v}\r\n"}.join
      request << "\r\n"
      request << @body if @body

      parser = Http::Parser.new
      parser.on_headers_complete = proc {
        Logger.info(@logprefix + "#{stream.id}: respond #{parser.status_code}")
        # stream.__send__(:send_headers, parser.headers.map {|k, v| [k.downcase, v] }.to_h.merge(
        #   "connection" => "close",
        #   ":status" => parser.status_code,
        #   "x-server" => parser.headers["Server"],
        #   "server" => "plum/#{Plum::VERSION}"), end_stream: false)
        stream.__send__(:send_headers,
                        {":status" => parser.status_code}.merge(parser.headers.map {|k, v| [k.downcase, v] }.to_h).merge(
                          "x-server" => parser.headers["Server"],
                          "server" => "plum/#{Plum::VERSION}",
                          ":status" => parser.status_code
                        ).reject {|k, v| ["connection"].include?(k) },
                        end_stream: false)
      }
      parser.on_body = proc {|chunk|
        stream.__send__(:send_data, chunk, end_stream: false)
      }
      parser.on_message_complete = proc do |e|
        stream.__send__(:send_data, "", end_stream: true)
      end
      uri = URI.parse(upstream)
      TCPSocket.open(uri.host, uri.port) {|sock|
        sock.write(request)
        while !sock.closed? && !sock.eof?
          parser << sock.readpartial(4096)
        end
      }
    end

    def respond_local
      if @headers[":method"] == "GET"
        Logger.info(@logprefix + "#{@stream.id}: request: GET " + @headers[":path"])
        get(@stream, @headers)
      else
        Logger.info(@logprefix + "#{@stream.id}: request: " + @headers[":method"] + " " + @headers[":path"])
        respond_error(@stream, 501, @headers, @data)
      end
    end

    def get(stream, headers)
      httppath = headers[":path"].dup
      httppath << Config.index if httppath.end_with?("/")

      unless httppath.start_with?("/")
        Logger.info(@logprefix + "#{stream.id}: invalid path: " + httppath)
        return respond_error(stream, 400, headers)
      end

      realpath = Assets.realpath(httppath)

      if !Assets.underroot?(realpath)
        Logger.info(@logprefix + "#{stream.id}: invalid path: " + httppath)
        return respond_error(stream, 404, headers)
      elsif Dir.exist?(realpath)
        Logger.info(@logprefix + "#{stream.id}: directory redirect: " + httppath)
        return respond_redirect(stream, 308, httppath + "/")
      elsif !File.exist?(realpath)
        Logger.info(@logprefix + "#{stream.id}: not found: " + httppath)
        return respond_error(stream, 404, headers)
      end

      size = File.stat(realpath).size
      io = Assets.fetch(realpath)
  
      if Config.push && @plum.push_enabled?
        i_sts = Assets.dependencies(httppath).map {|asset|
          st = stream.promise({
            ":authority": headers[":authority"],
            ":method": "GET",
            ":scheme": "https",
            ":path": asset })
          Logger.info(@logprefix + "#{st.id}: server push: " + asset)
          [st, asset]
        }
      end
  
      respond(stream, 200, {
        "content-type": content_type(httppath),
        "content-length": size }, io)
  
      if Config.push && @plum.push_enabled?
        i_sts.each do |st, asset|
          rep = Assets.realpath(asset)
          asize = File.stat(rep).size
          aio = Assets.fetch(rep)
          respond(st, 200, {
            "content-type": content_type(asset),
            "content-length": asize }, aio)
        end
      end
    end
  
    def respond_error(stream, status_code, headers, data = nil)
      body = headers.map {|name, value| "#{name}: #{value}" }.join("\n") + "\n" + data.to_s
      respond(stream, status_code, {
        "content-type": "text/plain",
        "content-length": body.bytesize }, body)
    end

    def respond_redirect(stream, status_code, location)
      respond(stream, status_code, { "location": location })
    end

    def respond(stream, code, headers, data = nil)
      Logger.info(@logprefix + "#{stream.id}: respond #{code}")
      if data
        stream.respond({
          ":status": code,
          "server": "plum/#{Plum::VERSION}" }.merge(headers), data)
      else
        stream.respond({
          ":status": code,
          "server": "plum/#{Plum::VERSION}"}.merge(headers))
      end
    end

    def content_type(filename)
      exp, ct = Config.content_types.lazy.select {|pat, e| Regexp.new(pat) =~ filename }.first
      ct || "text/plain"
    end
  end
end
