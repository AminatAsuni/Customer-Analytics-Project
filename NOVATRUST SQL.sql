SELECT TOP (1000) [TransactionID]
      ,[AccountNumber]
      ,[TransactionDate]
      ,[TransactionType]
      ,[Transaction_Amount]
      ,[Balance]
      ,[TransDescription]
      ,[ReferenceNumber]
  FROM [NovaTrust].[dbo].[transaction]

  --Exploring Customers Table
  SELECT  COUNT(Account_Number) As Count
  FROM [dbo].[Customers]

  --Checking for null values
  SELECT * FROM[dbo].[Customers] c
  WHERE c.Account_Number IS NULL
  OR c.Account_Open_Date IS NULL
  OR c.Account_Type IS NULL
  OR c.Contact_Email IS NULL
  OR c.Contact_Phone IS NULL
  OR c.CustomerID IS NULL
  OR c.DateOfBirth IS NULL
  OR c.Employment_Status IS NULL
  OR c.FirstName IS NULL
  OR c.LastName IS NULL

  --Checking for duplicates
  SELECT Account_Number,CustomerID,Contact_Email, COUNT(*) AS Counts
  FROM[dbo].[Customers] 
  GROUP BY Account_Number,CustomerID,Contact_Email
  HAVING COUNT(*) > 1

  --Checking for Employment Status
  SELECT Employment_Status, COUNT(*)
  FROM[dbo].[Customers] 
  GROUP BY Employment_Status 

  --Exploring Transaction Table
  SELECT TOP 10 *
  FROM [dbo].[transaction]

 
  --Checking for Oldest  and Most Recent transaction Date
  SELECT MIN(TransactionDate) MinDate,MAX(TransactionDate) MaxDate
  FROM [dbo].[transaction]

  --Checking for Max and Min Transaction Amount
SELECT MIN(Transaction_Amount) MinTransaction,MAX(Transaction_Amount) MaxTransaction
  FROM [dbo].[transaction]

  --Checking for Transaction Type
SELECT TransactionType,COUNT(*)
  FROM [dbo].[transaction]
  GROUP BY TransactionType

GO
--Creating Stored Procedures
CREATE PROCEDURE GetCustomerSegments
	@EmploymentStatus NVARCHAR(50),
	@DateCriteria DATE,
	@TransDescription NVARCHAR(50)
AS
--Extracting student customers with salaries
WITH Salaries AS(
SELECT c.Account_Number,
			t.TransactionID,
			t.TransactionDate,
			t.Transaction_Amount,
			t.TransDescription
FROM [dbo].[Customers] AS c
INNER JOIN [dbo].[transaction] AS t
ON c.Account_Number = t.AccountNumber
WHERE c.Employment_Status = @EmploymentStatus
AND LOWER(t.TransDescription) LIKE '%' + @TransDescription +'%'
AND t.TransactionDate >= DATEADD(MONTH,-12,@DateCriteria)
AND t.TransactionType = 'Credit'
),

---Calculating THE RFM Values
--Recency
--Frequency
--Monetary Value
RFM AS (
SELECT Account_Number,
		  MAX(TransactionDate) AS LastTransactionDate,
		  DATEDIFF(MONTH,MAX(TransactionDate),@DateCriteria) AS Recency,
		  COUNT(TransactionID) AS Frequency,
		  AVG(Transaction_Amount) AS MonetaryValue
FROM Salaries
GROUP BY Account_Number
HAVING AVG(Transaction_Amount) >= 200000
),
--SELECT MIN(MonetaryValue) AS MinSalary,
	--AVG(MonetaryValue) AS AvgSalary, 
	--MAX(MonetaryValue) AS MaxSalary
--FROM RFM
--Assigning RFM Scores to each customers

RFM_Scores AS
(
SELECT Account_Number,
	   LastTransactionDate,
	   Recency,
	   Frequency,
	   MonetaryValue,
	   -- Scoring Customers based on their Recency
	   CASE
			WHEN Recency = 0 THEN 10
			WHEN Recency <3 THEN 7
			WHEN Recency <5 THEN 4
			ELSE 1
		END AS R_Score,
		-- Scoring Custoomers based on the Frequency
		CASE
			WHEN Frequency = 12 THEN 10
			WHEN Frequency >= 9 THEN 7
			WHEN Frequency >= 6 THEN 4
			ELSE 1
		END AS F_Score,
		CASE
		--Scoring customers Based on Monetary Value
			WHEN MonetaryValue > 600000 THEN 10
			WHEN MonetaryValue > 400000 THEN 7
			WHEN MonetaryValue BETWEEN 300000 AND 400000 THEN 4
			ELSE 1
		END AS M_Score
FROM RFM
),
--Segmenting each customer based on their RFM scores
SEGMENT AS(
SELECT Account_Number,
		LastTransactionDate,
		Recency,
		Frequency,
		MonetaryValue,
		CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 AS RFM_Segment,--Calculate RFM scores
		CASE -- grouping salaries based on Monetary Value
			WHEN MonetaryValue > 600000 THEN 'Above 600k'
			WHEN MonetaryValue BETWEEN 400000 AND 600000 THEN '400-600k'
			WHEN MonetaryValue BETWEEN 300000 AND 400000 THEN '300-400k'
			ELSE '200-300k'
		END AS SalaryRange,
		--Customer Segmentation
		CASE	
			WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 > 0.8 THEN 'Tier 1 Customers'
			WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 >= 0.6 THEN 'Tier 2 Customers'
			WHEN CAST((R_Score + F_Score + M_Score) AS FLOAT)/30 >= 0.5 THEN 'Tier 3 Customers'
			ELSE 'Tier 4 Customers'
		END AS Segments
FROM RFM_Scores)

--Retrieving final values 
SELECT S.Account_Number, 
	   C.Contact_Email,
	   LastTransactionDate,
	   Recency AS MonthSinceLastSalary,
	   Frequency AS SalariesReceived,
	   MonetaryValue AS AverageSalary,
	   SalaryRange,
	   Segments
FROM Segment S
LEFT JOIN [dbo].[Customers] C
ON S.Account_Number = C.Account_Number


GO


EXECUTE GetCustomerSegments
		@EmploymentStatus = 'Student',
		@DateCriteria = '2023-08-31',
		@TransDescription = 'Salary';

