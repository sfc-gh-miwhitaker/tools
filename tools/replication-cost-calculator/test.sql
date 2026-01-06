/******************************************************************************
 * Tool: Replication Cost Calculator - QUICK TEST
 * Run this BEFORE deploy.sql to verify your account is ready
 *
 * Expected: All tests show ✅ PASS
 ******************************************************************************/

-- Test 1: Can we access ACCOUNT_USAGE?
SELECT
    '1. ACCOUNT_USAGE Access' AS test,
    CASE WHEN COUNT(*) >= 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE 1=0;

-- Test 2: What region are you in?
SELECT
    '2. Your Region' AS test,
    CURRENT_REGION() AS your_region,
    '✅ INFO' AS result;

-- Test 3: Can we create objects?
CREATE OR REPLACE TEMPORARY TABLE _test_table (x INT);
SELECT
    '3. Create Objects' AS test,
    '✅ PASS' AS result;
DROP TABLE IF EXISTS _test_table;

-- Test 4: Quick cost calculation (manual validation)
-- For 1 TB with 5% daily change, 1 refresh/day to AWS us-east-1:
-- Daily transfer: 0.05 TB
-- Daily transfer cost: 0.05 * 2.5 = 0.125 credits
-- Daily compute cost: 0.05 * 1.0 = 0.05 credits
-- Monthly transfer+compute: (0.125 + 0.05) * 30 = 5.25 credits
-- Monthly storage: 1 * 0.25 = 0.25 credits
-- Monthly serverless: 1 * 0.10 = 0.10 credits
-- TOTAL MONTHLY: 5.60 credits
SELECT
    '4. Math Check' AS test,
    5.60 AS expected_monthly_credits_for_1tb,
    5.60 * 4.0 AS expected_monthly_usd_at_4_per_credit,
    '✅ Verify these match the app output' AS result;

-- Summary
SELECT '====== ALL TESTS COMPLETE ======' AS status;
