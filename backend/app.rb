require 'sinatra'
require 'sinatra/reloader' if development?
require_relative 'config/database'
require_relative 'models/error_catalogo'

# Aqui se incluyen los models y controllers adaptados, ej:
# require_relative 'models/empleado'
# require_relative 'controllers/empleados_controller'

set :bind, '0.0.0.0'
set :port, 3000
set :public_folder, '/frontend'

VIEWS = '/frontend/views'

SESSION_SECRET = ENV.fetch('SESSION_SECRET',
  'LaContraseñaTieneQueExcederSesentayCuatroCaracteresParaSerQueRubyLaAcepte')

use Rack::Session::Cookie,
  key:          'planilla.session', # Modificado de tarea2 a planilla
  secret:       SESSION_SECRET,
  expire_after: 3600

def contar(tabla)
  Database.query do |db|
    db.execute("SELECT COUNT(*) AS c FROM dbo.#{tabla}").first.values.first.to_i
  end
end

def require_login
  redirect '/login' unless session[:usuario]
end

def no_cache
  headers 'Cache-Control' => 'no-store, no-cache, must-revalidate',
          'Pragma'         => 'no-cache',
          'Expires'        => '0'
end

# Rutas públicas base
get '/login' do
  no_cache
  redirect '/' if session[:usuario]
  error_msg = session.delete(:login_error)
  html = File.read("#{VIEWS}/login.html")
  error_msg ? html.sub('', "<div class='error'>#{error_msg}</div>") : html
end

# El resto del enrutamiento (ej. post '/login') va aca
