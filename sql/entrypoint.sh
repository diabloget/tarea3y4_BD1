#!/bin/bash
/opt/mssql/bin/sqlservr &
SQL_PID=$!

echo "Esperando a que SQL Server esté listo..."
for i in {1..30}; do
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "SQL Server listo. Ejecutando scripts..."
    break
  fi
  echo "Intento $i/30, esperando 2s..."
  sleep 2
done

# Aqui se ponen los archivos sp y demas
for script in schema.sql sp_login.sql sp_logout.sql sp_obtener_error.sql; do
  if [ -f "/db-init/$script" ]; then
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /db-init/$script
    echo "$script ejecutado."
  else
    echo "Advertencia: No se encontró el archivo /db-init/$script"
  fi
done

echo "Base de datos lista."
wait $SQL_PID
