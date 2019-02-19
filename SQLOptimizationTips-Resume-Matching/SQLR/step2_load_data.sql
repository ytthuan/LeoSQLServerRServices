USE ResumeMatching
GO

INSERT INTO [dbo].[Projects]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Job_Features.csv"), h=T, sep=",")'


INSERT INTO [dbo].[Resumes]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Resume_Features.csv"), h=T, sep=",")'


INSERT INTO [dbo].[LabeledData]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Labled_Data.csv"), h=T, sep=",")'