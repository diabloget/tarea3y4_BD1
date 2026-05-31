require_relative '../config/database'

class ErrorCatalogo
  def self.descripcion(codigo)
    Database.query do |db|
      sql = "DECLARE @outResultCode INT; " \
            "EXEC dbo.sp_obtener_error @inCodigo = #{codigo.to_i}, @outResultCode = @outResultCode OUTPUT;"
      resultado = db.execute(sql).first
      resultado ? resultado['Descripcion'] : "Error desconocido (código #{codigo})"
    end
  rescue
    "Error desconocido (código #{codigo})"
  end
end