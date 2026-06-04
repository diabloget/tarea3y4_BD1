USE PlanillaObrera;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_login
  @inUsername    VARCHAR(100)
, @inPassword    VARCHAR(256)
, @inIP          VARCHAR(45)
, @outResultCode INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @vIdUsuario INT;
  DECLARE @vIntentos  INT;
  DECLARE @vDescripcion VARCHAR(MAX);

  -- Zona 1: verificar si el usuario existe
  SELECT @vIdUsuario = U.Id
  FROM   dbo.Usuario U
  WHERE  (U.Username = @inUsername);

  IF (@vIdUsuario IS NULL)
  BEGIN
    SET @outResultCode = 50001;
    -- No registramos en bitácora porque no tenemos IdUsuario válido
    -- y la FK lo impediría. Se retorna solo el código de error.
    RETURN;
  END

  -- Verificar bloqueo por intentos fallidos (últimos 20 minutos)
  SELECT @vIntentos = COUNT(*)
  FROM   dbo.BitacoraEvento BE
  WHERE  (BE.IdUsuario    = @vIdUsuario)
  AND    (BE.IdTipoEvento = 2)
  AND    (BE.FechaHora   >= DATEADD(MINUTE, -20, GETDATE()));

  IF (@vIntentos >= 5)
  BEGIN
    SET @outResultCode = 50003;
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
    VALUES (3, @vIdUsuario, @inIP, NULL);
    RETURN;
  END

  -- Verificar contraseña (columna PasswordHash según schema)
  IF NOT EXISTS (
    SELECT 1 FROM dbo.Usuario U
    WHERE  (U.Id = @vIdUsuario)
    AND    (U.PasswordHash = @inPassword)
  )
  BEGIN
    SET @outResultCode = 50002;
    SET @vIntentos    = @vIntentos + 1;
    SET @vDescripcion = 'Intento ' + CAST(@vIntentos AS VARCHAR) + ' en los últimos 20 minutos.';
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
    VALUES (2, @vIdUsuario, @inIP, @vDescripcion);
    RETURN;
  END

  -- Login exitoso
  SET @outResultCode = 0;

  INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdUsuario, IP, Descripcion)
  VALUES (1, @vIdUsuario, @inIP, 'Exitoso');

  SELECT U.Id
       , U.Username
       , U.Tipo
  FROM   dbo.Usuario U
  WHERE  (U.Id = @vIdUsuario);
END;
GO
