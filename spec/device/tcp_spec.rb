require 'logstash-logger'

describe LogStashLogger::Device::TCP do
  include_context 'device'

  let(:tcp_socket) { double('TCPSocket') }
  let(:ssl_socket) { double('SSLSocket') }

  before(:each) do
    allow(TCPSocket).to receive(:new) { tcp_socket }
    allow(tcp_socket).to receive(:sync=)

    allow(OpenSSL::SSL::SSLSocket).to receive(:new) { ssl_socket }
    allow(ssl_socket).to receive(:connect)
  end

  context "use SSL" do
    context "when not using SSL" do
      it "writes to a TCP socket" do
        expect(tcp_socket).to receive(:write)
        tcp_device.write('test')
      end

      it "returns false for #use_ssl?" do
        expect(tcp_device.use_ssl?).to be_falsey
      end
    end

    context "when using SSL" do
      it "writes to an SSL TCP socket" do
        expect(ssl_socket).to receive(:write)
        ssl_tcp_device.write('test')
      end

      it "returns true for #use_ssl?" do
        expect(ssl_tcp_device.use_ssl?).to be_truthy
      end
    end
  end

  context "use KEEPALIVE" do
    before(:each) do
      allow(tcp_socket).to receive(:setsockopt)
      allow(tcp_socket).to receive(:write)
      allow(tcp_socket).to receive(:close)
      allow(ssl_socket).to receive(:write)
    end

    context "when not using KEEPALIVE" do
      it "doesn't call setsockopt" do
        expect(tcp_socket).not_to receive(:setsockopt)
        tcp_device.write('test')
      end

      it "returns false for #use_keepalive?" do
        expect(tcp_device.use_keepalive?).to be_falsey
      end
    end

    context "when using KEEPALIVE" do
      it "calls setsockopt" do
        expect(tcp_socket).to receive(:setsockopt).with(:SOCKET, :KEEPALIVE, true)
        keepalive_tcp_device.write('test')
      end

      it "returns true for #use_keepalive?" do
        expect(keepalive_tcp_device.use_keepalive?).to be_truthy
      end
    end
  end

  context "reconnect on connection failures" do
    before(:each) do
      allow(tcp_device).to receive(:warn)
      allow(tcp_device).to receive(:close)
      allow(tcp_socket).to receive(:write)
    end

    it "should call #reconnect when connection failure occures" do
      # found no clear way of raising exception just once
      times_called = 0
      allow(tcp_socket).to receive(:write) do
        times_called += 1
        raise Errno::EPIPE if times_called == 1
      end
      expect(tcp_device).to receive(:reconnect)
      tcp_device.write('test')
    end

    it "should give up reconnecting after 5 retries" do
      allow(tcp_socket).to receive(:write).and_raise(Errno::EPIPE).exactly(6).times
      expect(tcp_device).to receive(:reconnect).exactly(5).times
      tcp_device.write('test')
    end

    it "should print a warn message when giving up reconnecting" do
      allow(tcp_socket).to receive(:write).and_raise(Errno::EPIPE).exactly(6).times
      expect(tcp_device).to receive(:warn)
      tcp_device.write('test')
    end
  end
end
