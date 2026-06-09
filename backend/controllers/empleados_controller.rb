# Ruta principal para cargar la página de empleados
get '/admin/empleados' do
  require_login
  no_cache
  File.read("#{VIEWS}/admin_empleados.html")
end

# Ruta GET para filtrar y listar empleados para la tabla HTMX
get '/api/empleados' do
  filtro = params[:filtro]
  empleados = Empleado.listar(filtro)

  html = ""
  if empleados.empty?
    html += "<tr class='empty-row'><td colspan='3'>No se encontraron empleados.</td></tr>"
  else
    empleados.each do |emp|
      html += "<tr>"
      html += "<td>#{emp.valor_doc}</td>"
      html += "<td>#{emp.nombre}</td>"
      html += "<td>#{emp.puesto}</td>"
      html += "</tr>"
    end
  end
  html
end

# Ruta POST para cargar el catálogo base (Datos.xml)
post '/cargar-datos' do
  if params[:archivo_datos] && params[:archivo_datos][:tempfile]
    xml_content = params[:archivo_datos][:tempfile].read
    resultado = Empleado.procesar_datos_xml(xml_content)

    if resultado == 0
      "<span style='color: #2d5a4e; font-weight: bold;'>¡Catálogos base cargados exitosamente!</span>"
    else
      "<span style='color: #9b3a3a; font-weight: bold;'>Error cargando catálogos. (Código: #{resultado})</span>"
    end
  else
    "<span style='color: #9b3a3a;'>No se recibió ningún archivo válido.</span>"
  end
end

# Ruta de prueba para cargar XML
post '/cargar-xml' do
  if params[:archivo_xml] && params[:archivo_xml][:tempfile]
    xml_content = params[:archivo_xml][:tempfile].read
    resultado = Empleado.procesar_xml(xml_content)

    if resultado == 0
      "<span style='color: #2d5a4e; font-weight: bold;'>¡Simulación ejecutada exitosamente!</span>"
    else
      "<span style='color: #9b3a3a; font-weight: bold;'>Error procesando XML (Código: #{resultado}).</span>"
    end
  else
    "<span style='color: #9b3a3a;'>No se recibió ningún archivo válido.</span>"
  end
end
