helpers do
  def h(value)
    Rack::Utils.escape_html(value.to_s)
  end

  def money(value)
    "¢#{format('%.2f', value.to_f)}"
  end

  def truthy_db?(value)
    return value if value == true || value == false

    value.to_i == 1
  end

  def empleado_consulta_id
    (session[:impersonando] || session[:empleado_id] || session[:usuario_id]).to_i
  end

  def render_empty_row(colspan, message)
    "<tr class='empty-row'><td colspan='#{colspan}'>#{h(message)}</td></tr>"
  end

  def render_weekly_movements(movimientos)
    rows_html = if movimientos.empty?
      render_empty_row(6, 'No hay movimientos de asistencia para esta semana.')
    else
      movimientos.map do |m|
        "<tr>
          <td>#{h(m['Fecha'])}</td>
          <td>#{h(m['HoraEntrada'])}</td>
          <td>#{h(m['HoraSalida'])}</td>
          <td>#{h(m['TipoMovimiento'])}</td>
          <td class='text-center'>#{m['CantidadHoras'].to_f}</td>
          <td class='text-right'>#{money(m['Monto'])}</td>
        </tr>"
      end.join("\n")
    end

    "<div class='detail-panel'>
      <div class='detail-title'>Movimientos por dia</div>
      <div class='table-wrapper compact'>
        <table>
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Entrada</th>
              <th>Salida</th>
              <th>Movimiento</th>
              <th class='text-center'>Horas</th>
              <th class='text-right'>Monto</th>
            </tr>
          </thead>
          <tbody>#{rows_html}</tbody>
        </table>
      </div>
    </div>"
  end

  def render_weekly_deductions(deducciones)
    rows_html = if deducciones.empty?
      render_empty_row(4, 'No hay deducciones aplicadas para esta semana.')
    else
      deducciones.map do |d|
        es_porcentual = truthy_db?(d['EsPorcentual'])
        porcentaje = es_porcentual ? "#{format('%.4f', d['Porcentaje'].to_f)}%" : ''
        "<tr>
          <td>#{h(d['NombreDeduccion'])}</td>
          <td>#{es_porcentual ? 'Si' : 'No'}</td>
          <td class='text-right'>#{h(porcentaje)}</td>
          <td class='text-right'>#{money(d['MontoDeducido'])}</td>
        </tr>"
      end.join("\n")
    end

    "<div class='detail-panel'>
      <div class='detail-title'>Deducciones de la semana</div>
      <div class='table-wrapper compact'>
        <table>
          <thead>
            <tr>
              <th>Deduccion</th>
              <th>Porcentual</th>
              <th class='text-right'>Porcentaje</th>
              <th class='text-right'>Monto</th>
            </tr>
          </thead>
          <tbody>#{rows_html}</tbody>
        </table>
      </div>
    </div>"
  end

  def render_monthly_deductions(deducciones)
    rows_html = if deducciones.empty?
      render_empty_row(4, 'No hay deducciones registradas para este mes.')
    else
      deducciones.map do |d|
        es_porcentual = truthy_db?(d['EsPorcentual'])
        porcentaje = es_porcentual ? "#{format('%.4f', d['Porcentaje'].to_f)}%" : ''
        "<tr>
          <td>#{h(d['NombreDeduccion'])}</td>
          <td>#{es_porcentual ? 'Si' : 'No'}</td>
          <td class='text-right'>#{h(porcentaje)}</td>
          <td class='text-right'>#{money(d['MontoTotalMes'])}</td>
        </tr>"
      end.join("\n")
    end

    "<div class='detail-panel'>
      <div class='detail-title'>Deducciones del mes</div>
      <div class='table-wrapper compact'>
        <table>
          <thead>
            <tr>
              <th>Deduccion</th>
              <th>Porcentual</th>
              <th class='text-right'>Porcentaje</th>
              <th class='text-right'>Monto total</th>
            </tr>
          </thead>
          <tbody>#{rows_html}</tbody>
        </table>
      </div>
    </div>"
  end
end

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
      html += "<td>#{h(emp.valor_doc)}</td>"
      html += "<td>#{h(emp.nombre)}</td>"
      html += "<td>#{h(emp.puesto)}</td>"
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
    resultado = Database.execute_sp(:sp_listar_planillas_semanales)

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

