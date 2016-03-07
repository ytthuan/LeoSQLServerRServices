USE [DefaultDBName];
GO

exec test_binaryclass_models 'binaryclass_rf', 'binaryclass_btree', 'binaryclass_logit', 'binaryclass_nn';
GO
