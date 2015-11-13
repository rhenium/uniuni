module Uniuni
  class LazyClientResponse
    def initialize(client, res)
      @client = client
      @res = res
      @buffer = []
      res.on_chunk { |chunk|
        @buffer << chunk
      }
    end

    def each
      loop do
        while n = @buffer.shift
          yield n
        end
        break if @res.finished? || @res.failed?
        @client.session.succ
      end
    end

    def close
      @client.close
    end
  end
end
