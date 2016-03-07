USE [DefaultDBName];
GO

exec test_regression_models 'regression_rf', 'regression_btree', 'regression_glm', 'regression_nn';
GO
