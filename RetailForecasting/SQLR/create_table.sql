DROP TABLE IF EXISTS forecastinginput
GO

create table forecastinginput
(
	ID1 INT,
	ID2 INT,
	time VARCHAR(50),
	value INT
)
CREATE CLUSTERED COLUMNSTORE INDEX [forecastinginput_cci] ON forecastinginput WITH (DROP_EXISTING = OFF)

DROP TABLE IF EXISTS forecasting_personal_income
GO

create table forecasting_personal_income
(
	time VARCHAR(50),
	value FLOAT
)
CREATE CLUSTERED COLUMNSTORE INDEX [forecasting_personal_income_cci] ON forecasting_personal_income WITH (DROP_EXISTING = OFF)

DROP TABLE IF EXISTS RetailForecasting_models_btree
GO

CREATE table RetailForecasting_models_btree
(
	model varbinary(max) not null
)

DROP TABLE IF EXISTS RetailForecasting_models_rf
GO

CREATE table RetailForecasting_models_rf
(
	model varbinary(max) not null
)