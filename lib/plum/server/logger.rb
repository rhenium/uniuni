module Plum::Server
  class Logger
    class << self
      def method_missing(name, *args)
        logger.__send__(name, *args)
      end

      private
      def logger
        @_logger ||= ::Logger.new(Config.log || STDOUT).tap {|l|
          l.level = Config.debug ? ::Logger::DEBUG : ::Logger::INFO
        }
      end
    end
  end
end
