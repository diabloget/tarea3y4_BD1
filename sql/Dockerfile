FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

WORKDIR /db-init

COPY schema.sql                                       ./schema.sql
COPY stored_procedures/sp_carga_xml.sql               ./sp_carga_xml.sql
COPY stored_procedures/sp_login.sql                   ./sp_login.sql
COPY stored_procedures/sp_logout.sql                  ./sp_logout.sql
COPY stored_procedures/sp_listar_empleados.sql        ./sp_listar_empleados.sql
COPY stored_procedures/sp_listar_puestos.sql          ./sp_listar_puestos.sql
COPY stored_procedures/sp_insertar_empleado.sql       ./sp_insertar_empleado.sql
COPY stored_procedures/sp_consultar_empleado.sql      ./sp_consultar_empleado.sql
COPY stored_procedures/sp_borrar_empleado.sql         ./sp_borrar_empleado.sql
COPY stored_procedures/sp_intento_borrado.sql         ./sp_intento_borrado.sql
COPY stored_procedures/sp_actualizar_empleado.sql     ./sp_actualizar_empleado.sql
COPY stored_procedures/sp_listar_movimientos.sql      ./sp_listar_movimientos.sql
COPY stored_procedures/sp_listar_tipos_movimiento.sql ./sp_listar_tipos_movimiento.sql
COPY stored_procedures/sp_insertar_movimiento.sql     ./sp_insertar_movimiento.sql
COPY stored_procedures/sp_obtener_error.sql           ./sp_obtener_error.sql
COPY entrypoint.sh                                    ./entrypoint.sh

RUN dos2unix entrypoint.sh schema.sql \
    sp_carga_xml.sql sp_login.sql sp_logout.sql \
    sp_listar_empleados.sql sp_listar_puestos.sql \
    sp_insertar_empleado.sql sp_consultar_empleado.sql \
    sp_borrar_empleado.sql sp_intento_borrado.sql sp_actualizar_empleado.sql \
    sp_listar_movimientos.sql sp_listar_tipos_movimiento.sql sp_insertar_movimiento.sql \
    sp_obtener_error.sql \
    && chmod +x entrypoint.sh \
    && chmod 644 schema.sql \
    sp_carga_xml.sql sp_login.sql sp_logout.sql \
    sp_listar_empleados.sql sp_listar_puestos.sql \
    sp_insertar_empleado.sql sp_consultar_empleado.sql \
    sp_borrar_empleado.sql sp_intento_borrado.sql sp_actualizar_empleado.sql \
    sp_listar_movimientos.sql sp_listar_tipos_movimiento.sql sp_insertar_movimiento.sql \
    sp_obtener_error.sql

USER mssql

ENTRYPOINT ["/db-init/entrypoint.sh"]