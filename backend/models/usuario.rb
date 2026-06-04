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

      db.execute(sql).each do |row|
        if row.key?('Codigo')
          codigo = row['Codigo'].to_i
        elsif row.key?('Id')
          usuario = row
        end
      end

      { codigo: codigo, usuario: usuario }
    end
  rescue => e
    puts "Error en Usuario.login: #{e.message}"
    { codigo: 50000, usuario: nil }
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
  rescue => e
    puts "Error en Usuario.logout: #{e.message}"
  end
end
