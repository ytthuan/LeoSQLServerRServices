-- =============================================
-- Description:	Trigger to invoke prediction of Galaxy's class.
-- =============================================
CREATE TRIGGER [dbo].[T_InsertGalaxiesToScore] ON [dbo].[GalaxiesToScore]
	AFTER INSERT
AS 

BEGIN
   EXEC [dbo].[PredictGalaxiesNN]
		@ModelName = N'prod'  
END