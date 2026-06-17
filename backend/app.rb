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
  html = File.read("#{VIEWS}/index.html")
  empleado_nombre = session[:usuario].to_s

  if session[:impersonando]
    row = Database.execute_sp(:sp_listar_empleado, { FiltroNombre: nil })
                  .find { |emp| emp['Id'].to_i == session[:impersonando].to_i }
    empleado_nombre = row['NombreEmpleado'] || row['Nombre'] if row
  end

  volver_admin = if session[:impersonando]
    '<button class="btn-sm btn-outline" type="button" hx-post="/admin/volver">Volver al admin</button>'
  else
    ''
  end

  html.gsub('{{empleado_nombre}}', Rack::Utils.escape_html(empleado_nombre.to_s))
      .gsub('{{volver_admin}}', volver_admin)
end


# === AGREGA ESTA NUEVA RUTA AQUÍ ===
get '/admin/empleados' do
  require_login
  no_cache
  File.read("#{VIEWS}/admin_empleados.html")
end


# Modelos
require_relative 'models/empleado'
# Controladores
require_relative 'controllers/sesion_controller'
require_relative 'controllers/empleados_controller'
