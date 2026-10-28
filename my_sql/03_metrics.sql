-- ③ 지표 정의 → ④ 구간별 소요일 (10/23)
-- 질문·규칙: 직접 (notes/my_03_metrics.md) / 쿼리: AI 도구로 초안 작성, 실행·결과 검증은 직접

-- 1단계: 품목마다 4개 시점의 첫 번째 시각을 한 줄로 모으기
--   설명: case_id별로 발주·입고·송장 접수·지급의 첫 시각을 꺼내 한 줄로 만들고 case_times 임시 테이블로 저장
--   CASE WHEN: 조건 맞는 그 행의 ts, 아니면 NULL(ELSE 생략) / MIN: NULL 무시하고 가장 이른 값 / 행이 없으면 NULL
--   TEMP: 연결 끊기면 사라짐, 원본 DB에 안 남음 / OR REPLACE: 다시 실행해도 오류 안 남
--   MIN(CASE WHEN 활동 = X THEN ts END) = 그 활동의 첫 시각, 없으면 NULL
CREATE OR REPLACE TEMP TABLE case_times AS
SELECT case_id,
       MIN(CASE WHEN activity = 'Create Purchase Order Item' THEN ts END) AS po_ts,
       MIN(CASE WHEN activity = 'Record Goods Receipt'       THEN ts END) AS gr_ts,
       MIN(CASE WHEN activity = 'Record Invoice Receipt'     THEN ts END) AS ir_ts,
       MIN(CASE WHEN activity = 'Clear Invoice'              THEN ts END) AS pay_ts
FROM events
GROUP BY case_id;

-- 2단계: 4개 시점이 다 있는 품목이 몇 개인지 (나머지는 ④에서 따로)
SELECT count(*) AS 전체,
       count(*) FILTER (WHERE po_ts IS NOT NULL AND gr_ts IS NOT NULL
                          AND ir_ts IS NOT NULL AND pay_ts IS NOT NULL) AS 네시점_다있음
FROM case_times;

-- 3단계: 4개 시점 중 무엇이 빠졌나 (AI 도구로 초안, 결과 검증은 직접)
SELECT count(*) FILTER (WHERE po_ts  IS NULL) AS 발주없음,
       count(*) FILTER (WHERE gr_ts  IS NULL) AS 입고없음,
       count(*) FILTER (WHERE ir_ts  IS NULL) AS 송장접수없음,
       count(*) FILTER (WHERE pay_ts IS NULL) AS 지급없음
FROM case_times;
-- 결과: 0 / 12,143 / 18,896 / 44,594 → 발주는 전부 있음, 주로 지급이 빠짐

-- 2단계 결과: 전체 217,406 / 4개 시점 다 있음 172,241 (79.2%)
