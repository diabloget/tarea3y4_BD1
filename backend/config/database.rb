require 'tiny_tds'

module Database
  def self.conectar
    TinyTds::Client.new(
      host:     ENV.fetch('DB_HOST', 'mssql_db'),
      port:     1433,
      username: 'sa',
      password: ENV.fetch('DB_PASSWORD', 'Bd1tarea!'),
      database: 'mi_db'
    )
  end

  def self.query
    db = conectar
    yield db
  ensure
    db&.close
  end
end