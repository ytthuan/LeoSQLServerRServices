USE [DefaultDBName]
GO

DELETE FROM [PM_Models]
WHERE model_name = 'binaryclass_rf'

insert into [PM_Models] (model)
exec train_binaryclass_rf;

UPDATE [PM_models] set model_name = 'binaryclass_rf' 
where model_name = 'default model'

DELETE FROM [PM_Models]
WHERE model_name = 'binaryclass_btree'

insert into [PM_Models] (model)
exec train_binaryclass_btree;

UPDATE [PM_models] set model_name = 'binaryclass_btree' 
where model_name = 'default model'

DELETE FROM [PM_Models]
WHERE model_name = 'binaryclass_logit'

insert into [PM_Models] (model)
exec train_binaryclass_logit;

UPDATE [PM_models] set model_name = 'binaryclass_logit' 
where model_name = 'default model'

DELETE FROM [PM_Models]
WHERE model_name = 'binaryclass_nn'

insert into [PM_Models] (model)
exec train_binaryclass_nn;

UPDATE [PM_models] set model_name = 'binaryclass_nn' 
where model_name = 'default model'
