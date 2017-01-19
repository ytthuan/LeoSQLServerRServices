-- =============================================
-- Description:	Table used for scoring. Data to score is inserted as path to the Galaxy image and NULL for the Predicted Label.
-- =============================================

CREATE TABLE [dbo].[GalaxiesToScore](
	[path] [char](300) NULL,
	[PredictedLabel] [char](100) NULL
) ON [PRIMARY]

GO