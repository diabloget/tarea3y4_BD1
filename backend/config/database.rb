require 'tiny_tds'

module Database
  # ─────────────────────────────────────────────────────────────
  # Conexión base. Activa los SET options obligatorios para XML
  # e índices en SQL Server (TinyTds no los activa por defecto).
  # ─────────────────────────────────────────────────────────────
  def self.conectar
    client = TinyTds::Client.new(
      host:     ENV.fetch('DB_HOST',     'mssql_db'),
      port:     1433,
      username: 'sa',
      password: ENV.fetch('DB_PASSWORD', 'Bd1tarea!'),
      database: 'PlanillaObrera',
      appname:  'PlanillaApp',
      timeout:  30
    )
    client.execute('SET QUOTED_IDENTIFIER       ON').do
    client.execute('SET ANSI_NULLS              ON').do
    client.execute('SET ANSI_WARNINGS           ON').do
    client.execute('SET ANSI_PADDING            ON').do
    client.execute('SET ANSI_NULL_DFLT_ON       ON').do
    client.execute('SET CONCAT_NULL_YIELDS_NULL ON').do
    client
  end

  # ─────────────────────────────────────────────────────────────
  # Abre una conexión, la pasa al bloque y la cierra al terminar.
  # Úsalo cuando necesites ejecutar SQL personalizado directamente
  # (como en Usuario.login / Usuario.logout).
  #
  # Ejemplo:
  #   Database.query do |db|
  #     db.execute("SELECT 1 AS uno").each { |r| puts r }
  #   end
  # ─────────────────────────────────────────────────────────────
  def self.query
    client = conectar
    begin
      yield client
    ensure
      client&.close
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Ejecuta un SP con parámetros simples.
  # Acepta el nombre del SP como String o Symbol.
  # Soporta parámetros OUTPUT: { output: true, type: 'INT' }
  #
  # Ejemplo:
  #   Database.execute_sp('sp_listar_empleado', FiltroNombre: 'Juan')
  # ─────────────────────────────────────────────────────────────
  def self.execute_sp(proc_name, params = {})
    proc_name = proc_name.to_s
    output_params = {}
    declare_lines = []
    param_list    = []

    params.each do |key, val|
      col = "@#{key}"
      if val.is_a?(Hash) && val[:output]
        sql_type = val[:type] || 'INT'
        declare_lines << "DECLARE #{col} #{sql_type};"
        param_list    << "#{col} = #{col} OUTPUT"
        output_params[key] = col
      else
        param_list << "#{col} = #{escape_value(val)}"
      end
    end

    declares   = declare_lines.join(' ')
    call_args  = param_list.join(', ')
    select_out = output_params.empty? ? '' :
                 "SELECT #{output_params.map { |k, v| "#{v} AS #{k}" }.join(', ')};"

    sql = "#{declares} EXEC dbo.#{proc_name} #{call_args}; #{select_out}".strip

    results = []
    query { |db| db.execute(sql).each { |row| results << row } }
    results
  end

  # ─────────────────────────────────────────────────────────────
  # Ejecuta un SP que recibe @XmlData XML y devuelve @OutRespuesta.
  # Acepta el nombre como String o Symbol.
  # Retorna el hash de la primera fila (contiene 'Resultado').
  #
  # Ejemplo:
  #   result = Database.execute_xml_sp('sp_cargar_datos_xml', xml_string)
  #   result['Resultado']  # => 0 si exitoso
  # ─────────────────────────────────────────────────────────────
  def self.execute_xml_sp(proc_name, xml_content)
    proc_name  = proc_name.to_s
    xml_seguro = limpiar_xml(xml_content).gsub("'", "''")

    sql = <<~SQL
      SET QUOTED_IDENTIFIER       ON;
      SET ANSI_NULLS              ON;
      SET ANSI_WARNINGS           ON;
      SET ANSI_PADDING            ON;
      SET CONCAT_NULL_YIELDS_NULL ON;
      DECLARE @Res INT;
      EXEC dbo.#{proc_name}
          @XmlData      = '#{xml_seguro}',
          @OutRespuesta = @Res OUTPUT;
      SELECT @Res AS Resultado;
    SQL

    results = []
    query { |db| db.execute(sql).each { |row| results << row } }
    results.first || { 'Resultado' => 50008 }
  end

  # ─────────────────────────────────────────────────────────────
  # Privados
  # ─────────────────────────────────────────────────────────────
  private_class_method def self.escape_value(val)
    case val
    when NilClass   then 'NULL'
    when Integer    then val.to_s
    when Float      then val.to_s
    when TrueClass  then '1'
    when FalseClass then '0'
    else "'#{val.to_s.gsub("'", "''")}'"
    end
  end

  private_class_method def self.limpiar_xml(raw)
    texto = raw.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    texto = texto.sub("\xEF\xBB\xBF", '')                       # quitar BOM
    texto = texto.sub(/<\?xml[^?]*\?>/mi, '').strip             # quitar <?xml ... ?>
    texto.gsub(/[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD]/u, '') # chars inválidos XML 1.0
  end
end
