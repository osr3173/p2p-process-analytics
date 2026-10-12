-- 미지급 중 "기다리는 단계"인 건: 마지막 활동 후 며칠 지났나 (기준일 = 데이터 마지막 이벤트)
-- 30/90일은 임시 기준. 일반 케이스 소요일을 잰 뒤 다시 정한다. → notes/metrics.md 4절
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,
           max(ts) AS last_ts,
           min(ts) FILTER (WHERE activity = 'Clear Invoice') AS paid,
           arg_max(activity, ts) AS last_activity
    FROM events
    GROUP BY case_id
),
ref AS (SELECT max(ts) AS end_ts FROM events)
SELECT last_activity,
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) <= 30)             AS "30일 이내",
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) BETWEEN 31 AND 90) AS "31~90일",
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) > 90)              AS "90일 초과"
FROM c, ref
WHERE paid IS NULL
  AND first_ts >= TIMESTAMPTZ '2018-01-01 00:00:00+00'
  AND last_activity IN ('Record Invoice Receipt', 'Record Goods Receipt',
                        'Remove Payment Block', 'Create Purchase Order Item')
GROUP BY 1
ORDER BY 1;
