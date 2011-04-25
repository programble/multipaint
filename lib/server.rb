require 'socket'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'commands'

class Server
  def initialize(host='', port=5303)
    @socket = UDPSocket.new
    @socket.bind(host, port)
    @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    
    @clients = []
    @nicks = {}
    @points = []
  end
  
  def broadcast(data)
    @clients.each do |client|
      @socket.send(data, 0, Addrinfo.new(client[0..3]))
    end
  end
  
  def run
    while true
      data, sender = @socket.recvfrom(65536)
      command = data.unpack('n')[0]
      if !@clients.include?(sender) && command != Commands::CONNECT
        puts "#{data.inspect} #{sender[3]} (IGNORED)"
        next
      end
      
      case command
      when Commands::CONNECT
        @nicks[sender] = data.unpack('n Z*')[1]
        @clients << sender unless @clients.include?(sender)
        broadcast([Commands::CONNECT, @nicks[sender]].pack('n Z*'))
        @points.each_slice(1024) do |points|
          @socket.send([Commands::DRAW, '', *points.flatten].pack('n Z* n*'), 0, Addrinfo.new(sender[0..3]))
        end
        puts "CONNECT #{sender[3]}/#{@nicks[sender]}"
      when Commands::DISCONNECT
        @clients.delete(sender)
        broadcast([Commands::DISCONNECT, @nicks[sender]].pack('n Z*'))
        puts "DISCONNECT #{sender[3]}/#{@nicks[sender]}"
      when Commands::MESSAGE
        message = data.unpack('n Z*')[1]
        broadcast([Commands::MESSAGE, @nicks[sender], message].pack('n Z* Z*'))
        puts "MESSAGE #{sender[3]}/#{@nicks[sender]} #{message}"
      when Commands::DRAW
        x, y, color = data.unpack('n n n n')[1..3]
        next if @points.include?([x,y,color])
        @points << [x, y, color]
        broadcast([Commands::DRAW, @nicks[sender], x, y, color].pack('n Z* n n n'))
        puts "DRAW #{sender[3]}/#{@nicks[sender]} #{x} #{y} #{color}"
      when Commands::ERASE
        x, y = data.unpack('n n n')[1..2]
        erased = @points.select {|point| point[0] < x + 10 && point[0] > x - 10 && point[1] < y + 10 && point[1] > y - 10}
        erased.each do |point|
          @points.delete(point)
          broadcast([Commands::ERASE, @nicks[sender], point[0], point[1], point[2]].pack('n Z* n n n'))
          puts "ERASE #{sender[3]}/#{@nicks[sender]} #{point[0]} #{point[1]}"
        end
      when Commands::PINGPONG
        puts "PING #{sender[3]}/#{@nicks[sender]} #{data.inspect}"
        @socket.send(data, 0, Addrinfo.new(sender[0..3]))
      end
    end
  end
end
