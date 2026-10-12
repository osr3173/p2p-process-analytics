-- 케이스 4분류: 데이터 오류 / 미지급 / 서류 없이 지급 / 일반
-- 규칙: notes/metrics.md 3절. 위에서부터 먼저 맞는 분류 하나만 붙는다.
-- 결과 (2026-10-12): 193 / 44,590 / 570 / 172,053 (합 217,406)
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,
           min(ts) FILTER (WHERE activity = 'Record Goods Receipt')   AS gr,
           min(ts) FILTER (WHERE activity = 'Record Invoice Receipt') AS ir,
           min(ts) FILTER (WHERE activity = 'Clear Invoice')          AS paid
    FROM events
    GROUP BY case_id
)
SELECT CASE
           WHEN first_ts < TIMESTAMPTZ '2018-01-01 00:00:00+00' THEN '1 데이터오류: 2018년 이전'
           WHEN paid IS NULL                                     THEN '2 업무예외: 미지급'
           WHEN gr IS NULL OR ir IS NULL                         THEN '3 업무예외: 서류 없이 지급'
           ELSE                                                       '4 일반'
       END AS 분류,
       count(*) AS 건수,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS 비율
FROM c
GROUP BY 1
ORDER BY 1;
