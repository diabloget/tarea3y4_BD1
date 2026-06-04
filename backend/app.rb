require 'sinatra'
require 'sinatra/reloader' if development?
require_relative 'config/database'

set :bind, '0.0.0.0'
set :port, 3000
set :public_folder, '/frontend'

VIEWS = '/frontend/views'

SESSION_SECRET = ENV.fetch('SESSION_SECRET', 'LaContraseñaTieneQueExcederSesentayCuatroCaracteresParaSerQueRubyLaAcepte')

use Rack::Session::Cookie,
  key:          'planilla.session',
  secret:       SESSION_SECRET,
  expire_after: 3600

def require_login
  redirect '/login' unless session[:usuario]
end

def no_cache
  headers 'Cache-Control' => 'no-store, no-cache, must-revalidate',
          'Pragma'         => 'no-cache',
          'Expires'        => '0'
end

# Rutas públicas
get '/login' do
  no_cache
  redirect '/' if session[:usuario]
  File.read("#{VIEWS}/login.html")
end

# Ruta protegida principal
get '/' do
  require_login
  no_cache
  File.read("#{VIEWS}/index.html")
end

# Controladores
require_relative 'controllers/sesion_controller'
