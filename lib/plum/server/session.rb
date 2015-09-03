module Plum::Server
  class Session
    def initialize(sock, connection)
      @plum = connection.new(sock)
      @threads = []

      if sock.respond_to?(:peeraddr)
        @logprefix = "#{sock.peeraddr.last}: "
      elsif sock.respond_to?(:io) && sock.io.respond_to?(:peeraddr)
        @logprefix = "#{sock.io.peeraddr.last}: "
      else
        @logprefix = ""
      end
    end
  
    def run
      @plum.on(:frame) {|frame| Logger.debug("#{@logprefix}: recv: #{frame.inspect}") }
      @plum.on(:send_frame) {|frame| Logger.debug("#{@logprefix}: send: #{frame.inspect}") }
      @plum.on(:remote_settings) {|settings| Logger.debug(@logprefix + settings.map {|name, value| "#{name}: #{value}" }.join(", ")) }
      @plum.on(:connection_error) {|exception| Logger.info(@logprefix + exception.to_s + " // " + exception.backtrace.join(" // ")) }
      @plum.on(:goaway) {|frame| Logger.debug("#{@logprefix}: recv goaway: #{frame.payload.inspect}") }
      
      @plum.on(:stream) do |stream|
        headers = data = nil
        Logger.debug("#{@logprefix}#{stream.id}: stream open")
        stream.on(:stream_error) {|exception| Logger.info(@logprefix + "#{stream.id}: " + exception.to_s + " // " + exception.backtrace.join(" // ")) }
      
        stream.on(:open) {
          headers = nil
          data = ""
        }
      
        stream.on(:headers) {|headers_|
          Logger.debug(@logprefix + "#{stream.id}: " + headers_.map {|name, value| "#{name}: #{value}" }.join(", "))
          headers = headers_.to_h
        }
      
        stream.on(:data) {|data_|
          Logger.debug(@logprefix + "#{stream.id}: " + data_)
          data << data_
        }
  
        stream.on(:end_stream) do
          thread = Thread.new {
            begin
              responder = Responder.new(stream, headers, data, @plum, @logprefix)
              responder.respond_request
            rescue => e
              Logger.warn "#{@logprefix}: " + e.to_s
              Logger.warn "#{@logprefix}: " + e.backtrace.join("\n")
            end
          }
          thread.abort_on_exception = true
          @threads << thread
        end
      end
  
      @plum.run
    end

    def close
      @plum.close
      @threads.each(&:kill)
    end
  end
end
