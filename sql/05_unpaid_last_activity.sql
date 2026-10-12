-- 미지급 44,590건은 어디서 멈췄나: 마지막 활동별 건수 → notes/metrics.md 4절
-- arg_max(activity, ts) = ts가 가장 큰 행의 activity (마지막 활동)
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,
           min(ts) FILTER (WHERE activity = 'Clear Invoice') AS paid,
           arg_max(activity, ts) AS last_activity
    FROM events
    GROUP BY case_id
)
SELECT last_activity,
       count(*) AS 건수,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS 비율
FROM c
WHERE paid IS NULL
  AND first_ts >= TIMESTAMPTZ '2018-01-01 00:00:00+00'
GROUP BY 1
ORDER BY 건수 DESC;
