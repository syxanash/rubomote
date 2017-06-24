require 'sinatra'
require 'sinatra-websocket'
require 'itunes-client'
require 'base64'
require 'socket'
require 'json'

require './lib/rubomote_helpers'
require './lib/lyrics_finder'

include Itunes

CONFIG_FILE = 'rubomote_config.json'.freeze

def generate_pin(length, user_port)
  secret_pin = ''
  socket_ip = Socket.ip_address_list.detect{ |intf| intf.ipv4_private? }
  host_port = ''

  if socket_ip.nil?
    abort('Server won\'t be reached by any device, connect server to WiFi or Ethernet!')
  end

  length.times { secret_pin += Random.rand(10).to_s }

  host_port = ":#{user_port}" unless user_port == 80

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

  # get content of rubomote configuration file
  begin
    rconfig = File.read(CONFIG_FILE)
    rconfig = JSON.parse(rconfig)
  rescue Errno::ENOENT
    abort('Can\'t read Rubomote config file!')
  end

  # if user executing the script is root then use port 80 otherwise the one
  # set in configuration file
  server_port = Process.uid == 0 ? 80 : rconfig['server_port']

  set :pin_length, rconfig['pin_length']
  set :genius_token, rconfig['genius_token']
  set :port, server_port
  set :bind, '0.0.0.0'
  set :sockets, []
  set :session_secret, generate_pin(rconfig['pin_length'], server_port)
  set :show_exceptions, false
end

# before executing any routes create two instances of itunes-client and lyrics finder
before do
  @volume_control = Itunes::Volume
  @player = Itunes::Player

  @lyrics_finder = LyricsFinder.new(settings.genius_token)

  # for any routes except /login and /errors/* authentication is required
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
        EM.defer {
          send_to_all = false
          server_reply = {}
          client_request = ''

          # check if client request is valid JSON
          begin
            client_request = JSON.parse(client_msg)
          rescue JSON::ParserError
            conn[:socket].send({ 'error' => 'Invalid JSON sent from client' }.to_json.to_s)
            next
          end

          # checking client requests

          if client_request['status']
            if @player.playing?
              server_reply[:current_track] = track_info
            end

            server_reply[:volume_value] = @volume_control.value
            server_reply[:playing] = @player.playing?
          end

          unless client_request['volume'].nil?
            # if the server_reply sent by the client contains the word volume, parse it
            # and dynamically execute the methods "up" or "down" of the class which
            # controls the volume
            @volume_control.send(client_request['volume'])

            server_reply[:volume_value] = @volume_control.value

            send_to_all = true
          end

          unless client_request['controls'].nil?
            # dynamically execute method of the class which controls
            # the player and if the player is currently playing a track
            # send it to the client
            @player.send(client_request['controls'])

            if @player.playing?
              server_reply[:current_track] = track_info
            else
              server_reply[:playing] = false
            end

            send_to_all = true
          end

          if client_request['lyrics']
            server_reply[:lyrics] = track_lyrics
          end

          if send_to_all
            # send the server reply to all clients connected to
            # websocket server
            settings.sockets.each do |user|
              user[:socket].send(server_reply.to_json.to_s)
            end
          else
            conn[:socket].send(server_reply.to_json.to_s)
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
