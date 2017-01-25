set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS PredictChurnRx
GO

/* 
 Description: This file creates the procedure to predict churn outcome based on the Microsoft R model previously built.
*/
create procedure PredictChurnRx @inquery nvarchar(max)
as
begin
  declare @modelt varbinary(max) = (select top 1 model from ChurnModelRx);
  insert into ChurnPredictRx
  exec sp_execute_external_script @language = N'R',
                                  @script = N'
mod <- unserialize(as.raw(model));
print(summary(mod))
Scores <- rxPredict(modelObject = mod, data = InputDataSet, outData = NULL, 
                   predVarNames = "Score", type = "response", writeModelVars = FALSE, overwrite = TRUE);
Scores$TagId <- as.numeric(as.character(InputDataSet$TagId))
predictROC <- rxRoc(actualVarName = c("TagId"), predVarNames = c("Score"), data = Scores, numBreaks = 100)
Auc <- rxAuc(predictROC)
OutputDataSet <- data.frame(InputDataSet$UserId,InputDataSet$Tag,InputDataSet$TagId,Scores$Score,Auc)'
,@input_data_1 = @inquery
,@output_data_1_name = N'OutputDataSet'
,@params = N'@model varbinary(max)'
,@model = @modelt;
end
go

declare @query_string nvarchar(max)
set @query_string='
select F.*, Tags.Tag, Tags.TagId from
(select a.* from Features a
left outer join
(
select * from Features
tablesample (70 percent) repeatable (98052)
)b
on a.UserId=b.UserId
where b.UserId is null) F join Tags on F.UserId=Tags.UserId 
'
execute PredictChurnRx @inquery = @query_string;
go



