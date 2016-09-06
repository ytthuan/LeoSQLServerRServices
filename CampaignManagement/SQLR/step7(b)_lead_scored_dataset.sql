DROP TABLE IF EXISTS lead_scored_dataset;

select * into lead_scored_dataset
from (
	select  tl.Lead_Id AS [Lead ID],
			tl.Age,
			tl.Annual_Income AS [Annual Income],
			tl.Credit_Score,
			tl.Product,
			tl.Campaign_Name AS [Campaign Name],
			tl.Recommended_Channel AS Channel,
			tl.Recommended_Day_Of_Week AS [Day of Week],
			tl.Recommended_Time_Of_Day AS [Time of Day],
			tl.Probability AS [Conv Probability],
			tl.conversion_flag AS Converts,
			tl.Model_name,
			td.[State]
	from lead_demography as td
	join lead_list as tl
	on td.Lead_Id = tl.Lead_Id
	) a
;

CREATE CLUSTERED COLUMNSTORE INDEX [lead_scored_dataset_cci] ON [lead_scored_dataset] WITH (DROP_EXISTING = OFF);