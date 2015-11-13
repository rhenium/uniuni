module Uniuni
  class Site
    def initialize(sconfig)
      @prefixes = sconfig["prefixes"].map { |prefix, pconfig|
        if pconfig["origin"]
          [prefix, ProxyHandler.new(pconfig)]
        else
          [prefix, Handler.new(pconfig)]
        end
      }
      @root_handler = Handler.new(sconfig)
    end

    def call(env)
      path = env["PATH_INFO"] + env["SCRIPT_NAME"]
      path = "/" if path.empty?
      handler = find(path)
      handler.handle(env, path)
    end

    private
    def find(path)
      h = @prefixes.find { |prefix, handler|
        path.start_with?(prefix)
      }
      h && h[1] or @root_handler
    end
  end
end
