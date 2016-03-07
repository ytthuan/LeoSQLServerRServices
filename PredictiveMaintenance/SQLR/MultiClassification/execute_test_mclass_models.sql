USE [DefaultDBName];
GO

exec test_multiclass_models 'multiclass_rf', 'multiclass_btree', 'multiclass_nn', 'multiclass_mn';
GO
