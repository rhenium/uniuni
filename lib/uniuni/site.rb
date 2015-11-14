module Uniuni
  class Site
    def initialize(sconfig)
      @prefixes = sconfig["prefixes"].map { |prefix, pconfig|
        [prefix, ProxyHandler.new(pconfig)]
      }
      @handler = Handler.new(sconfig)
    end

    def call(env)
      path = env["PATH_INFO"] + env["SCRIPT_NAME"]
      path = "/" if path.empty?
      if phandler = find_handler(path)
        phandler.handle(env, path)
      else
        @handler.handle(env, path)
      end
    end

    private
    def find_handler(path)
      h = @prefixes.find { |prefix, handler|
        path.start_with?(prefix)
      }
      h && h[1] or @root_handler
    end
  end
end
