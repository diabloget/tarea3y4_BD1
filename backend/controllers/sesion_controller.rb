require_relative '../models/usuario'

post '/login' do
  username = params[:username].to_s.strip
  password = params[:password].to_s.strip

  if username.empty? || password.empty?
    session[:login_error] = 'Usuario y contraseña son requeridos.'
    redirect '/login'
  end

  begin
    resultado = Usuario.login(username: username, password: password, ip: request.ip)
    codigo    = resultado[:codigo]
    usuario   = resultado[:usuario]

    if codigo == 0 && usuario
      session[:usuario]      = usuario['Username']
      session[:usuario_id]   = usuario['Id']
      session[:login_error]  = nil
      redirect '/'
    elsif codigo == 50003
      session[:login_error] = 'Demasiados intentos fallidos. Esperá 10 minutos.'
      redirect '/login'
    else
      session[:login_error] = codigo == 50001 ? 'El usuario no existe.' : 'Contraseña incorrecta.'
      redirect '/login'
    end
  rescue => e
    puts "ERROR login: #{e.message}"
    session[:login_error] = 'Posible error en la base de datos.'
    redirect '/login'
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