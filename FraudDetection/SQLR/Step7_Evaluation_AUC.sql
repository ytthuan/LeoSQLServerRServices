set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS dbo.EvaluateR_auc
GO

create procedure dbo.EvaluateR_auc
as
begin

truncate table sql_performance_auc

insert into sql_performance_auc
exec sp_execute_external_script @language = N'R',
                                  @script = N'
 library(ROCR)
 scored_data <- InputDataSet
 pred <- prediction(scored_data$Score, scored_data$Label)
 auc = as.numeric(performance(pred,"auc")@y.values)
 OutputDataSet <- as.data.frame(auc)
',
  @input_data_1 = N' select * from sql_predict_score'
;
end
