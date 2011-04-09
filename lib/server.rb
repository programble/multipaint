require 'socket'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'commands'

class Server
  def initialize(host='', port=5303)
    @socket = UDPSocket.new
    @socket.bind(host, port)
    @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    
    @clients = []
    @points = []
  end
  
  def broadcast(data)
    @clients.each do |client|
      @socket.send(data, 0, Addrinfo.new(client))
    end
  end
  
  def run
    while true
      data, sender = @socket.recvfrom(65536)
      command = data.unpack('n')[0]
      if !@clients.include?(sender) && command != Commands::CONNECT
        puts "##{command} #{sender[3]} (IGNORED)"
        next
      end
      
      case command
      when Commands::CONNECT
        if @clients.include? sender
          puts 'Ignoring a CONNECT command from a connected client'
        else
          @clients << sender
          broadcast([Commands::CONNECT, sender[3]].pack('n a*x'))
          @points.each do |point|
            @socket.send([Commands::DRAW, '', point[0], point[1]].pack('n Z* n n'), 0, Addrinfo.new(sender))
          end
          puts "CONNECT #{sender[3]}"
        end
      when Commands::DISCONNECT
        @clients.delete(sender)
        broadcast([Commands::DISCONNECT, sender[3]].pack('n Z*'))
        puts "DISCONNECT #{sender[3]}"
      when Commands::MESSAGE
        message = data.unpack('n Z*')[1]
        broadcast([Commands::MESSAGE, sender[3], message].pack('n Z* Z*'))
        puts "MESSAGE #{sender[3]} #{message}"
      when Commands::DRAW
        x, y = data.unpack('n n n')[1..2]
        next if @points.include?([x,y])
        @points << [x, y]
        broadcast([Commands::DRAW, sender[3], x, y].pack('n Z* n n'))
        puts "DRAW #{sender[3]} #{x} #{y}"
      when Commands::ERASE
        x, y = data.unpack('n n n')[1..2]
        erased = @points.select {|point| point[0] < x + 10 && point[0] > x - 10 && point[1] < y + 10 && point[1] > y - 10}
        erased.each do |point|
          @points.delete(erased)
          broadcast([Commands::ERASE, sender[3], point[0], point[1]].pack('n Z* n n'))
          puts "ERASE #{sender[3]} #{point[0]} #{point[1]}"
        end
      end
    end
  end
end
