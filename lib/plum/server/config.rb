module Plum::Server
  class Config
    class << self
      def load(file)
        @_config = YAML.load_file(file)
      end

      def overlay(options)
        options.each do |key, val|
          config[key.to_s] = val
        end
      end

      def method_missing(name, *args)
        if args.empty?
          self[name]
        else
          super
        end
      end

      def [](name)
        config[name.to_s]
      end

      private
      def config
        @_config ||= {}
      end
    end
  end
end
