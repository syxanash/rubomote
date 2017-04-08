require 'sinatra'
require 'itunes-client'

include Itunes

PIN_LENGTH = 5.freeze

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
  set :session_secret, generate_pin
  set :show_exceptions, false
end

# before executing any routes create two instances of itunes-client
before do
  @volume_control = Itunes::Volume
  @player = Itunes::Player
end

# for any routes except /login authentication is required
before %r{^(?!\/login)} do
  authenticate!
end

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
  erb :index
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
