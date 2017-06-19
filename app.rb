require 'sinatra'
require 'sinatra-websocket'
require 'itunes-client'
require 'base64'
require 'socket'

require './lib/lyrics_finder'

include Itunes

PIN_LENGTH = 6
GENIUS_TOKEN = ''.freeze

def generate_pin
  secret_pin = ''
  socket_ip = Socket.ip_address_list.detect{ |intf| intf.ipv4_private? }
  host_port = ''

  if socket_ip.nil?
    abort('Server won\'t be reached by any device, connect server to WiFi or Ethernet!')
  end

  PIN_LENGTH.times { secret_pin += Random.rand(10).to_s }

  host_port = ":#{@server_port}" unless @server_port == 80

  system("cowsay 'Server hosted at: http://#{socket_ip.ip_address}#{host_port}\n Secret PIN: #{secret_pin}' | lolcat")

  secret_pin
end

helpers do
  def authenticate!
    redirect '/login' unless authenticated?
  end

  def authenticated?
    session[:pin] == settings.session_secret
  end

  def get_lyrics
    lyrics_text = 'lyrics_'

    if @player.stopped?
      lyrics_text += 'Press ▶️ to get the lyrics'
    else
      begin
        lyrics_text += @lyrics_finder.lyrics(@player.current_track.name, @player.current_track.artist)
      rescue LyricsNotFound
        lyrics_text += 'Nothing found'
      rescue Genius::AuthenticationError
        lyrics_text += 'Invalid Genius API token'
      end
    end

    lyrics_text
  end

  def track_info
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end

not_found do
  @error_msg = '404 not found!'
  erb :error
end

error do
  @error_msg = env['sinatra.error'].message
  erb :error
end

configure do
  enable :sessions

  # if user executing the script is root then use port 80 otherwise 4567
  @server_port = Process.uid == 0 ? 80 : 4567

  set :port, @server_port
  set :bind, '0.0.0.0'
  set :sockets, []
  set :session_secret, generate_pin
  set :show_exceptions, false
end

# before executing any routes create two instances of itunes-client and lyrics finder
before do
  @volume_control = Itunes::Volume
  @player = Itunes::Player

  @lyrics_finder = LyricsFinder.new(GENIUS_TOKEN)
end

# for any routes except /login and /errors/* authentication is required
before do
  if %r{^(?!\/login|\/errors\/.)} =~ request.path_info
    authenticate! unless request.websocket?
  end
end

# routes for login

get '/login' do
  if authenticated?
    redirect "/auth/#{Base64.urlsafe_encode64(session[:pin])}"
  end

  erb :login
end

post '/login' do
  entered_pin = ''

  # get POST parameters which contain PIN numbers
  params = request.POST

  params.each do |key, value|
    entered_pin += value
  end

  if entered_pin == settings.session_secret
    session[:pin] = entered_pin
    redirect "/auth/#{Base64.urlsafe_encode64(entered_pin)}"
  else
    redirect '/errors/wrongpin'
  end
end

# main routes

get '/' do
  redirect '/login'
end

get '/auth/:secretpin' do
  # check if secret pin from url is encoded in base 64
  begin
    actual_pin = Base64.urlsafe_decode64(params[:secretpin])
  rescue ArgumentError
    redirect '/errors/wrongformat'
  end

  if !request.websocket?
    # if pin in url is different from session pin redirect to login
    if actual_pin != session[:pin]
      redirect '/errors/authenticate'
    end

    erb :index
  else
    request.websocket do |ws|
      conn = { socket: ws }

      ws.onopen do
        #warn 'someone just connected'

        # when clients connect to the websocket server send
        # artist, track name and volume value

        settings.sockets << conn

        EM.next_tick {
          if @player.playing?
            conn[:socket].send(track_info.to_s)
          end

          conn[:socket].send(@volume_control.value.to_s)
        }
      end

      ws.onmessage do |msg|
        EM.next_tick {
          #warn "message received by client is: #{msg}"

          response = msg

          # if the message sent by the client contains the word volume, parse it
          # and dynamically execute the methods "up" or "down" of the class which
          # controls the volume
          if msg.include? 'volume'
            msg.slice! 'volume_'

            @volume_control.send(msg)

            response = @volume_control.value
          elsif msg.include? 'player'
            msg.slice! 'player_'
            # otherwise dynamically execute method of the class which controls
            # the player and if the player is currently playing a track
            # send it to the client

            @player.send(msg)

            # if the player is not playing a track the response will be
            # the string "pause"

            if @player.playing?
              response = track_info
            end
          elsif msg.include? 'lyrics'
            response = get_lyrics
          end

          # if client needs status of the player send track name and volume vlaue
          # only to that specific client, otherwise send response to all clients
          if response == 'status'

            if @player.playing?
              conn[:socket].send(track_info.to_s)
            else
              # if player is not playing a song then set to pause the client player
              conn[:socket].send('pause'.to_s)
            end

            conn[:socket].send(@volume_control.value.to_s)
          elsif msg.include? 'lyrics'
            # send lyrics only to the client who made request
            conn[:socket].send(response.to_s)
          else
            settings.sockets.each do |user|
              user[:socket].send(response.to_s)
            end
          end
        }
      end

      ws.onclose do
        #warn 'websocket closed by a client!'

        settings.sockets.delete(ws)
      end
    end
  end
end

# error routes

get '/errors/:msg' do
  error_messages = {
    'authenticate' => 'Authentication required!',
    'wrongpin' => 'Wrong PIN entered',
    'wrongformat' => 'Wrong Base64 format for secret PIN'
  }

  if error_messages.include? params[:msg]
    @error_msg = error_messages[params[:msg]]
  else
    @error_msg = 'Something went wrong :('
  end

  erb :error
end
