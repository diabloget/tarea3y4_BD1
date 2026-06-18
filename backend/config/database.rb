require 'tiny_tds'

module Database
  # TinyTds no activa estos SET options y SQL Server los exige para XML.
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

  def self.query
    client = conectar
    begin
      yield client
    ensure
      client&.close
    end
  end

  # Soporta parametros OUTPUT: { output: true, type: 'INT' }.
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
      DECLARE @XmlData XML;
      BEGIN TRY
          SET @XmlData = CAST('#{xml_seguro}' AS XML);
          EXEC dbo.#{proc_name}
              @inXmlData      = @XmlData,
              @outResultCode  = @Res OUTPUT;
      END TRY
      BEGIN CATCH
          INSERT INTO dbo.DBError (
              Mensaje,
              Severidad,
              Estado
          )
          VALUES (
              ERROR_MESSAGE(),
              ERROR_SEVERITY(),
              ERROR_STATE()
          );
          SET @Res = 50008;
      END CATCH;
      SELECT @Res AS Resultado;
    SQL

    results = []
    query { |db| db.execute(sql).each { |row| results << row } }
    results.first || { 'Resultado' => 50008 }
  end

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
    texto = texto.sub("\xEF\xBB\xBF", '')
    texto = texto.sub(/<\?xml[^?]*\?>/mi, '').strip
    texto.gsub(/[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD]/u, '')
  end
end
