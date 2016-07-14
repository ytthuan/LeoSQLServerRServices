DROP TABLE IF EXISTS PM_Score
GO

create table PM_Score
(
	id INT,
	cycle INT,
	setting1 float,
	setting2 float,
	setting3 float,
	s1 float,
	s2 float,
	s3 float,
	s4 float,
	s5 float,
	s6 float,
	s7 float,
	s8 float,
	s9 float,
	s10 float,
	s11 float,
	s12 float,
	s13 float,
	s14 float,
	s15 float,
	s16 float,
	s17 float,
	s18 float,
	s19 float,
	s20 float,
	s21 float
	)
CREATE CLUSTERED COLUMNSTORE INDEX [pm_train_cci] ON PM_Score WITH (DROP_EXISTING = OFF)
