class Empleado
  attr_accessor :id, :valor_doc, :nombre, :puesto

  def initialize(attributes = {})
    @id        = attributes[:id]
    @valor_doc = attributes[:valor_doc]
    @nombre    = attributes[:nombre]
    @puesto    = attributes[:puesto]
  end

  def self.listar(filtro = nil)
    # Usamos execute_sp (sin salida)
    rows = Database.execute_sp(:sp_listar_empleado, { FiltroNombre: filtro })

    rows.map do |row|
      Empleado.new(
        id:        row['Id'],
        valor_doc: row['ValorDocumento'],
        nombre:    row['NombreEmpleado'] || row['Nombre'],
        puesto:    row['Puesto']
      )
    end
  end

  def self.procesar_xml(xml_string)
    result = Database.execute_xml_sp(:sp_procesar_operaciones_xml, xml_string)
    result['Resultado'].to_i
  end

  def self.procesar_datos_xml(xml_string)
    result = Database.execute_xml_sp(:sp_cargar_datos_xml, xml_string)
    result['Resultado'].to_i
  end
end