get '/empleado/planillas' do
  require_login
  content_type :html

  planillas = Database.execute_sp(
    :sp_consultar_planillas_semanales_empleado,
    IdEmpleado: empleado_consulta_id
  )

  return render_empty_row(8, 'No hay planillas semanales.') if planillas.empty?

  planillas.map do |p|
    id_semana = p['IdSemana'] || p['IdPlanilla']
    "<tr>
      <td>#{h(p['FechaInicio'])}<br><small>#{h(p['FechaFin'])}</small></td>
      <td class='text-center'>#{p['HorasOrdinarias'].to_f}</td>
      <td class='text-center'>#{p['HorasExtraNormal'].to_f}</td>
      <td class='text-center'>#{p['HorasExtraDoble'].to_f}</td>
      <td class='text-right'>
        <button class='amount-link' hx-get='/empleado/planilla/#{id_semana}/detalle?tipo=movimientos' hx-target='#detalle-semana-#{id_semana}' hx-swap='innerHTML'>
          #{money(p['SalarioBruto'])}
        </button>
      </td>
      <td class='text-right'>
        <button class='amount-link debit' hx-get='/empleado/planilla/#{id_semana}/detalle?tipo=deducciones' hx-target='#detalle-semana-#{id_semana}' hx-swap='innerHTML'>
          #{money(p['TotalDeducciones'])}
        </button>
      </td>
      <td class='text-right strong'>#{money(p['SalarioNeto'])}</td>
    </tr>
    <tr class='detail-row'>
      <td colspan='7' id='detalle-semana-#{id_semana}'></td>
    </tr>"
  end.join("\n")
rescue => e
  "<tr><td colspan='7' style='color: red;'>ERROR: #{h(e.message)}</td></tr>"
end

get '/empleado/planilla/:id_semana/detalle' do
  require_login
  content_type :html

  rows = Database.execute_sp(
    :sp_consultar_detalle_semana,
    IdEmpleado: empleado_consulta_id,
    IdSemana: params[:id_semana].to_i
  )

  movimientos = rows.select { |row| row.key?('TipoMovimiento') }
  deducciones = rows.select { |row| row.key?('NombreDeduccion') }

  case params[:tipo].to_s
  when 'deducciones'
    render_weekly_deductions(deducciones)
  when 'movimientos'
    render_weekly_movements(movimientos)
  else
    "#{render_weekly_movements(movimientos)}#{render_weekly_deductions(deducciones)}"
  end
rescue => e
  "<div style='color: red;'>ERROR: #{h(e.message)}</div>"
end

get '/empleado/planillas-mensuales' do
  require_login
  content_type :html

  planillas = Database.execute_sp(
    :sp_consultar_planillas_mensuales_empleado,
    IdEmpleado: empleado_consulta_id
  )

  return render_empty_row(4, 'No hay planillas mensuales.') if planillas.empty?

  planillas.map do |p|
    "<tr>
      <td>#{h(p['FechaInicio'])}<br><small>#{h(p['FechaFin'])}</small></td>
      <td class='text-right'>#{money(p['SalarioBrutoMensual'])}</td>
      <td class='text-right'>
        <button class='amount-link debit' hx-get='/empleado/planilla-mensual/#{p['IdMes']}/detalle' hx-target='#detalle-mes-#{p['IdMes']}' hx-swap='innerHTML'>
          #{money(p['TotalDeduccionesMensual'])}
        </button>
      </td>
      <td class='text-right strong'>#{money(p['SalarioNetoMensual'])}</td>
    </tr>
    <tr class='detail-row'>
      <td colspan='4' id='detalle-mes-#{p['IdMes']}'></td>
    </tr>"
  end.join("\n")
rescue => e
  "<tr><td colspan='4' style='color: red;'>ERROR: #{h(e.message)}</td></tr>"
end

get '/empleado/planilla-mensual/:id_mes/detalle' do
  require_login
  content_type :html

  deducciones = Database.execute_sp(
    :sp_consultar_detalle_mes,
    IdEmpleado: empleado_consulta_id,
    IdMes: params[:id_mes].to_i
  )

  render_monthly_deductions(deducciones)
rescue => e
  "<div style='color: red;'>ERROR: #{h(e.message)}</div>"
end
