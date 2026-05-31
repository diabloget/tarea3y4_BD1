# Controlador base limpio para la administración de empleados (Tarea 3)
get '/admin/empleados' do
  require_login
  no_cache

  # Usando el molde vacio del modelo
  @empleados = Empleado.todos

  # Posible vista de la tarea para esta parte de aca
  html = File.read("#{VIEWS}/admin_empleados.html")
  html
end
