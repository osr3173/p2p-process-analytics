-- ============================================================
-- 04. 케이스 4분류: 21만 건 중 "제대로 잴 수 있는 건"은 몇 건인가?
-- ============================================================
-- 질문    : 품목 217,406건을 ① 데이터 오류 ② 미지급 ③ 서류 없이 지급 ④ 일반 으로 나누면 각각 몇 건?
-- 왜 하나 : 소요 기간을 재기 전에, 측정 대상(일반)과 예외를 먼저 갈라야 한다.
--           예외가 많으면 "일반 기준 중앙값 ○일"이라는 결론의 의미가 달라진다.
-- 규칙    : notes/metrics.md 3절. 위에서부터 검사해서 처음 맞는 분류 하나만 붙는다 (순서 중요).
--           ① 첫 활동이 2018-01-01 이전 → 데이터 오류 (이 데이터는 2018년 기록)
--           ② 지급(Clear Invoice) 기록이 없음 → 미지급
--           ③ 지급은 있는데 입고 또는 청구서 기록이 없음 → 서류 없이 지급 (규정 위반 후보)
--           ④ 나머지 → 일반 (측정 대상)
-- 결과    : 2026-10-12  193 (0.1%) / 44,590 (20.5%) / 570 (0.3%) / 172,053 (79.1%)
--           네 숫자의 합 = 217,406 → 빠지거나 겹친 건 없음 ✅
-- 읽는 법 : "4 일반"이 측정 대상. "2 미지급"이 크면 따로 들여다본다 (→ 05, 06).
-- ============================================================

-- 1단계: 품목마다 필요한 시각 4개를 한 줄로 모은다
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,                                                 -- 가장 이른 활동 시각
           min(ts) FILTER (WHERE activity = 'Record Goods Receipt')   AS gr,    -- 입고(물건 도착) 첫 시각. 없으면 NULL
           min(ts) FILTER (WHERE activity = 'Record Invoice Receipt') AS ir,    -- 청구서 접수 첫 시각. 없으면 NULL
           min(ts) FILTER (WHERE activity = 'Clear Invoice')          AS paid   -- 지급 첫 시각. 없으면 NULL
    FROM events
    GROUP BY case_id
)
-- 2단계: 위에서부터 차례로 검사해 분류 이름을 붙이고, 분류별로 센다
SELECT CASE
           WHEN first_ts < TIMESTAMPTZ '2018-01-01 00:00:00+00' THEN '1 데이터오류: 2018년 이전'
           WHEN paid IS NULL                                     THEN '2 업무예외: 미지급'
           WHEN gr IS NULL OR ir IS NULL                         THEN '3 업무예외: 서류 없이 지급'
           ELSE                                                       '4 일반'
       END AS 분류,
       count(*) AS 건수,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS 비율   -- 전체 대비 % (sum() OVER () = 전체 합계)
FROM c
GROUP BY 1
ORDER BY 1;

-- 참고: FILTER (WHERE ...) 는 DuckDB 문법. "조건에 맞는 행만 골라서 집계"한다.
--       MySQL이라면 MIN(CASE WHEN activity='...' THEN ts END) 로 쓴다.
