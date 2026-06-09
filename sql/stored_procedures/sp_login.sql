USE PlanillaObrera;
GO

IF OBJECT_ID('dbo.sp_login', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_login;
GO

CREATE PROCEDURE dbo.sp_login
    @inUsername    VARCHAR(64),
    @inPassword    VARCHAR(128),
    @inIP          VARCHAR(45),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vIdUsuario INT;
    DECLARE @vIntentos  INT;
    DECLARE @vDescripcion VARCHAR(MAX);

    SELECT @vIdUsuario = Id
    FROM dbo.Usuario
    WHERE Username = @inUsername;

    IF (@vIdUsuario IS NULL)
    BEGIN
        SET @outResultCode = 50001; -- Usuario no existe
        RETURN;
    END

    -- 2. Verificar intentos fallidos (últimos 20 min)
    SELECT @vIntentos = COUNT(*)
    FROM dbo.BitacoraEvento
    WHERE IdUsuario = @vIdUsuario
      AND IdTipoEvento = 2
      AND FechaHora >= DATEADD(MINUTE, -20, GETDATE());

    IF (@vIntentos >= 5)
    BEGIN
        SET @outResultCode = 50003; -- Login deshabilitado
        INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
        VALUES (3, @vIdUsuario, @inIP, 'Bloqueo por intentos fallidos');
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Id = @vIdUsuario AND PasswordHash = @inPassword)
    BEGIN
        SET @outResultCode = 50002; -- Contraseña incorrecta
        SET @vIntentos = @vIntentos + 1;
        SET @vDescripcion = 'Intento fallido #' + CAST(@vIntentos AS VARCHAR);

        INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
        VALUES (2, @vIdUsuario, @inIP, @vDescripcion);
        RETURN;
    END

    SET @outResultCode = 0;
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
    VALUES (1, @vIdUsuario, @inIP, 'Login exitoso');

    SELECT Id, Username, Tipo FROM dbo.Usuario WHERE Id = @vIdUsuario;
END;
GO
