USE [DefaultDBName]
GO

DELETE  FROM [PM_Models]
WHERE model_name = 'regression_rf'

insert into [PM_models] (model)
exec train_regression_rf;

UPDATE [PM_models] set model_name = 'regression_rf' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'regression_btree'

insert into [PM_models] (model)
exec train_regression_btree;

UPDATE [PM_models] set model_name = 'regression_btree' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'regression_glm'

insert into [PM_models] (model)
exec train_regression_glm;

UPDATE [PM_models] set model_name = 'regression_glm' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'regression_nn'

insert into [PM_models] (model)
exec train_regression_nn;

UPDATE [PM_models] set model_name = 'regression_nn' 
where model_name = 'default model'
