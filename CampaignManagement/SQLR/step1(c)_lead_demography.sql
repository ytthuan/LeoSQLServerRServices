DROP TABLE IF EXISTS [Lead_Demography]

CREATE TABLE [Lead_Demography]
(
Lead_Id varchar(50),
Age	varchar(50),
Phone_No varchar(15),
Annual_Income varchar(15),
Credit_Score varchar(15),
Country varchar(5),
[State] varchar(5),
No_Of_Dependents int,
Highest_Education varchar(50),
Ethnicity varchar(50),
No_Of_Children int,
Household_Size int,
Gender varchar(15),
Marital_Status varchar(2)
)


insert into [Lead_Demography]


EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
###################################################### Creation of Lead Data ###########################################################

local <- RxLocalSeq()
rxSetComputeContext(local)

##########################################################################################################################################
## Creating and Assigning lead_id, age and phone_no
##########################################################################################################################################
# 

lead_id <- function(x) {
  guid_no <- c(1:x)
  for(i in 1:x)
  {
    guid_no[i]  <- paste(sample(c(letters[1:6],0:9),32,replace=TRUE),collapse="")
    guid_no[i] <- paste(
      substr(guid_no[i],1,8),"-",
      substr(guid_no[i],9,12),"-",
      substr(guid_no[i],13,16),"-",
      substr(guid_no[i],17,20),"-",
      substr(guid_no[i],21,32),
      sep = "",collapse = ""
      
    )  
  }
  return(guid_no)
}

table_lead <- data.frame(lead_id(100000))
colnames(table_lead)[1] <- "lead_id"

age <- c("Young","Middle Age","Senior Citizen")
avalue <- c(0.35,0.5,0.15)
table_lead$Age <- sample(age,nrow(table_lead),replace=TRUE,prob=avalue)

phone_no <- function(x){
  rnumber <- c(1:x)
  for(i in 1:x)
  {
    rnumber[i] <- paste(9,paste( sample( 0:9, 9, replace=TRUE ), collapse="" ),sep="")
  }
  return(rnumber)
}
table_lead$phone_no <- phone_no(nrow(table_lead))



###########################################################################################################################################
##Assigning values to the various demographic variables randomly.
## The variables created below are: 
## annual_income, credit_score, Country, state, no_of_children, Highest_education, ethnicity, no_of_dependents, household_size
###########################################################################################################################################

annual_income <- c("<60k","60k-120k",">120k")
aivalue <- c(0.25,0.45,0.3)
table_lead$Annual_Income <- sample(annual_income,nrow(table_lead),replace=TRUE,prob=aivalue)

credit_score <- c("<350","350-700",">700")
csvalue <- c(0.25,0.45,0.3)
table_lead$credit_score <- sample(credit_score,nrow(table_lead),replace=TRUE,prob=csvalue)


table_lead$Country <- rep("US",nrow(table_lead))

state <- c("US",	"AL",	"AK",	"AZ",	"AR",	"CA",	"CO",	"CT",	"DE",	"DC",	"FL",	"GA",	"HI",	"ID",	"IL",	"IN",	"IA",	"KS",	"KY",	"LA",	"ME",	"MD",	"MA",	"MI",	"MN",	"MS",	"MO",	"MT",	"NE",	"NV",	"NH",	"NJ",	"NM",	"NY",	"NC",	"ND",	"OH",	"OK",	"OR",	"PA",	"RI",	"SC",	"SD",	"TN",	"TX",	"UT",	"VT",	"VA",	"WA",	"WV",	"WI",	"WY",	"AS",	"GU",	"MP",	"PR",	"VI",	"UM",	"FM",	"MH",	"PW")
table_lead$state <- sample(state,nrow(table_lead),replace=TRUE)

table_lead$no_of_children <- sample(c(0:3),nrow(table_lead),replace=T)

education <- c("High School","Attended Vocational","Graduate School","College") 
table_lead$Highest_education <- sample(education,nrow(table_lead),replace=TRUE)

et<- c("white americans","african american","Hispanic","Latino")
table_lead$ethnicity <- sample(et,nrow(table_lead),replace=TRUE)

table_lead$no_of_dependents <- round(runif(nrow(table_lead),0,table_lead$no_of_children),digits=0)

table_lead$household_size <- round(runif(nrow(table_lead),1,table_lead$no_of_children+1),digits=0)

##########################################################################################################################################
##Generating and Assigning Gender and Marital Status in groups and binding them row wise. 
##########################################################################################################################################

table_lead_1 <- table_lead[1:(0.505*(nrow(table_lead))),]
table_lead_2 <- table_lead[(0.505*(nrow(table_lead))+1):(nrow(table_lead)),]


table_lead_1$Gender <- "Female"
table_lead_2$Gender <- "Male"

table_lead <- rbind(table_lead_1,table_lead_2)


table_lead_1 <- table_lead[1:(0.45*(nrow(table_lead))),]
table_lead_2 <- table_lead[(0.45*(nrow(table_lead))+1):(0.8*(nrow(table_lead))),]
table_lead_3 <- table_lead[(0.8*(nrow(table_lead))+1):(0.9*(nrow(table_lead))),]
table_lead_4 <- table_lead[(0.9*(nrow(table_lead))+1):(nrow(table_lead)),]

table_lead_1$Marital_Status <- "S"          #Single
table_lead_2$Marital_Status <- "M"          #Married
table_lead_3$Marital_Status <- "D"          #Divorced
table_lead_4$Marital_Status <- "W"          #Widowed

table_lead <- rbind(table_lead_1,table_lead_2,table_lead_3,table_lead_4)

########################################################################################################################################
########### Inserting NA values in no_of_children,no_of_dependents,household_size and Highest_education
########################################################################################################################################

x <- sample(table_lead$lead_id ,0.01*(nrow(table_lead)))

table_lead[table_lead$lead_id %in% x,"no_of_children"] = NA

x <- sample(table_lead$lead_id,0.01*(nrow(table_lead)))

table_lead[table_lead$lead_id %in% x,"no_of_dependents"] = NA

x <- sample(table_lead$lead_id,0.01*(nrow(table_lead)))

table_lead[table_lead$lead_id %in% x,"household_size"] = NA

x <- sample(table_lead$lead_id,0.01*(nrow(table_lead)))

table_lead[table_lead$lead_id %in% x,"Highest_education"] = NA

############################################################ End of table_lead #########################################################

'
, @output_data_1_name = N'table_lead'
