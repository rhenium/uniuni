module Plum::Server
  class Session
    def initialize(sock, connection)
      @plum = connection.new(sock)
    end
  
    def run
      @plum.on(:frame) {|frame| Logger.debug("recv: #{frame.inspect}") }
      @plum.on(:send_frame) {|frame| Logger.debug("send: #{frame.inspect}") }
      @plum.on(:remote_settings) {|settings| Logger.debug(settings.map {|name, value| "#{name}: #{value}" }.join(", ")) }
      @plum.on(:connection_error) {|exception| Logger.info(exception.to_s + " // " + exception.backtrace.join(" // ")) }
      
      @plum.on(:stream) do |stream|
        headers = data = nil
        Logger.debug("#{stream.id}: stream open")
        stream.on(:stream_error) {|exception| Logger.info(exception.to_s + " // " + exception.backtrace.join(" // ")) }
      
        stream.on(:open) {
          headers = nil
          data = ""
        }
      
        stream.on(:headers) {|headers_|
          Logger.debug(headers_.map {|name, value| "#{name}: #{value}" }.join(", "))
          headers = headers_.to_h
        }
      
        stream.on(:data) {|data_|
          Logger.debug(data_)
          data << data_
        }
  
        stream.on(:end_stream) do
          Logger.info(headers[":method"] + " " + headers[":path"])
          if headers[":method"] == "GET"
            get(stream, headers)
          else
            respond_error(stream, 501, headers, data)
          end
        end
      end
  
      @plum.run
    end

    def close
      @plum.close
    end
  
    def get(stream, headers)
      httppath = headers[":path"].dup
      httppath << Config.index if httppath.end_with?("/")

      unless httppath.start_with?("/")
        # Invalid :path
        return respond_error(stream, 400, headers)
      end

      realpath = Assets.realpath(httppath)

      if !Assets.underroot?(realpath)
        return respond_error(stream, 404, headers)
      elsif Dir.exist?(realpath)
        return respond_redirect(stream, 308, httppath + "/")
      elsif !File.exist?(realpath)
        return respond_error(stream, 404, headers)
      end

      size = File.stat(realpath).size
      io = Assets.fetch(realpath)
  
      i_sts = Assets.dependencies(httppath).map {|asset|
        st = stream.promise({
          ":authority": headers[":authority"],
          ":method": "GET",
          ":scheme": "https",
          ":path": asset })
        [st, asset]
      }
  
      respond(stream, 200, {
        "content-type": content_type(httppath),
        "content-length": size }, io)
  
      i_sts.each do |st, asset|
        rep = Assets.realpath(asset)
        asize = File.stat(rep).size
        aio = Assets.fetch(rep)
        respond(st, 200, {
          "content-type": content_type(asset),
          "content-length": asize }, aio)
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
