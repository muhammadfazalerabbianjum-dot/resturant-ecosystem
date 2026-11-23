-- =============================================================================
-- UI-7 (p17 T-3) — GA4 ecommerce funnel queries (BigQuery standard SQL)
-- =============================================================================
-- WHAT: four self-contained queries over the GA4 BigQuery export for the
--       delivered menu/dish/cart/checkout events (T-1 taxonomy):
--         Q1  funnel overview per day (view -> cart -> checkout -> purchase)
--         Q2  abandoned carts — sessions that began but never bought
--         Q3  dish ranking by items.item_id (interest vs. conversion)
--         Q4  leaky dishes — added in a session, never purchased there
--       Every query header states the business question it answers.
--
-- SETUP: replace `analytics_XXXXXXXXXX` with your dataset
--        (`analytics_<GA4 property id>`), select the BigQuery project that
--        contains it, then run ONE query at a time in the BigQuery console.
--        The dashboard deep link
--        (kAnalyticsConsoleDeepLink in analytics_snapshot.dart) opens that
--        console; operator steps live in tool_uilib/p17/RUNBOOK_ANALYTICS.md.
--
-- RULES: every query prunes with `_TABLE_SUFFIX` (L10 — never scan a whole
--        year of events); `event_date` is STRING 'YYYYMMDD';
--        `event_timestamp` is microseconds; nested params need UNNEST with
--        `name =` (GA4's event_params field is `name`, not `key`).
--
-- HONESTY (L5): the export is DAILY and carries only CONSENTED events (L1) —
--        Google backfills late arrivals up to 3 days; today's data lives in
--        `events_intraday_*` and is not in these queries. Figures are
--        "current through yesterday + late arrivals" — exactly what the
--        dashboard's freshness note tells the owner.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1 · Business question: "Where does the funnel leak — of the customers who
--      looked at a dish on each day, how many added to cart, started checkout
--      and completed a purchase, and what are the step conversion rates?"
-- -----------------------------------------------------------------------------
WITH per_user_day AS (
  SELECT
    event_date,
    user_pseudo_id,
    MAX(IF(event_name = 'view_item', 1, 0)) AS did_view,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS did_add,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS did_checkout,
    MAX(IF(event_name = 'purchase', 1, 0)) AS did_purchase
  FROM `analytics_XXXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX
        BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 27 DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY event_date, user_pseudo_id
)
SELECT
  event_date,
  COUNTIF(did_view) AS users_viewed,
  COUNTIF(did_add) AS users_added_to_cart,
  COUNTIF(did_checkout) AS users_began_checkout,
  COUNTIF(did_purchase) AS users_purchased,
  ROUND(COUNTIF(did_checkout) / NULLIF(COUNTIF(did_add), 0), 4)
      AS cart_to_checkout_rate,
  ROUND(COUNTIF(did_purchase) / NULLIF(COUNTIF(did_checkout), 0), 4)
      AS checkout_to_purchase_rate
FROM per_user_day
GROUP BY event_date
ORDER BY event_date DESC;

-- -----------------------------------------------------------------------------
-- Q2 · Business question: "WHO abandoned — which sessions put dishes in the
--      cart or started checkout but never bought, when did they last act, and
--      what checkout value was left on the table?"
--      Semantics: GA4 session = user_pseudo_id + auto-logged `ga_session_id`
--      (Firebase Analytics logs it on every event); a purchase in the SAME
--      session cancels its abandonment; `value` is in currency units (the
--      app sends cents/100), because GA4 `value` is a FLOAT param.
-- -----------------------------------------------------------------------------
WITH session_events AS (
  SELECT
    CONCAT(
      user_pseudo_id, '.',
      CAST((SELECT P.value.int_value
              FROM UNNEST(event_params) P
             WHERE P.name = 'ga_session_id') AS STRING)
    ) AS session_key,
    event_name,
    event_date,
    (SELECT P.value.float_value
       FROM UNNEST(event_params) P
      WHERE P.name = 'value') AS checkout_value
  FROM `analytics_XXXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX
        BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 27 DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name IN ('add_to_cart', 'begin_checkout', 'purchase')
),
per_session AS (
  SELECT
    session_key,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS did_add,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS did_checkout,
    MAX(IF(event_name = 'purchase', 1, 0)) AS did_purchase,
    MAX(event_date) AS last_activity_date,
    MAX(IF(event_name = 'begin_checkout', checkout_value, NULL))
        AS abandoned_checkout_value
  FROM session_events
  WHERE session_key IS NOT NULL
  GROUP BY session_key
)
SELECT
  session_key,
  last_activity_date,
  did_add,
  did_checkout,
  abandoned_checkout_value
FROM per_session
WHERE did_purchase = 0
  AND (did_add = 1 OR did_checkout = 1)
ORDER BY last_activity_date DESC;

-- -----------------------------------------------------------------------------
-- Q3 · Business question: "Which dishes dominate — ranked by items.item_id
--      across the funnel: viewed, added, checked out and actually sold?"
-- -----------------------------------------------------------------------------
SELECT
  item.item_id,
  ANY_VALUE(item.item_name) AS item_name,
  COUNTIF(event_name = 'view_item') AS times_viewed,
  COUNTIF(event_name = 'add_to_cart') AS times_added_to_cart,
  COUNTIF(event_name = 'begin_checkout') AS times_in_checkout,
  COUNTIF(event_name = 'purchase') AS times_purchased,
  SUM(IF(event_name = 'purchase', item.quantity, 0)) AS units_sold
FROM `analytics_XXXXXXXXXX.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX
      BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 27 DAY))
          AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  AND item.item_id IS NOT NULL
GROUP BY item.item_id
ORDER BY times_added_to_cart DESC, times_purchased DESC
LIMIT 100;

-- -----------------------------------------------------------------------------
-- Q4 · Business question: "Which dishes leak — ranked by how many sessions
--      added the item to the cart but never purchased THAT item in the same
--      session? (Per-session, per-item: the honest pairing of Q2 + Q3.)"
-- -----------------------------------------------------------------------------
WITH session_item AS (
  SELECT
    CONCAT(
      user_pseudo_id, '.',
      CAST((SELECT P.value.int_value
              FROM UNNEST(event_params) P
             WHERE P.name = 'ga_session_id') AS STRING)
    ) AS session_key,
    item.item_id,
    ANY_VALUE(item.item_name) AS item_name,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS did_add,
    MAX(IF(event_name = 'purchase', 1, 0)) AS did_purchase
  FROM `analytics_XXXXXXXXXX.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX
        BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 27 DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name IN ('add_to_cart', 'purchase')
    AND item.item_id IS NOT NULL
  GROUP BY session_key, item.item_id
)
SELECT
  item_id,
  ANY_VALUE(item_name) AS item_name,
  COUNTIF(did_add = 1 AND did_purchase = 0) AS abandoned_sessions,
  COUNTIF(did_add = 1) AS sessions_that_added
FROM session_item
WHERE did_add = 1
GROUP BY item_id
ORDER BY abandoned_sessions DESC, sessions_that_added DESC
LIMIT 50;
