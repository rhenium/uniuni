module Uniuni
  class App
    def initialize(file)
      @config = YAML.load_file(file)
      @sites = @config["sites"].map { |hostname, sconfig| [hostname, Site.new(sconfig)] }.to_h
    end

    def call(env)
      site = @sites.fetch(env["SERVER_NAME"], @sites.first.last)
      site.call(env)
    end
  end
end
