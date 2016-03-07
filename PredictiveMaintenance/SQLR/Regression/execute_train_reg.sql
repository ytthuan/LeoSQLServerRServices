USE [DefaultDBName];
GO

DELETE  FROM [DefaultDBName].[db_datareader].[PM_Models]
WHERE model_name = 'regression_nn'

insert into [DefaultDBName].[db_datareader].[PM_models] (model)
exec train_regression_nn;

UPDATE [DefaultDBName].[db_datareader].[PM_models] set model_name = 'regression_nn' 
where model_name = 'default model'
