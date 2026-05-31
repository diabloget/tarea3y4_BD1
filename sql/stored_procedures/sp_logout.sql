USE mi_db;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_logout
  @inIdUsuario   INT
, @inIP          VARCHAR(45)
, @outResultCode INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY
    SET @outResultCode = 0;

    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
    VALUES (4, NULL, @inIdUsuario, @inIP, GETDATE());
  END TRY
  BEGIN CATCH
    SET @outResultCode = ERROR_NUMBER() + 50000;
    INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message, DateTime)
    VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), GETDATE());
    THROW;
  END CATCH
END;
GO