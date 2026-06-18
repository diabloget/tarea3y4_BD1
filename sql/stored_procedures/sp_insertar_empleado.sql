USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_insertar_empleado', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_insertar_empleado;
END
GO

CREATE PROCEDURE dbo.sp_insertar_empleado
    @inValorDocumento VARCHAR(50)
    , @inNombre VARCHAR(100)
    , @inNombrePuesto VARCHAR(100)
    , @inCuentaBancaria VARCHAR(100)
    , @inFechaContratacion DATE
    , @inUsername VARCHAR(64) = NULL
    , @inPassword VARCHAR(128) = NULL
    , @outResultCode INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idPuesto INT;
    DECLARE @idDepartamento INT;
    DECLARE @idTipoDocumento INT;
    DECLARE @idUsuario INT;
    DECLARE @realUsername VARCHAR(64);
    DECLARE @realPassword VARCHAR(128);

    SET @outResultCode = 0;
    SET @realUsername = ISNULL(NULLIF(@inUsername, ''), @inValorDocumento);
    SET @realPassword = ISNULL(NULLIF(@inPassword, ''), @inValorDocumento);

    SELECT
        @idPuesto = P.Id
    FROM dbo.Puesto AS P
    WHERE (P.Nombre = @inNombrePuesto);

    SELECT TOP (1)
        @idDepartamento = D.Id
    FROM dbo.Departamento AS D
    ORDER BY
        D.Id ASC;

    SELECT TOP (1)
        @idTipoDocumento = TD.Id
    FROM dbo.TipoDocIdentidad AS TD
    ORDER BY
        TD.Id ASC;

    IF (EXISTS (
        SELECT
            1
        FROM dbo.Empleado AS E
        WHERE (E.ValorDocumento = @inValorDocumento)
    ))
    BEGIN
        SET @outResultCode = 50004;
        RETURN;
    END

    IF (EXISTS (
        SELECT
            1
        FROM dbo.Empleado AS E
        WHERE (E.Nombre = @inNombre)
    ))
    BEGIN
        SET @outResultCode = 50005;
        RETURN;
    END

    IF (
        @idPuesto IS NULL
        OR @idDepartamento IS NULL
        OR @idTipoDocumento IS NULL
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Usuario (
            Username
            , PasswordHash
            , Tipo
        )
        VALUES (
            @realUsername
            , @realPassword
            , 'empleado'
        );

        SET @idUsuario = SCOPE_IDENTITY();

        INSERT INTO dbo.Empleado (
            IdPuesto
            , IdDepartamento
            , IdTipoDocumento
            , IdUsuario
            , ValorDocumento
            , Nombre
            , CuentaBancaria
            , FechaContratacion
            , Activo
        )
        VALUES (
            @idPuesto
            , @idDepartamento
            , @idTipoDocumento
            , @idUsuario
            , @inValorDocumento
            , @inNombre
            , @inCuentaBancaria
            , @inFechaContratacion
            , 1
        );

        COMMIT TRANSACTION;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END

        INSERT INTO dbo.DBError (
            Mensaje
            , Severidad
            , Estado
        )
        VALUES (
            ERROR_MESSAGE()
            , ERROR_SEVERITY()
            , ERROR_STATE()
        );

        SET @outResultCode = 50008;
    END CATCH
END
GO
