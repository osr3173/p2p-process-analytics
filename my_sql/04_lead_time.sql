-- ④ 구간별 소요일 (10/23)
-- 질문·규칙: 리드 (notes/my_03_metrics.md) / 쿼리: AI 초안
-- 전제: 03_metrics.sql 1단계(case_times 임시 테이블)를 먼저 실행해야 함

-- 1단계: 품목마다 구간별 소요일 계산 (일 단위, 시각 차이 초 ÷ 86400)
CREATE OR REPLACE TEMP TABLE lead_times AS
SELECT case_id,
       (epoch(gr_ts)  - epoch(po_ts)) / 86400.0 AS a_발주_입고,
       (epoch(ir_ts)  - epoch(gr_ts)) / 86400.0 AS b_입고_송장접수,
       (epoch(pay_ts) - epoch(ir_ts)) / 86400.0 AS c_송장접수_지급,
       (epoch(pay_ts) - epoch(po_ts)) / 86400.0 AS 전체_발주_지급
FROM case_times
WHERE po_ts IS NOT NULL AND gr_ts IS NOT NULL
  AND ir_ts IS NOT NULL AND pay_ts IS NOT NULL;

-- 2단계: 구간별 중앙값·P90
SELECT '건수' AS 구분,
       count(*) AS a_발주_입고, count(*) AS b_입고_송장접수, count(*) AS c_송장접수_지급, count(*) AS 전체
FROM lead_times
UNION ALL
SELECT '중앙값(일)',
       round(median(a_발주_입고), 1), round(median(b_입고_송장접수), 1),
       round(median(c_송장접수_지급), 1), round(median(전체_발주_지급), 1)
FROM lead_times
UNION ALL
SELECT 'P90(일)',
       round(quantile_cont(a_발주_입고, 0.9), 1), round(quantile_cont(b_입고_송장접수, 0.9), 1),
       round(quantile_cont(c_송장접수_지급, 0.9), 1), round(quantile_cont(전체_발주_지급, 0.9), 1)
FROM lead_times;

-- 3단계 (참고): B 구간이 음수인 품목 수 = 송장 접수가 입고보다 먼저 (before GR 정상 흐름)
SELECT count(*) FILTER (WHERE b_입고_송장접수 < 0) AS b_음수,
       count(*) AS 전체
FROM lead_times;

-- 결과 (10/23):
-- 중앙값 A 8.9 / B 8.2 / C 43.0 / 전체 77.1일
-- P90    A 30.1 / B 42.9 / C 97.9 / 전체 126.9일
-- B 음수 14,963 / 172,241 (8.7%) = before GR 정상 흐름
-- 해석(리드): 병목은 C 송장 접수→지급

-- 4단계 (리드 작성, 10/23): 모든 구간 음수 세기
SELECT
count(*) FILTER (WHERE a_발주_입고 < 0) AS a_음수,
count(*) FILTER (WHERE b_입고_송장접수 < 0) AS b_음수,
count(*) FILTER (WHERE c_송장접수_지급 < 0) AS c_음수,
count(*) FILTER (WHERE 전체_발주_지급 < 0) AS 전체_음수
FROM lead_times;
-- 결과: a 0 / b 14,963 / c 9 / 전체 0

-- 5단계 (리드 작성): c 음수 9건 목록
SELECT case_id, c_송장접수_지급
FROM lead_times
WHERE c_송장접수_지급 < 0;
-- 결과: 9건, 모두 발주 번호 다름. -0.0125일(약 18분) 1건, 나머지 8건 -5 ~ -210일

-- 6단계 (리드 작성): 가장 큰 -210일 품목의 활동 순서
SELECT activity, ts
FROM events
WHERE case_id = '4507016022_00020'
ORDER BY ts;
-- 결과: 발주 3/13 → 업체 송장 발행 3/31 → 입고 4/4 → 지급 5/24 → 송장 접수 12/20, 활동마다 1번씩

-- 7단계 (리드 작성): 9건이 c 중앙값에 주는 영향
SELECT median(c_송장접수_지급) AS c_전체,
       median(c_송장접수_지급) FILTER (WHERE c_송장접수_지급 >= 0) AS c_음수제외
FROM lead_times;
-- 결과: 42.99 / 42.99 → 영향 없음
