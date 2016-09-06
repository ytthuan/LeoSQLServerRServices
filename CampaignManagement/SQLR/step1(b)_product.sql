DROP TABLE IF EXISTS [Product]

CREATE  TABLE [Product]
(
Product_Id	int,
Product varchar(50),
Category varchar(50),
Term int,
No_Of_People_Covered int,
Premium	int,
Payment_Frequency varchar(50),
Net_Amt_Insured	int,
Amt_On_Maturity int,
Amt_On_Maturity_Bin	varchar(50)
)


CREATE CLUSTERED COLUMNSTORE INDEX [Product_cci] ON [Product] WITH (DROP_EXISTING = OFF)

INSERT INTO [Product]

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
############################################################ Creation of Product Table ###################################################

local <- RxLocalSeq()
rxSetComputeContext(local)

##########################################################################################################################################
##Creating product ids for various Product
##########################################################################################################################################

product_1 <- c(1:6)
product <- paste("P",product_1,sep="",collapse=NULL)

table_product <- data.frame(product_1)
table_product$product <- data.frame(product)

table_product$product <- ifelse(table_product$product == "P1","Protect Your Future",
                                ifelse(table_product$product == "P2","Live Free",
                                       ifelse(table_product$product == "P3","Secured Happiness",
                                              ifelse(table_product$product == "P4","Making Tomorrow Better",
                                                     ifelse(table_product$product == "P5","Secured Life",
                                                            ifelse(table_product$product == "P6","Live Happy","X"))))))

 

##########################################################################################################################################
 ##Assigning the various categories of product for each product id.
##########################################################################################################################################

table_product$category <- ifelse(table_product$product == "Protect Your Future","Long Term Care",
                                ifelse(table_product$product == "Live Free","Life",
                                       ifelse(table_product$product == "Secured Happiness","Health",
                                              ifelse(table_product$product == "Making Tomorrow Better","Disability",
                                                     ifelse(table_product$product == "Secured Life","Health",
                                                            ifelse(table_product$product == "Live Happy","Life","X"))))))



###########################################################################################################################################
##Assigning various product variables such as Term, No_of_people_covered, Premium, Payment_frequency, Net_Amt_Insured, Amt_on_Maturity,
###########################################################################################################################################

table_product$Term <- c(10,15,20,30,24,16)

table_product$No_of_people_covered <- c(4,2,1,4,2,5)

table_product$Premium <- c(1000,1500,2000,700,900,2000)

table_product$Payment_frequency <- c(rep("Monthly",3),rep("Quarterly",2),"Yearly")

table_product$Net_Amt_Insured <- c(100000,200000,150000,100000,200000,150000)

table_product$Amt_on_Maturity <- ifelse(table_product$Payment_frequency=="Monthly",12*table_product$Premium*table_product$Term*1.5,
                                        ifelse(table_product$Payment_frequency=="Quarterly",4*table_product$Premium*table_product$Term*1.5,
                                               1*table_product$Premium*table_product$Term*1.5))


table_product$Amt_on_Maturity_bin <- ifelse(table_product$Amt_on_Maturity<200000,"<200000",
                                            ifelse((table_product$Amt_on_Maturity>=200000)& (table_product$Amt_on_Maturity<250000),"200000-250000",
                                                   ifelse((table_product$Amt_on_Maturity>=250000)& (table_product$Amt_on_Maturity<300000),"250000-300000",
                                                          ifelse((table_product$Amt_on_Maturity>=300000)& (table_product$Amt_on_Maturity<350000),"300000-350000",
                                                                 ifelse((table_product$Amt_on_Maturity>=350000)& (table_product$Amt_on_Maturity<400000),"350000-400000",
                                                                        "<400000")))))

############################################################ End of table_product #######################################################'

, @output_data_1_name = N'table_product'
