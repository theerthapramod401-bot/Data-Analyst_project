/* =====================================================================
   MARKETING CAMPAIGN - STAR SCHEMA (File 2 of 3)
   Run this AFTER File 1 (needs the marketing_campaign table to exist).
   Creates dimension tables + fact_campaign_performance for Power BI.
   ===================================================================== */


-- ---------------------------------------------------------------------
-- 17. STAR SCHEMA (FACT + DIMENSION TABLES) FOR POWER BI
-- ---------------------------------------------------------------------

-- 17a. Dimension: Company
DROP TABLE IF EXISTS dim_company;
CREATE TABLE dim_company (
    Company_ID   INT AUTO_INCREMENT PRIMARY KEY,
    Company_Name VARCHAR(100) UNIQUE
);
INSERT INTO dim_company (Company_Name)
SELECT DISTINCT Company FROM marketing_campaign;

-- 17b. Dimension: Channel
DROP TABLE IF EXISTS dim_channel;
CREATE TABLE dim_channel (
    Channel_ID   INT AUTO_INCREMENT PRIMARY KEY,
    Channel_Name VARCHAR(50) UNIQUE
);
INSERT INTO dim_channel (Channel_Name)
SELECT DISTINCT Channel_Used FROM marketing_campaign;

-- 17c. Dimension: Campaign Type
DROP TABLE IF EXISTS dim_campaign_type;
CREATE TABLE dim_campaign_type (
    Campaign_Type_ID INT AUTO_INCREMENT PRIMARY KEY,
    Campaign_Type_Name VARCHAR(50) UNIQUE
);
INSERT INTO dim_campaign_type (Campaign_Type_Name)
SELECT DISTINCT Campaign_Type FROM marketing_campaign;

-- 17d. Dimension: Location
DROP TABLE IF EXISTS dim_location;
CREATE TABLE dim_location (
    Location_ID   INT AUTO_INCREMENT PRIMARY KEY,
    Location_Name VARCHAR(50) UNIQUE
);
INSERT INTO dim_location (Location_Name)
SELECT DISTINCT Location FROM marketing_campaign;

-- 17e. Dimension: Date
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    Date_ID  DATE PRIMARY KEY,
    Year_Num INT,
    Month_Num INT,
    Month_Name VARCHAR(15),
    Day_Num  INT,
    Weekday_Name VARCHAR(15)
);
INSERT INTO dim_date
SELECT DISTINCT
    Campaign_Date,
    YEAR(Campaign_Date),
    MONTH(Campaign_Date),
    MONTHNAME(Campaign_Date),
    DAY(Campaign_Date),
    DAYNAME(Campaign_Date)
FROM marketing_campaign;

-- 17f. Fact table: Campaign Performance
DROP TABLE IF EXISTS fact_campaign_performance;
CREATE TABLE fact_campaign_performance (
    Campaign_ID      INT PRIMARY KEY,
    Company_ID        INT,
    Channel_ID         INT,
    Campaign_Type_ID    INT,
    Location_ID         INT,
    Date_ID              DATE,
    Target_Audience      VARCHAR(50),
    Customer_Segment      VARCHAR(50),
    Language               VARCHAR(30),
    Duration_Days           INT,
    Clicks                  INT,
    Impressions              INT,
    Conversion_Rate           DECIMAL(6,4),
    Acquisition_Cost           DECIMAL(12,2),
    ROI                        DECIMAL(8,4),
    Engagement_Score             INT,
    CTR                          DECIMAL(6,2),
    FOREIGN KEY (Company_ID) REFERENCES dim_company(Company_ID),
    FOREIGN KEY (Channel_ID) REFERENCES dim_channel(Channel_ID),
    FOREIGN KEY (Campaign_Type_ID) REFERENCES dim_campaign_type(Campaign_Type_ID),
    FOREIGN KEY (Location_ID) REFERENCES dim_location(Location_ID),
    FOREIGN KEY (Date_ID) REFERENCES dim_date(Date_ID)
);

INSERT INTO fact_campaign_performance
SELECT
    m.Campaign_ID,
    c.Company_ID,
    ch.Channel_ID,
    ct.Campaign_Type_ID,
    l.Location_ID,
    m.Campaign_Date,
    m.Target_Audience,
    m.Customer_Segment,
    m.Language,
    CAST(SUBSTRING_INDEX(m.Duration, ' ', 1) AS UNSIGNED),
    m.Clicks,
    m.Impressions,
    m.Conversion_Rate,
    m.Acquisition_Cost,
    m.ROI,
    m.Engagement_Score,
    ROUND((m.Clicks * 1.0 / NULLIF(m.Impressions, 0)) * 100, 2)
FROM marketing_campaign m
JOIN dim_company c        ON m.Company = c.Company_Name
JOIN dim_channel ch        ON m.Channel_Used = ch.Channel_Name
JOIN dim_campaign_type ct  ON m.Campaign_Type = ct.Campaign_Type_Name
JOIN dim_location l        ON m.Location = l.Location_Name;

