/* =====================================================================
   MARKETING CAMPAIGN - BI-READY VIEWS (File 3 of 3)
   Run this AFTER File 2 (needs the star schema tables to exist).
   Views for direct Power BI import.
   ===================================================================== */


-- ---------------------------------------------------------------------
-- 18. BI-READY VIEWS (built on the star schema, for direct Power BI import)
-- ---------------------------------------------------------------------

-- 18a. Channel performance view
CREATE OR REPLACE VIEW vw_channel_performance AS
SELECT
    ch.Channel_Name,
    SUM(f.Clicks)        AS total_clicks,
    SUM(f.Impressions)   AS total_impressions,
    ROUND(AVG(f.ROI), 2) AS avg_roi,
    ROUND(AVG(f.Conversion_Rate) * 100, 2) AS avg_conversion_rate_pct
FROM fact_campaign_performance f
JOIN dim_channel ch ON f.Channel_ID = ch.Channel_ID
GROUP BY ch.Channel_Name;

-- 18b. Monthly trend view
CREATE OR REPLACE VIEW vw_monthly_trend AS
SELECT
    d.Year_Num,
    d.Month_Num,
    d.Month_Name,
    SUM(f.Clicks)        AS monthly_clicks,
    ROUND(AVG(f.ROI), 2) AS monthly_avg_roi
FROM fact_campaign_performance f
JOIN dim_date d ON f.Date_ID = d.Date_ID
GROUP BY d.Year_Num, d.Month_Num, d.Month_Name
ORDER BY d.Year_Num, d.Month_Num;

-- 18c. Top campaigns view
CREATE OR REPLACE VIEW vw_top_campaigns AS
SELECT
    f.Campaign_ID,
    c.Company_Name,
    ct.Campaign_Type_Name,
    ch.Channel_Name,
    f.ROI,
    f.Clicks,
    f.Acquisition_Cost
FROM fact_campaign_performance f
JOIN dim_company c       ON f.Company_ID = c.Company_ID
JOIN dim_campaign_type ct ON f.Campaign_Type_ID = ct.Campaign_Type_ID
JOIN dim_channel ch       ON f.Channel_ID = ch.Channel_ID
ORDER BY f.ROI DESC;
