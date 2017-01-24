-- =============================================
-- Description:	Table used for storing trained models. 
-- =============================================

CREATE TABLE [dbo].[GalaxiesModels](
	[CreationDate] [datetime] NULL,
	[Model] [varbinary](max) NOT NULL,
	[Name] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

-- =============================================
-- Description:	Table used for scoring. Data to score is inserted as path to the Galaxy image and NULL for the Predicted Label.
-- =============================================

CREATE TABLE [dbo].[GalaxiesToScore](
	[path] [char](300) NULL,
	[PredictedLabel] [char](100) NULL
) ON [PRIMARY]

GO

