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

# Ruta para obtener el desglose de planillas semanales calculado
get '/admin/planillas' do
  content_type :html
  begin
    resultado = []
    Database.query do |db|
      db.execute("EXEC dbo.sp_listar_planillas_semanales").each do |row|
        resultado << row
      end
    end

    if resultado.empty?
      return "<tr class='empty-row'><td colspan='6'>No hay datos.</td></tr>"
    end

    # Tu lógica de renderizado...
    resultado.map do |p|
      "<tr>
        <td>#{p['EmpleadoNombre']}<br><small>Doc: #{p['EmpleadoDocumento']}</small></td>
        <td>Semana #{p['SemanaId']}<br><small>#{p['FechaInicio']} al #{p['FechaFin']}</small></td>
        <td class='text-center'>#{p['HorasOrdinarias'].to_i}</td>
        <td class='text-center'>#{p['HorasExtraNormal'].to_i}</td>
        <td class='text-center'>#{p['HorasExtraDoble'].to_i}</td>
        <td class='text-right'>¢#{sprintf('%.2f', p['SalarioBruto'].to_f)}</td>
      </tr>"
    end.join("\n")

  rescue => e
    "<tr><td colspan='6' style='color: red;'>ERROR: #{e.message}</td></tr>"
  end
end
