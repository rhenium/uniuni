module Uniuni
  class CLI
    def initialize(argv)
      @argv = argv
      @options = {}
      parse!
    end

    private
    def parse!
      @parser = setup_parser
      @parser.parse!(@argv)

      command = @argv.shift or raise(ArgumentError.new("command is required"))
      if command != "analyze"
        raise ArgumentError, "only analyze is currently implemented"
      end

      config = @argv.shift || "config.yml"
      analyzer = Analyzer.new(config)
      analyzer.run
    end

    def setup_parser
      OptionParser.new do |o|
        o.on "-v", "--version", "Show version" do
          puts "uniuni version #{Uniuni::VERSION}"
          exit(0)
        end

        o.on "-h", "--help", "Show this message" do
          puts o
          exit(0)
        end

        o.banner = "uniuni [options] [command: (analyze)] [config]"
      end
    end
  end
end
