module Plum::Server
  class Assets
    class << self
      def fetch(file)
        File.open(file)
      end

      def dependencies(cleanpath)
        db[cleanpath] || []
      end

      def realpath(file)
        raise ArgumentError unless file.start_with?("/")
        File.expand_path(file[1..-1], Config.root)
      end

      def underroot?(realpath)
        root = Config.root.dup
        root << "/" unless root.end_with?("/")
        realpath.start_with?(root)
      end

      private
      def db
        @_db ||= YAML.load_file(Config.dependency_cache)
      end
    end
  end
end
