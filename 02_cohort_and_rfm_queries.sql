-- ====================================================================
-- Project: E-Commerce Customer Retention & Sales Intelligence Pipeline
-- Database: ecommerce_db
-- Author: Dinesh Tadaka
-- ====================================================================

USE ecommerce_db;

-- --------------------------------------------------------------------
-- 1. Customer Cohort Retention Matrix View
-- --------------------------------------------------------------------
CREATE OR REPLACE VIEW view_cohort_retention AS
WITH customer_first_purchase AS (
    SELECT 
        CustomerID,
        MIN(InvoiceMonth) AS cohort_month
    FROM ecom_transactions
    GROUP BY CustomerID
),
cohort_transactions AS (
    SELECT 
        t.CustomerID,
        cfp.cohort_month,
        t.InvoiceMonth AS order_month,
        TIMESTAMPDIFF(MONTH, cfp.cohort_month, t.InvoiceMonth) AS cohort_index,
        t.TotalAmount
    FROM ecom_transactions t
    JOIN customer_first_purchase cfp ON t.CustomerID = cfp.CustomerID
)
SELECT 
    DATE_FORMAT(cohort_month, '%Y-%m') AS cohort_year_month,
    cohort_index,
    COUNT(DISTINCT CustomerID) AS active_customers,
    ROUND(SUM(TotalAmount), 2) AS total_revenue
FROM cohort_transactions
GROUP BY cohort_transactions.cohort_month, cohort_index
ORDER BY cohort_transactions.cohort_month, cohort_index;

-- --------------------------------------------------------------------
-- 2. RFM Customer Segmentation View
-- --------------------------------------------------------------------
CREATE OR REPLACE VIEW view_rfm_segmentation AS
WITH rfm_base AS (
    SELECT 
        CustomerID,
        DATEDIFF((SELECT MAX(InvoiceDate) FROM ecom_transactions), MAX(InvoiceDate)) AS recency_days,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        ROUND(SUM(TotalAmount), 2) AS monetary_value
    FROM ecom_transactions
    GROUP BY CustomerID
),
rfm_scores AS (
    SELECT 
        CustomerID,
        recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM rfm_base
),
rfm_combined AS (
    SELECT 
        CustomerID,
        recency_days,
        frequency,
        monetary_value,
        r_score,
        f_score,
        m_score,
        ROUND((r_score + f_score + m_score) / 3.0, 1) AS avg_rfm_score
    FROM rfm_scores
)
SELECT 
    CustomerID,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    avg_rfm_score,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk / Slipping'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost / Inactive'
        ELSE 'Potential Loyalists'
    END AS customer_segment
FROM rfm_combined;
