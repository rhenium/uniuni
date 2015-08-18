module Plum::Server
  class Analyzer
    def initialize
    end

    def start
      dic = {}
      Dir.glob(File.expand_path("./**/*.html", Config.root)) do |file|
        deps = parse_html(file)

        fileabs = get_abs(file)
        depabs = deps.map {|dep| get_abs(dep) }

        Logger.debug "#{fileabs}: #{depabs.join(", ")}"
        dic[fileabs] = depabs
      end

      YAML.dump(dic, File.open(Config.dependency_cache, "w"))
    end

    private
    def parse_html(file)
      doc = Oga.parse_html(File.read(file))
      assets = []
      doc.xpath("img").each {|img| assets << img.get("src") }
      doc.xpath("//html/head/link[@rel='stylesheet']").each {|css| assets << css.get("href") }
      doc.xpath("script").each {|js| assets << js.get("src") }
    
      assets.compact.uniq.map {|path|
        next nil if path.include?("//")
    
        if path.start_with?("/")
          File.expand_path(Config.root + path)
        else
          File.expand_path(path, file)
        end
      }.compact.select {|path|
        !get_abs(path).include?("..") && File.file?(path)
      }
    rescue => e
      []
    end

    def get_abs(file)
      root_pn = Pathname.new(Config.root)
      file_pn = Pathname.new(file)
      "/" << file_pn.relative_path_from(root_pn).to_s
    end
  end
end
