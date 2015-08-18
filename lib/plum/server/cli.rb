module Plum::Server
  class CLI < Thor
    class_option :config
    class_option :debug, type: :boolean

    desc "server", "Run a HTTP/2 server."
    options port: :numeric, tls: :boolean
    def server
      load_config(options)

      if Config.debug
        begin
          require "sslkeylog/autotrace"
        rescue LoadError
        end
      end

      if Config.tls
        server = HTTPSServer.new
      else
        server = HTTPServer.new
      end

      server.start
    end

    desc "analyze", "Analyze document root and analyze file dependency."
    def analyze
      load_config(options)

      analyzer = Analyzer.new
      analyzer.start
    end

    private
    def load_config(options)
      Config.load(options[:config]) if options[:config]
      Config.overlay(options.reject {|k, _| k == :config }.to_h)

      required = [:root]
      lacks = required.reject {|key| Config[key] }

      unless lacks.empty?
        str = lacks.map {|key| "#{key.inspect}" }.join(", ")
        raise ArgumentError.new("parameter #{str} is missing.")
      end
    end
  end
end
