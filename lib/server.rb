require 'socket'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'commands'

class Server
  def initialize(host='', port='5303')
    @socket = UDPSocket.new
    @socket.bind(host, port)
    
    @clients = []
  end
  
  def broadcast(data)
    @clients.each do |client|
      @socket.send(data, Socket::MSG_DONTROUTE, Addrinfo.new(client))
    end
  end
  
  def run
    while true
      data, sender = @socket.recvfrom(65536)
      command = data.unpack('n')[0]
      if !@clients.include?(sender) && command != Commands::CONNECT
        puts "Ignoring a ##{command} from a disconnected client"
        next
      end
      
      case command
      when Commands::CONNECT
        if @clients.include? sender
          puts 'Ignoring a CONNECT command from a connected client'
        else
          @clients << sender
          broadcast([Commands::CONNECT, sender[3]].pack('n a*x'))
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
        broadcast([Commands::DRAW, sender[3], x, y].pack('n Z* n n'))
        puts "DRAW #{sender[3]} #{x} #{y}"
      end
    end
  end
end
