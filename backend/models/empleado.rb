class Empleado
  attr_accessor :id, :tipo_doc, :valor_doc, :nombre, :fecha_contratacion, :puesto, :departamento, :activo

  def initialize(attributes = {})
    @id = attributes[:id]
    @tipo_doc = attributes[:tipo_doc]
    @valor_doc = attributes[:valor_doc]
    @nombre = attributes[:nombre]
    @fecha_contratacion = attributes[:fecha_contratacion]
    @puesto = attributes[:puesto]
    @departamento = attributes[:departamento]
    @activo = attributes[:activo]
  end

  # Molde vacío: se implementa una vez haya un dbo.sp_listar_empleados en la base de datos
  def self.todos
    []
  end
end
