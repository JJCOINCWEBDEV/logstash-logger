require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @use_ssl = !!(@ssl_certificate || opts[:use_ssl] || opts[:ssl_enable])
        @use_keepalive = opts[:use_keepalive] || opts[:keepalive_enable]
        @allow_retrying_on_failures = true
      end

      def use_ssl?
        @use_ssl || !@ssl_certificate.nil?
      end

      def use_keepalive?
        @use_keepalive
      end

      def closed?
        super || server_closed?
      end

      def server_closed?
        # check if socket is in CLOSE_WAIT tcp state (it would have EOF in read
        # stream)
        # it triggers socket read, but it doesn't matter as long as logstash
        # does not respond anything to socket
        return true unless @io
        rs, _, _ = ::IO.select([@io], [], [], 0)
        rs && rs[0] && rs[0].eof?
      end

      protected

      def connect
        if use_ssl?
          ssl_connect
        else
          non_ssl_connect
        end

        @io
      end

      def non_ssl_connect
        @io = TCPSocket.new(@host, @port).tap do |socket|
          socket.sync = sync unless sync.nil?
          socket.setsockopt(:SOCKET, :KEEPALIVE, true) if use_keepalive?
        end
      end

      def ssl_connect
        non_ssl_connect
        #openssl_cert = OpenSSL::X509::Certificate.new(::File.read(@ssl_certificate))
        @io = OpenSSL::SSL::SSLSocket.new(@io)
        @io.connect
      end
    end
  end
end
