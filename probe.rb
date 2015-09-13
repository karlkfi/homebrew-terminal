require "language/go"

class Probe < Formula
  desc "Command-line service interrogator"
  homepage "https://github.com/karlkfi/probe"
  head "https://github.com/karlkfi/probe.git"

  stable do
    url "https://github.com/karlkfi/probe/archive/v0.1.0.tar.gz"
    sha256 "ee40591f7722202a62049b181f864aef544d0fcd6370f675f502e6d2cd920644"
  end

  depends_on "go" => :build

  go_resource "github.com/tools/godep" do
    url "https://github.com/tools/godep.git", :revision => "aeda8bab6aa7e64e94a83b40e29858daeb85ee87"
  end

  def install
    contents = Dir["{*,.git,.gitignore}"]
    gopath = buildpath/"gopath"
    (gopath/"src/github.com/karlkfi/probe").install contents

    ENV["GOPATH"] = gopath
    ENV.prepend_create_path "PATH", gopath/"bin"
    Language::Go.stage_deps resources, gopath/"src"

    cd gopath/"src/github.com/tools/godep" do
      system "go", "install"
    end

    cd gopath/"src/github.com/karlkfi/probe" do
      system "make", "restoredeps"
      system "make", "build"
      bin.install "probe"
    end
  end

  test do
    # Open pipe to read server port
    rd, wr = IO.pipe

    # Launch test server
    pid = fork do
      require "socket"

      # Ask OS for free port
      server = TCPServer.new "127.0.0.1", 0
      port = server.addr[1]

      puts "Listening on port #{port}"

      # Write port to pipe
      rd.close
      wr.write port
      wr.close

      loop do
        socket = server.accept
        resp = "Ready\n"
        headers = [
          "HTTP/1.1 200 OK",
          "Content-Type: text/plain; charset=iso-8859-1",
          "Content-Length: #{resp.length}",
          "",
          ""
        ].join("\r\n")
        socket.puts headers
        socket.puts resp
        socket.close
      end
    end

    # Read port from pipe
    wr.close
    port = rd.read
    rd.close

    # Yield and wait for server to come up
    sleep 1

    # Expect exit 0
    system "probe", "http://127.0.0.1:#{port}"

    # Kill test server
    Process.kill("TERM", pid)
  end
end
