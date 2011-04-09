require 'socket'
require 'gosu'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require 'commands'

class GameWindow < Gosu::Window
  def initialize(host, port=5303)
    super(640, 480, false)
    self.caption = "Multiplayer Paint"
    
    @font = Gosu::Font.new(self, Gosu::default_font_name, 15)
    
    @lines = ['', '', '']
    
    @socket = UDPSocket.new
    @socket.connect(host, port)
    @socket.send([Commands::CONNECT].pack('n'), 0)
  end
  
  def append_line(line)
    @lines << line
    @lines.shift
  end
  
  def close
    @socket.send([Commands::DISCONNECT].pack('n'), 0)
    super
  end
  
  def update
    begin
      data, sender = @socket.recvfrom_nonblock(65536)
    rescue IO::WaitReadable
    end
    return unless data
    command = data.unpack('n')[0]
    case command
    when Commands::CONNECT
      user = data.unpack('n Z*')[1]
      append_line("#{user} connected")
    when Commands::DISCONNECT
      user = data.unpack('n Z*')[1]
      append_line("#{user} disconnected")
    end
  end
  
  def button_down(id)
    case id
    when Gosu::Button::KbEscape
      close
    end
  end
  
  def draw
    draw_quad(0, 0, Gosu::Color::WHITE, width, 0, Gosu::Color::WHITE, 0, height, Gosu::Color::WHITE, width, height, Gosu::Color::WHITE, 0)
    y = 0
    @lines.each do |line|
      @font.draw(line, 0, y, 1, 1.0, 1.0, Gosu::Color::BLACK)
      y += 15
    end
  end
end
