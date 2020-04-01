require 'socket'
require 'openssl'

class IRC
  attr_accessor :data

  def send_messages(messages)
    messages = Array(messages)

    if config_boolean_true?('no_colors')
      messages.each{|message|
        message.gsub!(/\002|\017|\026|\037|\003\d{0,2}(?:,\d{1,2})?/, '')}
    else
      messages.each{|message|
        message.gsub!("/COLOR-RED-ESCAPE/",   "\00304")}
      messages.each{|message|
        message.gsub!("/COLOR-GREEN-ESCAPE/", "\00303")}
      messages.each{|message|
        message.gsub!("/COLOR-RESET-ESCAPE/", "\017")}
    end

    rooms = data['room'].to_s
    if rooms.empty?
      raise_config_error "No rooms: #{rooms.inspect}"
      return
    end

    rooms   = rooms.gsub(",", " ").split(" ").map{|room| room[0].chr == '#' ? room : "##{room}"}
    botname = data['nick'].to_s.empty? ? "GitHub#{rand(200)}" : data['nick'][0..16]
    command = config_boolean_true?('notice') ? 'NOTICE' : 'PRIVMSG'

    irc_password("PASS", data['password']) if !data['password'].to_s.empty?
    irc_puts "NICK #{botname}"
    irc_puts "USER #{botname} 8 * :my commitchecker like GitHub IRCBot"

    loop do
      case irc_gets
      when / 00[1-4] #{Regexp.escape(botname)} /
        break
      when /^PING\s*:\s*(.*)$/
        irc_puts "PONG #{$1}"
      end
    end

    nickserv_password = data['nickserv_password'].to_s
    if !nickserv_password.empty?
      irc_password("PRIVMSG NICKSERV :IDENTIFY", nickserv_password)
      loop do
        case irc_gets
        when /^:NickServ/i
          # NickServ responded somehow.
          break
        when /^PING\s*:\s*(.*)$/
          irc_puts "PONG #{$1}"
        end
      end
    end

    without_join = config_boolean_true?('message_without_join')
    rooms.each do |room|
      room, pass = room.split("::")
      irc_puts "JOIN #{room} #{pass}" unless without_join

      messages.each do |message|
        irc_puts "#{command} #{room} :#{message}"
      end

      irc_puts "PART #{room}" unless without_join
    end

    irc_puts "QUIT"
    irc_gets until irc_eof?
  rescue SocketError => boom
    if boom.to_s =~ /getaddrinfo: Name or service not known/
      raise_config_error 'Invalid host'
    elsif boom.to_s =~ /getaddrinfo: Servname not supported for ai_socktype/
      raise_config_error 'Invalid port'
    else
      raise
    end
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    raise_config_error 'Invalid host'
  rescue OpenSSL::SSL::SSLError
    raise_config_error 'Host does not support SSL'
  ensure
    emit_debug_log
  end

  def irc_gets
    response = readable_irc.gets
    debug_incoming(clean_string_for_json(response)) unless !response || response.empty?
    response
  end

  def irc_eof?
    readable_irc.eof?
  end

  def irc_password(command, password)
    real_command = "#{command} #{password}"
    debug_command = "#{command} #{'*' * password.size}"
    irc_puts(real_command, debug_command)
  end

  def irc_puts(command, debug_command=command)
    debug_outgoing(debug_command)
    writable_irc.puts command
  end

  def debug_outgoing(command)
    irc_debug_log << ">> #{command.strip}"
  end

  def debug_incoming(command)
    irc_debug_log << "=> #{command.strip}"
  end

  def irc_debug_log
    @irc_debug_log ||= []
  end

  def emit_debug_log
    return unless irc_debug_log.any?
    puts ("IRC Log:\n#{irc_debug_log.join("\n")}")
  end

  def irc
    @irc ||= begin
      socket = TCPSocket.open(data['server'], port)
      socket = new_ssl_wrapper(socket) if use_ssl?
      socket
    end
  end

  alias readable_irc irc
  alias writable_irc irc

  def new_ssl_wrapper(socket)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
    ssl_socket.sync_close = true
    ssl_socket.connect
    ssl_socket
  end

  def use_ssl?
    config_boolean_true?('ssl')
  end

  def default_port
    use_ssl? ? 6697 : 6667
  end

  def port
    data['port'].to_i > 0 ? data['port'].to_i : default_port
  end

  def url
    config_boolean_true?('long_url') ? summary_url : shorten_url(summary_url)
  end
  
    # Boolean fields as either nil, "0", or "1".
  def config_boolean_true?(boolean_field)
    data[boolean_field].to_i == 1
  end
  
  def raise_config_error(msg = "Invalid configuration")
    #TODO: learn ruby and implement better
    puts msg
  end

    # overridden in Hookshot for proper UTF-8 transcoding with CharlockHolmes
  def clean_string_for_json(str)
    str.to_s.force_encoding(UTF8)
  end
  UTF8 = "UTF-8".freeze
end


b = IRC.new
b.data = Hash.new
b.data['server'] = 'kornbluth.freenode.net'
#b.data['port'] = 6697
b.data['use_ssl'] = false
b.data['room'] = '#freifunktrier-robots'
b.data['nick'] = 'my-commitcheck'
b.data['message_without_join'] = 1
b.send_messages(ARGF)
