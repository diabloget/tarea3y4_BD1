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

for script in schema.sql sp_carga_xml.sql sp_login.sql sp_logout.sql \
              sp_listar_empleados.sql sp_listar_puestos.sql \
              sp_insertar_empleado.sql sp_consultar_empleado.sql \
              sp_borrar_empleado.sql sp_intento_borrado.sql sp_actualizar_empleado.sql \
              sp_listar_movimientos.sql sp_listar_tipos_movimiento.sql sp_insertar_movimiento.sql \
              sp_obtener_error.sql; do
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /db-init/$script
  echo "$script ejecutado."
done

echo "Base de datos lista."
wait $SQL_PID