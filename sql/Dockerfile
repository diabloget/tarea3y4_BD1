FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

WORKDIR /db-init

COPY schema.sql                       ./schema.sql
COPY stored_procedures/sp_login.sql                   ./sp_login.sql
COPY stored_procedures/sp_logout.sql                  ./sp_logout.sql
COPY stored_procedures/sp_listar_empleado.sql         ./sp_listar_empleado.sql
COPY stored_procedures/sp_insertar_empleado.sql       ./sp_insertar_empleado.sql
COPY stored_procedures/sp_eliminar_empleado.sql       ./sp_eliminar_empleado.sql
COPY stored_procedures/sp_desasociar_deduccion.sql    ./sp_desasociar_deduccion.sql
COPY stored_procedures/sp_obtener_error.sql           ./sp_obtener_error.sql
COPY stored_procedures/sp_procesar_operaciones_xml.sql ./sp_procesar_operaciones_xml.sql
COPY stored_procedures/sp_cargar_datos_xml.sql        ./sp_cargar_datos_xml.sql
COPY stored_procedures/sp_listar_planillas_semanales.sql ./sp_listar_planillas_semanales.sql
COPY stored_procedures/sp_consultar_planillas_semanales_empleado.sql ./sp_consultar_planillas_semanales_empleado.sql
COPY stored_procedures/sp_consultar_detalle_semana.sql ./sp_consultar_detalle_semana.sql
COPY stored_procedures/sp_consultar_planillas_mensuales_empleado.sql ./sp_consultar_planillas_mensuales_empleado.sql
COPY stored_procedures/sp_consultar_detalle_mes.sql ./sp_consultar_detalle_mes.sql
COPY entrypoint.sh                                    ./entrypoint.sh

RUN dos2unix entrypoint.sh schema.sql \
    sp_login.sql sp_logout.sql \
    sp_listar_empleado.sql \
    sp_insertar_empleado.sql \
    sp_eliminar_empleado.sql \
    sp_desasociar_deduccion.sql \
    sp_obtener_error.sql \
    sp_procesar_operaciones_xml.sql \
    sp_cargar_datos_xml.sql \
    sp_listar_planillas_semanales.sql \
    sp_consultar_planillas_semanales_empleado.sql \
    sp_consultar_detalle_semana.sql \
    sp_consultar_planillas_mensuales_empleado.sql \
    sp_consultar_detalle_mes.sql \
    && chmod +x entrypoint.sh \
    && chmod 644 schema.sql \
    sp_login.sql sp_logout.sql \
    sp_listar_empleado.sql \
    sp_insertar_empleado.sql \
    sp_eliminar_empleado.sql \
    sp_desasociar_deduccion.sql \
    sp_obtener_error.sql \
    sp_procesar_operaciones_xml.sql \
    sp_cargar_datos_xml.sql \
    sp_listar_planillas_semanales.sql \
    sp_consultar_planillas_semanales_empleado.sql \
    sp_consultar_detalle_semana.sql \
    sp_consultar_planillas_mensuales_empleado.sql \
    sp_consultar_detalle_mes.sql

ENTRYPOINT ["/db-init/entrypoint.sh"]
