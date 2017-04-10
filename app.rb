require 'sinatra'
require 'sinatra-websocket'
require 'itunes-client'

include Itunes

PIN_LENGTH = 1.freeze

def generate_pin
  secret_pin = ''
  PIN_LENGTH.times { secret_pin += Random.rand(10).to_s }
  system("cowsay 'Your secret PIN: #{secret_pin}' | lolcat")

  secret_pin
end

helpers do
  def authenticate!
    if !authenticated?
      redirect '/login'
    end
  end

  def authenticated?
    session[:pin] == settings.session_secret
  end
end

not_found do
  @error_msg = "404 not found!"
  erb :error
end

error do
  @error_msg = env['sinatra.error'].message
  erb :error
end

configure do
  enable :sessions

  set :sockets, []
  set :session_secret, generate_pin
  set :show_exceptions, false
end

# before executing any routes create two instances of itunes-client
before do
  @volume_control = Itunes::Volume
  @player = Itunes::Player
end

=begin
# for any routes except /login authentication is required
before %r{^(?!\/login)} do
  authenticate!
end
=end

# main routes

get '/login' do
  if authenticated?
    redirect '/'
  end

  erb :login
end

post '/login' do
  entered_pin = ''

  params.each do |key, value|
    entered_pin += value
  end

  if entered_pin == settings.session_secret
    session[:pin] = entered_pin
    redirect '/'
  end
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      @conn = {socket: ws}

      ws.onopen do
        warn("someone just connected")
        settings.sockets << @conn
        EM.next_tick {
          @conn[:socket].send("hello new user!".to_s)
        }
      end

      ws.onmessage do |msg|
        warn "message received by client is: #{msg}"

        if msg.include? "volume"
          actual_msg = ''

          if msg =~ %r{^volume_(.*?)$}
            actual_msg = $1
          end

          @volume_control.send(actual_msg)

          EM.next_tick {
            settings.sockets.each do |user|
              user[:socket].send(@volume_control.value.to_s)
            end
          }
        else
          @player.send(msg)

          EM.next_tick {
            settings.sockets.each do |user|
              if @player.playing?
                msg = "#{@player.current_track.name} - #{@player.current_track.artist}"
              end

              user[:socket].send(msg.to_s)
            end
          }
        end
      end

      ws.onclose do
        warn("websocket closed by a client!")
        settings.sockets.delete(ws)
      end
    end
  end
end

get '/volume' do
  "#{@volume_control.value}"
end

get '/artist' do
  if @player.playing?
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end

get '/volume/:volume' do
  volume = params[:volume]
  @volume_control.send(volume)

  "#{@volume_control.value}"
end

get '/action/:action' do
  action = params[:action]
  @player.send(action)

  if @player.playing?
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end
