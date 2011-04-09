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
    @points = []
    
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
    if button_down? Gosu::Button::MsLeft
      @socket.send([Commands::DRAW, mouse_x, mouse_y].pack('n n n'), 0)
    end
    while true
      begin
        data = @socket.recv_nonblock(65536)
      rescue IO::WaitReadable
        break
      end
      command = data.unpack('n')[0]
      case command
      when Commands::CONNECT
        user = data.unpack('n Z*')[1]
        append_line("#{user} connected")
      when Commands::DISCONNECT
        user = data.unpack('n Z*')[1]
        append_line("#{user} disconnected")
      when Commands::DRAW
        coords = data.unpack('n Z* n n')[2..3]
        @points << coords
      when Commands::MESSAGE
        user, msg = data.unpack('n Z* Z*')[1..2]
        append_line("#{user}: #{msg}")
      end
    end
  end
  
  def button_down(id)
    case id
    when Gosu::Button::KbEscape
      close unless self.text_input
      self.text_input = nil
    when Gosu::Button::KbT
      self.text_input = Gosu::TextInput.new unless self.text_input
    when Gosu::Button::KbReturn
      @socket.send([Commands::MESSAGE, self.text_input.text].pack('n Z*'), 0) if self.text_input
      self.text_input = nil
    end
  end
  
  def needs_cursor?
    true
  end
  
  def draw
    draw_quad(0, 0, Gosu::Color::WHITE, width, 0, Gosu::Color::WHITE, 0, height, Gosu::Color::WHITE, width, height, Gosu::Color::WHITE, 0)
    y = 0
    @lines.each do |line|
      @font.draw(line, 0, y, 1, 1.0, 1.0, Gosu::Color::BLACK)
      y += 15
    end
    @font.draw(">#{text_input.text}", 0, 15*3, 1, 1.0, 1.0, Gosu::Color::BLACK) if self.text_input
    @points.each do |point|
      #draw_line(*a, Gosu::Color::BLACK, *b, Gosu::Color::BLACK, 2)
      #translate(*point) do
        draw_quad(*point, Gosu::Color::BLACK, point[0] + 2, point[1], Gosu::Color::BLACK, point[0] + 2, point[1] + 2, Gosu::Color::BLACK, point[0], point[1] + 2, Gosu::Color::BLACK, 2)
      #end
    end
  end
end
