require_relative '../models/usuario'

post '/login' do
  username = params[:username].to_s.strip
  password = params[:password].to_s.strip

  # Si faltan datos, devolvemos el HTML del error directamente
  if username.empty? || password.empty?
    status 200
    return "<p class='login-error'>Usuario y contraseña son requeridos.</p>"
  end

  begin
    resultado = Usuario.login(username: username, password: password, ip: request.ip)
    codigo    = resultado[:codigo]
    usuario   = resultado[:usuario]

    if codigo == 0 && usuario
      # LOGIN EXITOSO
      session[:usuario]      = usuario['Username']
      session[:usuario_id]   = usuario['Id']
      session[:login_error]  = nil

      # Redirección especial para que HTMX cambie toda la página
      headers 'HX-Redirect' => '/'
      status 200
      body ""
    elsif codigo == 50003
      # BLOQUEO DE INTENTOS
      status 200
      "<p class='login-error'>Demasiados intentos fallidos. Esperá 10 minutos.</p>"
    else
      # CONTRASEÑA INCORRECTA O USUARIO NO EXISTE
      status 200
      mensaje = codigo == 50001 ? 'El usuario no existe.' : 'Contraseña incorrecta.'
      "<p class='login-error'>#{mensaje}</p>"
    end
  rescue => e
    puts "ERROR login: #{e.message}"
    status 200
    "<p class='login-error'>Posible error en la base de datos.</p>"
  end
end

post '/logout' do
  begin
    if session[:usuario_id]
      Usuario.logout(id_usuario: session[:usuario_id], ip: request.ip)
    end
  rescue => e
    puts "ERROR logout: #{e.message}"
  ensure
    session.clear
    redirect '/login'
  end
end
