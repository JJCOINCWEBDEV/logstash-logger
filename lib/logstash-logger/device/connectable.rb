module LogStashLogger
  module Device
    class Connectable < Base
      RECONNECTABLE_EXCEPTIONS = [Errno::EPIPE, Errno::EBADF, Errno::ECONNRESET, Errno::ENOTCONN]
      MAX_RETRIES = 5

      def write(message)
        with_connection do
          if allow_retrying_on_failures?
            retries = 0
            begin
              super
            rescue *RECONNECTABLE_EXCEPTIONS
              retries += 1
              if retries <= MAX_RETRIES
                reconnect
                retry
              else
                raise
              end
            end
          else
            super
          end
        end
      end

      def flush
        return unless connected?
        with_connection do
          super
        end
      end

      def to_io
        with_connection do
          @io
        end
      end

      def connected?
        !!@io
      end

      def allow_retrying_on_failures?
        !!@allow_retrying_on_failures
      end

      protected

      # Implemented by subclasses
      def connect
        fail NotImplementedError
      end

      def reconnect
        @io = nil
        connect
      end

      # Ensure the block is executed with a valid connection
      def with_connection(&block)
        connect unless @io
        yield
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
        close
        @io = nil
      end
    end
  end
end
