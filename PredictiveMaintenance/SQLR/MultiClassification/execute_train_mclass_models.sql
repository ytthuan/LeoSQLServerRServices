USE [DefaultDBName]
GO

DELETE  FROM [PM_Models]
WHERE model_name = 'multiclass_rf'

insert into [PM_Models] (model)
exec train_multiclass_rf;

UPDATE [PM_models] set model_name = 'multiclass_rf' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'multiclass_btree'

insert into [PM_Models] (model)
exec train_multiclass_btree;

UPDATE [PM_models] set model_name = 'multiclass_btree' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'multiclass_nn'

insert into [PM_Models] (model)
exec train_multiclass_nn;

UPDATE [PM_models] set model_name = 'multiclass_nn' 
where model_name = 'default model'

DELETE  FROM [PM_Models]
WHERE model_name = 'multiclass_mn'

insert into [PM_Models] (model)
exec train_multiclass_mn;

UPDATE [PM_models] set model_name = 'multiclass_mn' 
where model_name = 'default model'
