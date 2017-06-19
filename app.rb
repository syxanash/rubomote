require 'sinatra'
require 'sinatra-websocket'
require 'itunes-client'
require 'base64'
require 'socket'
require 'json'

require './lib/rubomote_helpers'
require './lib/lyrics_finder'

include Itunes

PIN_LENGTH = 1
GENIUS_TOKEN = 'Na70o4NBjPTMcyaKnky4qEFhtEYJ7VtiM4trkQtQu5Db9Zd-K3o4ex8m3LqN-jsw'.freeze

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

helpers RubomoteHelpers

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
        # transfer object which will be sent to the client via websocket
        message = {}

        # when clients connect to the websocket server send
        # artist, track name and volume value

        settings.sockets << conn

        EM.next_tick {
          if @player.playing?
            message[:current_track] = track_info
          end

          message[:volume_value] = @volume_control.value

          conn[:socket].send(message.to_json.to_s)
        }
      end

      ws.onmessage do |client_msg|
        EM.next_tick {
          message = {}

          response = client_msg

          # if the message sent by the client contains the word volume, parse it
          # and dynamically execute the methods "up" or "down" of the class which
          # controls the volume
          if client_msg.include? 'volume'
            client_msg.slice! 'volume_'

            @volume_control.send(client_msg)

            message[:volume_value] = @volume_control.value
          elsif client_msg.include? 'player'
            client_msg.slice! 'player_'
            # dynamically execute method of the class which controls
            # the player and if the player is currently playing a track
            # send it to the client

            @player.send(client_msg)

            if @player.playing?
              message[:current_track] = track_info
            else
              message[:playing] = false
            end
          elsif client_msg.include? 'lyrics'
            message[:lyrics] = track_lyrics
          end

          # if client needs status of the player send track name and volume vlaue
          # only to that specific client, otherwise send response to all clients
          if client_msg == 'status'
            if @player.playing?
              message[:current_track] = track_info
            end

            message[:volume_value] = @volume_control.value
            message[:playing] = @player.playing?

            conn[:socket].send(message.to_json.to_s)
          elsif client_msg.include? 'lyrics'
            message[:lyrics] = track_lyrics

            # send lyrics only to the client who made request
            conn[:socket].send(message.to_json.to_s)
          else
            settings.sockets.each do |user|
              user[:socket].send(message.to_json.to_s)
            end
          end
        }
      end

      ws.onclose do
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
