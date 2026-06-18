#!/bin/bash

(
  echo "Esperando a que SQL Server arranque para insertar datos..."
  for i in {1..30}; do
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "SQL Server listo. Ejecutando scripts..."
      break
    fi
    echo "Intento $i/30, esperando 2s..."
    sleep 2
  done

  for script in schema.sql sp_login.sql sp_logout.sql sp_obtener_error.sql sp_listar_empleado.sql sp_insertar_empleado.sql sp_eliminar_empleado.sql sp_desasociar_deduccion.sql sp_procesar_operaciones_xml.sql sp_cargar_datos_xml.sql sp_listar_planillas_semanales.sql sp_consultar_planillas_semanales_empleado.sql sp_consultar_detalle_semana.sql sp_consultar_planillas_mensuales_empleado.sql sp_consultar_detalle_mes.sql; do
    if [ -f "/db-init/$script" ]; then
      /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /db-init/$script
      echo "$script ejecutado."
    else
      echo "Advertencia: No se encontró el archivo /db-init/$script"
    fi
  done

  echo "================================================="
  echo " Base de datos y procedimientos listos para usar."
  echo "================================================="
) &

echo "Arrancando motor maestro de SQL Server..."
exec /opt/mssql/bin/sqlservr
