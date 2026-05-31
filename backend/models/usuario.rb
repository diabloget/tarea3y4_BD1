require_relative '../config/database'

class Usuario
  def self.login(username:, password:, ip:)
    Database.query do |db|
      sql = "DECLARE @outResultCode INT; " \
            "EXEC dbo.sp_login " \
            "  @inUsername    = N'#{username.gsub("'","''")}', " \
            "  @inPassword    = N'#{password.gsub("'","''")}', " \
            "  @inIP          = N'#{ip}', " \
            "  @outResultCode = @outResultCode OUTPUT; " \
            "SELECT @outResultCode AS Codigo;"

      codigo  = nil
      usuario = nil
      result  = db.execute(sql)
      # Aqui el StoreProcedure deberia de devolver el SELECT de usuarios y un output
      # Entonces es nada mas iterar hasta que se encuentre el que tiene codigo
      result.each(as: :hash) do |fila|
        if fila.key?('Codigo')
          codigo = fila['Codigo'].to_i
        elsif fila.key?('Id')
          usuario = fila
        end
      end
      { codigo: codigo, usuario: usuario }
    end
  end

  def self.logout(id_usuario:, ip:)
    Database.query do |db|
      db.execute(
        "DECLARE @outResultCode INT; " \
        "EXEC dbo.sp_logout " \
        "  @inIdUsuario   = #{id_usuario.to_i}, " \
        "  @inIP          = N'#{ip}', " \
        "  @outResultCode = @outResultCode OUTPUT;"
      ).do
    end
  end
end