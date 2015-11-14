require "pathname"
require "oga"

module Uniuni
  class Analyzer
    def initialize(file)
      @config = YAML.load_file(file)
    end

    def run
      @config["sites"].each do |host, conf|
        analyze(conf)
      end
    end

    def analyze(conf)
      root = conf["root"]
      dfile = conf["dependency-map"]
      return unless dfile

      dic = {}
      Dir.glob(File.expand_path("./**/*.html", root)) do |file|
        deps = parse_html(root, file)

        fileabs = get_abs(root, file)
        depabs = deps.map {|dep| get_abs(root, dep) }

        puts "#{fileabs}: #{depabs.join(", ")}"
        dic[fileabs] = depabs
      end

      YAML.dump(dic, File.open(dfile, "w"))
    end

    private
    def parse_html(root, file)
      doc = Oga.parse_html(File.read(file))
      assets = []
      doc.xpath("//img").each {|img| assets << img.get("src") }
      doc.xpath("/html/head/link[@rel='stylesheet']").each {|css| assets << css.get("href") }
      doc.xpath("//script").each {|js| assets << js.get("src") }
    
      assets.compact.uniq.map {|path|
        next nil if path.include?("//")
    
        if path.start_with?("/")
          File.expand_path(root + path)
        else
          File.expand_path(path, file)
        end
      }.compact.select {|path|
        !get_abs(root, path).include?("..") && File.file?(path)
      }
    rescue => e
      []
    end

    def get_abs(root, file)
      root_pn = Pathname.new(root)
      file_pn = Pathname.new(file)
      "/" << file_pn.relative_path_from(root_pn).to_s
    end
  end
end
