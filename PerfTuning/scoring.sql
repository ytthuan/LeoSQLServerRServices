-- Before running script, the model needs to be stored in the database. Run SaveLMModel test using runtests.R
-- Also, the table airlineWithIndex should exist with 10 M rows of data.
-- This code uses trivial parallelism to speed up prediction of 1M rows.
use PerfTuning;
declare @just_model varbinary(max);
select @just_model = [value] from [rdata] where [key] = 'lm.model.1';
declare @pred float;
exec sp_execute_external_script
   @language = N'R',
   @script = N'
         # Prepare the data for single row scoring
         InputDataSet[,"DayOfWeek"] <- factor(InputDataSet[,"DayOfWeek"], levels=as.character(1:7))

         mm <- unserialize(as.raw(model_param))

         # Predict
         OutputDataSet <- data.frame(pred=predict(mm, InputDataSet))
   ',
   @input_data_1 = N'SELECT [ArrDelay],[DayOfWeek], [CRSDepTime] FROM airlineWithIndex WHERE rowNum > 9000000',
   @parallel = 1,
   @params = N'@model_param varbinary(max)',
   @model_param = @just_model
with result sets ((pred float));