module Uniuni
  class Handler
    def initialize(pconfig)
      @root = File.expand_path(pconfig["root"])
      @index = pconfig["index"] || "index.html"
      @default_mime_type = pconfig["default-type"] || "text/plain"
    end

    def handle(env, path)
      case env["REQUEST_METHOD"]
      when "GET", "HEAD"
        handle_local_get(env, path)
      when "OPTIONS"
        [200, { "allow" => "GET, HEAD, OPTIONS" }, []]
      else
        [405, { "allow" => "GET, HEAD, OPTIONS" }, []]
      end
    end

    private
    def handle_local_get(env, path)
      return [404, {}, []] unless path.start_with?("/")
      path << @index if path.end_with?("/")

      rpath = realpath(path)
      return [404, {}, []] unless rpath

      stat = File.stat(rpath)
      return [308, { "location" => path + "/" }, []] if stat.directory?

      last_modified = stat.mtime.httpdate
      return [304, {}, []] if env["HTTP_IF_MODIFIED_SINCE"] == last_modified

      headers = { "last-modified" => last_modified,
                  "content-type" => mime_type(rpath) }

      if env["REQUEST_METHOD"] == "GET"
        # TODO: support range header
        # if range = env["HTTP_RANGE"]
        #   ranges = parse_range(range)
        # end
        [200, headers, File.open(rpath, "rb")]
      else
        [200, headers, []]
      end
    rescue SystemCallError
      [404, {}, []]
    end

    def realpath(path)
      return nil unless path.start_with?("/")
      rpath = File.expand_path(path[1..-1], @root)
      return nil unless rpath.start_with?(@root + "/")
      rpath
    end

    MIME_TYPE = {
      ".html" => "text/html",
      ".css" => "text/css",
    }.sort_by { |suf, typ| -suf.size }
    def mime_type(rpath)
      _, type = MIME_TYPE.find { |suffix, type| rpath.end_with?(suffix) }
     type || @default_mime_type
    end
  end
end
