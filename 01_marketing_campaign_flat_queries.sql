/* =====================================================================
   MARKETING CAMPAIGN - FLAT TABLE ANALYSIS QUERIES (File 1 of 3)
   Run this after creating + loading the marketing_campaign table.
   Covers: cleaning, KPIs, channel/campaign/audience/language analysis,
   correlation, engagement score, and window functions.
   ===================================================================== */

/* =====================================================================
   MARKETING CAMPAIGN PERFORMANCE ANALYSIS - SQL
   Dataset: marketing_campaign_dataset.csv
   Mirrors the Python/Pandas EDA notebook (cleaning, KPIs, channel/campaign
   analysis, ROI trends, top campaigns) in pure SQL.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. TABLE CREATION
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS marketing_campaign;

CREATE TABLE marketing_campaign (
    Campaign_ID        INT PRIMARY KEY,
    Company             VARCHAR(100),
    Campaign_Type        VARCHAR(50),
    Target_Audience      VARCHAR(50),
    Duration             VARCHAR(20),       -- raw text e.g. "30 days"
    Channel_Used         VARCHAR(50),
    Conversion_Rate       DECIMAL(6,4),
    Acquisition_Cost      DECIMAL(12,2),     -- cleaned numeric (no $ , )
    ROI                  DECIMAL(8,4),
    Location              VARCHAR(50),
    Language              VARCHAR(30),
    Clicks                INT,
    Impressions           INT,
    Engagement_Score       INT,
    Customer_Segment       VARCHAR(50),
    Campaign_Date          DATE
);

-- If loading raw CSV first into a staging table (Acquisition_Cost as text
-- because of "$" and "," formatting), use this staging table, clean it,
-- then insert into marketing_campaign:

DROP TABLE IF EXISTS marketing_campaign_staging;

CREATE TABLE marketing_campaign_staging (
    Campaign_ID        INT,
    Company             VARCHAR(100),
    Campaign_Type        VARCHAR(50),
    Target_Audience      VARCHAR(50),
    Duration             VARCHAR(20),
    Channel_Used         VARCHAR(50),
    Conversion_Rate       VARCHAR(20),
    Acquisition_Cost      VARCHAR(20),       -- raw, e.g. "$16,174.00"
    ROI                  VARCHAR(20),
    Location              VARCHAR(50),
    Language              VARCHAR(30),
    Clicks                VARCHAR(20),
    Impressions           VARCHAR(20),
    Engagement_Score       VARCHAR(20),
    Customer_Segment       VARCHAR(50),
    Campaign_Date          VARCHAR(20)
);

-- Example LOAD (adjust to your DBMS - MySQL syntax shown):
-- LOAD DATA INFILE 'marketing_campaign_dataset.csv'
-- INTO TABLE marketing_campaign_staging
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;


-- ---------------------------------------------------------------------
-- 2. DATA CLEANING (staging -> final table)
-- ---------------------------------------------------------------------

-- 2a. Remove duplicate Campaign_IDs in staging before insert
DELETE s1 FROM marketing_campaign_staging s1
JOIN marketing_campaign_staging s2
  ON s1.Campaign_ID = s2.Campaign_ID
 AND s1.Campaign_ID > s2.Campaign_ID;

-- 2b. Insert cleaned/typed records into the final table
INSERT INTO marketing_campaign
SELECT
    Campaign_ID,
    Company,
    Campaign_Type,
    Target_Audience,
    Duration,
    Channel_Used,
    CAST(Conversion_Rate AS DECIMAL(6,4)),
    CAST(REPLACE(REPLACE(Acquisition_Cost, '$', ''), ',', '') AS DECIMAL(12,2)),
    CAST(ROI AS DECIMAL(8,4)),
    Location,
    Language,
    CAST(Clicks AS INT),
    CAST(Impressions AS INT),
    CAST(Engagement_Score AS INT),
    Customer_Segment,
    CAST(Campaign_Date AS DATE)
FROM marketing_campaign_staging
WHERE Campaign_ID IS NOT NULL
  AND Acquisition_Cost IS NOT NULL
  AND ROI IS NOT NULL;

-- 2c. Check for missing values column by column (after load)
SELECT
    SUM(CASE WHEN Company IS NULL THEN 1 ELSE 0 END)         AS missing_company,
    SUM(CASE WHEN Campaign_Type IS NULL THEN 1 ELSE 0 END)    AS missing_campaign_type,
    SUM(CASE WHEN Acquisition_Cost IS NULL THEN 1 ELSE 0 END) AS missing_cost,
    SUM(CASE WHEN ROI IS NULL THEN 1 ELSE 0 END)              AS missing_roi,
    SUM(CASE WHEN Clicks IS NULL THEN 1 ELSE 0 END)           AS missing_clicks,
    SUM(CASE WHEN Impressions IS NULL THEN 1 ELSE 0 END)      AS missing_impressions
FROM marketing_campaign;

-- 2d. Row count / dataset size check
SELECT COUNT(*) AS total_rows FROM marketing_campaign;


-- ---------------------------------------------------------------------
-- 3. FEATURE ENGINEERING
-- ---------------------------------------------------------------------

-- 3a. CTR (Click-Through Rate) = Clicks / Impressions * 100
SELECT
    Campaign_ID,
    Company,
    Clicks,
    Impressions,
    ROUND((Clicks * 1.0 / NULLIF(Impressions, 0)) * 100, 2) AS CTR
FROM marketing_campaign;

-- 3b. Duration in numeric days (parsed from "30 days" -> 30)
SELECT
    Campaign_ID,
    Duration,
    CAST(SUBSTRING_INDEX(Duration, ' ', 1) AS UNSIGNED) AS Duration_Days
FROM marketing_campaign;


-- ---------------------------------------------------------------------
-- 4. OVERALL KPIs
-- ---------------------------------------------------------------------

SELECT
    SUM(Clicks)                                AS total_clicks,
    SUM(Impressions)                           AS total_impressions,
    ROUND(AVG(ROI), 2)                         AS avg_roi,
    SUM(Acquisition_Cost)                      AS total_acquisition_cost,
    ROUND(AVG(Conversion_Rate) * 100, 2)       AS avg_conversion_rate_pct,
    ROUND(SUM(Clicks) * 1.0 / NULLIF(SUM(Impressions), 0) * 100, 2) AS overall_ctr
FROM marketing_campaign;


-- ---------------------------------------------------------------------
-- 5. CHANNEL-WISE PERFORMANCE
-- ---------------------------------------------------------------------

SELECT
    Channel_Used,
    SUM(Clicks)                          AS total_clicks,
    SUM(Impressions)                     AS total_impressions,
    ROUND(AVG(ROI), 2)                   AS avg_roi,
    ROUND(AVG(Conversion_Rate) * 100, 2) AS avg_conversion_rate_pct,
    SUM(Acquisition_Cost)                AS total_acquisition_cost
FROM marketing_campaign
GROUP BY Channel_Used
ORDER BY avg_roi DESC;


-- ---------------------------------------------------------------------
-- 6. CAMPAIGN TYPE ANALYSIS
-- ---------------------------------------------------------------------

SELECT
    Campaign_Type,
    ROUND(AVG(ROI), 2) AS avg_roi,
    SUM(Clicks)         AS total_clicks,
    COUNT(*)            AS num_campaigns
FROM marketing_campaign
GROUP BY Campaign_Type
ORDER BY avg_roi DESC;

-- 6a. Campaign type distribution (% share)
SELECT
    Campaign_Type,
    COUNT(*) AS campaign_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_share
FROM marketing_campaign
GROUP BY Campaign_Type
ORDER BY campaign_count DESC;


-- ---------------------------------------------------------------------
-- 7. ROI vs ACQUISITION COST (bucketed, since SQL has no scatter plot)
-- ---------------------------------------------------------------------

SELECT
    CASE
        WHEN Acquisition_Cost < 5000  THEN 'Low (<5K)'
        WHEN Acquisition_Cost < 10000 THEN 'Medium (5K-10K)'
        WHEN Acquisition_Cost < 15000 THEN 'High (10K-15K)'
        ELSE 'Very High (15K+)'
    END AS cost_bucket,
    COUNT(*)            AS num_campaigns,
    ROUND(AVG(ROI), 2)  AS avg_roi
FROM marketing_campaign
GROUP BY cost_bucket
ORDER BY avg_roi DESC;


-- ---------------------------------------------------------------------
-- 8. ROI BY CAMPAIGN TYPE (ranked)
-- ---------------------------------------------------------------------

SELECT
    Campaign_Type,
    ROUND(AVG(ROI), 2) AS avg_roi,
    RANK() OVER (ORDER BY AVG(ROI) DESC) AS roi_rank
FROM marketing_campaign
GROUP BY Campaign_Type;


-- ---------------------------------------------------------------------
-- 9. MONTHLY CAMPAIGN TREND
-- ---------------------------------------------------------------------

SELECT
    DATE_FORMAT(Campaign_Date, '%Y-%m') AS campaign_month,
    SUM(Clicks)         AS monthly_clicks,
    ROUND(AVG(ROI), 2)  AS monthly_avg_roi,
    COUNT(*)             AS num_campaigns
FROM marketing_campaign
GROUP BY campaign_month
ORDER BY campaign_month;


-- ---------------------------------------------------------------------
-- 10. TOP 10 CAMPAIGNS BY ROI
-- ---------------------------------------------------------------------

SELECT
    Campaign_ID,
    Company,
    Campaign_Type,
    Channel_Used,
    ROI,
    Clicks,
    Acquisition_Cost
FROM marketing_campaign
ORDER BY ROI DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 11. TOP PERFORMING COMPANY / SEGMENT / LOCATION (bonus KPIs)
-- ---------------------------------------------------------------------

-- 11a. Top 10 companies by average ROI
SELECT
    Company,
    ROUND(AVG(ROI), 2) AS avg_roi,
    COUNT(*)             AS num_campaigns
FROM marketing_campaign
GROUP BY Company
ORDER BY avg_roi DESC
LIMIT 10;

-- 11b. Performance by customer segment
SELECT
    Customer_Segment,
    ROUND(AVG(ROI), 2)                   AS avg_roi,
    ROUND(AVG(Conversion_Rate) * 100, 2) AS avg_conversion_rate_pct,
    SUM(Clicks)                          AS total_clicks
FROM marketing_campaign
GROUP BY Customer_Segment
ORDER BY avg_roi DESC;

-- 11c. Performance by location
SELECT
    Location,
    ROUND(AVG(ROI), 2)    AS avg_roi,
    SUM(Acquisition_Cost) AS total_acquisition_cost
FROM marketing_campaign
GROUP BY Location
ORDER BY avg_roi DESC;


-- ---------------------------------------------------------------------
-- 12. CORRELATION ANALYSIS (mirrors the notebook's correlation heatmap)
-- ---------------------------------------------------------------------

-- 12a. Native CORR() - works on PostgreSQL and MySQL 8.0.31+
SELECT
    ROUND(CORR(Clicks, Impressions), 4)        AS corr_clicks_impressions,
    ROUND(CORR(Clicks, ROI), 4)                AS corr_clicks_roi,
    ROUND(CORR(Impressions, ROI), 4)           AS corr_impressions_roi,
    ROUND(CORR(Conversion_Rate, ROI), 4)       AS corr_conversionrate_roi,
    ROUND(CORR(Acquisition_Cost, ROI), 4)      AS corr_cost_roi,
    ROUND(CORR(Engagement_Score, ROI), 4)      AS corr_engagement_roi
FROM marketing_campaign;

-- 12b. Manual Pearson correlation (portable fallback if CORR() isn't
-- available on your engine, e.g. older MySQL / SQL Server). Example shown
-- for Acquisition_Cost vs ROI - repeat the pattern for other pairs.
SELECT
    (SUM(x.Acquisition_Cost * x.ROI) - COUNT(*) * AVG(x.Acquisition_Cost) * AVG(x.ROI))
    /
    (SQRT(SUM(POWER(x.Acquisition_Cost, 2)) - COUNT(*) * POWER(AVG(x.Acquisition_Cost), 2))
     * SQRT(SUM(POWER(x.ROI, 2)) - COUNT(*) * POWER(AVG(x.ROI), 2)))
    AS corr_cost_roi_manual
FROM marketing_campaign x;


-- ---------------------------------------------------------------------
-- 13. ENGAGEMENT SCORE ANALYSIS
-- ---------------------------------------------------------------------

-- 13a. Average engagement by channel
SELECT
    Channel_Used,
    ROUND(AVG(Engagement_Score), 2) AS avg_engagement_score,
    ROUND(AVG(ROI), 2)              AS avg_roi
FROM marketing_campaign
GROUP BY Channel_Used
ORDER BY avg_engagement_score DESC;

-- 13b. Average engagement by campaign type
SELECT
    Campaign_Type,
    ROUND(AVG(Engagement_Score), 2) AS avg_engagement_score
FROM marketing_campaign
GROUP BY Campaign_Type
ORDER BY avg_engagement_score DESC;

-- 13c. Engagement score distribution (bucketed)
SELECT
    Engagement_Score,
    COUNT(*) AS num_campaigns,
    ROUND(AVG(ROI), 2) AS avg_roi
FROM marketing_campaign
GROUP BY Engagement_Score
ORDER BY Engagement_Score;


-- ---------------------------------------------------------------------
-- 14. TARGET AUDIENCE ANALYSIS
-- ---------------------------------------------------------------------

SELECT
    Target_Audience,
    COUNT(*)                              AS num_campaigns,
    ROUND(AVG(ROI), 2)                    AS avg_roi,
    ROUND(AVG(Conversion_Rate) * 100, 2)  AS avg_conversion_rate_pct,
    SUM(Clicks)                           AS total_clicks
FROM marketing_campaign
GROUP BY Target_Audience
ORDER BY avg_roi DESC;


-- ---------------------------------------------------------------------
-- 15. LANGUAGE-WISE PERFORMANCE
-- ---------------------------------------------------------------------

SELECT
    Language,
    COUNT(*)            AS num_campaigns,
    ROUND(AVG(ROI), 2)  AS avg_roi,
    SUM(Impressions)    AS total_impressions
FROM marketing_campaign
GROUP BY Language
ORDER BY avg_roi DESC;


-- ---------------------------------------------------------------------
-- 16. WINDOW FUNCTIONS - RUNNING TOTALS & MONTH-OVER-MONTH CHANGE
-- ---------------------------------------------------------------------

-- 16a. Running total of clicks over time (cumulative)
WITH monthly AS (
    SELECT
        DATE_FORMAT(Campaign_Date, '%Y-%m') AS campaign_month,
        SUM(Clicks)        AS monthly_clicks,
        ROUND(AVG(ROI), 2) AS monthly_avg_roi
    FROM marketing_campaign
    GROUP BY campaign_month
)
SELECT
    campaign_month,
    monthly_clicks,
    SUM(monthly_clicks) OVER (ORDER BY campaign_month) AS running_total_clicks,
    monthly_avg_roi
FROM monthly
ORDER BY campaign_month;

-- 16b. Month-over-month % change in average ROI
WITH monthly_roi AS (
    SELECT
        DATE_FORMAT(Campaign_Date, '%Y-%m') AS campaign_month,
        ROUND(AVG(ROI), 2) AS avg_roi
    FROM marketing_campaign
    GROUP BY campaign_month
)
SELECT
    campaign_month,
    avg_roi,
    LAG(avg_roi) OVER (ORDER BY campaign_month) AS prev_month_roi,
    ROUND(
        (avg_roi - LAG(avg_roi) OVER (ORDER BY campaign_month))
        / NULLIF(LAG(avg_roi) OVER (ORDER BY campaign_month), 0) * 100, 2
    ) AS mom_pct_change
FROM monthly_roi
ORDER BY campaign_month;

-- 16c. Rank campaigns within each channel by ROI (top performer per channel)
SELECT *
FROM (
    SELECT
        Campaign_ID,
        Company,
        Channel_Used,
        ROI,
        RANK() OVER (PARTITION BY Channel_Used ORDER BY ROI DESC) AS roi_rank_in_channel
    FROM marketing_campaign
) ranked
WHERE roi_rank_in_channel = 1;

