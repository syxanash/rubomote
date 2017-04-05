require 'sinatra'
require 'itunes-client'

include Itunes

PIN_LENGTH = 5.freeze

def generate_pin
  secret_pin = String.new
  PIN_LENGTH.times { secret_pin += Random.rand(10).to_s }
  system("cowsay 'Your secret PIN: #{secret_pin}' | lolcat")

  secret_pin
end

helpers do
  def authenticate!
    if session[:pin] != settings.secret_pin
      redirect '/login'
    end
  end
end

configure do
  enable :sessions

  set :secret_pin, generate_pin
end

before do
  @volume_control = Itunes::Volume
  @player = Itunes::Player
end

get '/login' do
  erb :login
end

post '/login' do
  entered_pin = ''

  params.each do |key, value|
    entered_pin += value
  end

  if entered_pin == settings.secret_pin
    session[:pin] = entered_pin
    redirect '/'
  end
end

get '/' do
  authenticate!

  erb :index
end

get '/artist' do
  authenticate!

  if @player.playing?
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end

get '/volume' do
  authenticate!

  "#{@volume_control.value}"
end

get '/volume/:volume' do
  authenticate!

  volume = params[:volume]
  @volume_control.send(volume)

  "#{@volume_control.value}"
end

get '/action/:action' do
  authenticate!

  action = params[:action]
  @player.send(action)

  if @player.playing?
    "#{@player.current_track.name} - #{@player.current_track.artist}"
  end
end
