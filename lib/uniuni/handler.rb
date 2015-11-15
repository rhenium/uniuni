module Uniuni
  class Handler
    MIME_TYPE = {
      ".html" => "text/html",
      ".xhtml" => "application/xhtml+xml",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".css" => "text/css",
      ".js" => "application/javascript",
      ".atom" => "application/atom+xml",
      ".xml" => "application/xml",
    }.sort_by { |suf, typ| -suf.size }

    DEFAULT_HEADERS = {
      "x-powered-by" => "uniuni/#{Uniuni::VERSION}",
    }

    def initialize(pconfig)
      @root = File.expand_path(pconfig["root"])
      @index = pconfig["index"] || "index.html"
      @default_mime_type = pconfig["default-type"] || "text/plain"
      @push_map = pconfig["dependency-map"] && YAML.load_file(pconfig["dependency-map"]) || {}
      @push_cache = Set.new
    end

    def handle(env, path)
      case env["REQUEST_METHOD"]
      when "GET", "HEAD"
        handle_local_get(env, path)
      when "OPTIONS"
        [200, DEFAULT_HEADERS.merge({ "allow" => "GET, HEAD, OPTIONS" }), []]
      else
        [405, DEFAULT_HEADERS.merge({ "allow" => "GET, HEAD, OPTIONS" }), []]
      end
    end

    private
    def handle_local_get(env, path)
      return [404, DEFAULT_HEADERS, []] unless path.start_with?("/")
      path << @index if path.end_with?("/")

      rpath = realpath(path)
      return [404, DEFAULT_HEADERS, []] unless rpath

      stat = File.stat(rpath)
      return [308, DEFAULT_HEADERS.merge({ "location" => path + "/" }), []] if stat.directory?

      last_modified = stat.mtime.httpdate
      return [304, DEFAULT_HEADERS, []] if env["HTTP_IF_MODIFIED_SINCE"] == last_modified

      headers = DEFAULT_HEADERS.merge({
        "last-modified" => last_modified,
        "content-type" => mime_type(rpath)
      })

      if env["REQUEST_METHOD"] == "GET"
        # TODO: support range header
        # if range = env["HTTP_RANGE"]
        #   ranges = parse_range(range)
        # end

        if spush = @push_map[path]
          headers["plum.serverpush"] = spush.map { |pp|
            next nil unless @push_cache.add?(pp)
            "GET #{pp}"
          }.compact.join(";") # TODO: client may have cache
        end
        [200, headers, File.open(rpath, "rb")]
      else
        [200, headers, []]
      end
    rescue SystemCallError
      [404, DEFAULT_HEADERS, []]
    end

    def realpath(path)
      return nil unless path.start_with?("/")
      rpath = File.expand_path(path[1..-1], @root)
      return nil unless rpath.start_with?(@root + "/")
      rpath
    end

    def mime_type(rpath)
      _, type = MIME_TYPE.find { |suffix, type| rpath.end_with?(suffix) }
     type || @default_mime_type
    end
  end
end
