-- ④-2 지연 집중도 (10/26)
-- 질문·지연 기준·판단 기준: 리드 (notes/my_04_lead_time.md) / 쿼리: 리드 작성 (뼈대 힌트만 AI)
-- 전제: 03 1단계(case_times) → 04 1단계(lead_times) 먼저 실행
-- 지연 기준: C 구간(송장 접수→지급) > 97.9일 (= P90). C 음수 9건은 >= 0 조건으로 제외

-- 1단계: 공급사별 지연 건수 상위 10
SELECT c.vendor, count(*) AS 지연건수
FROM lead_times l
JOIN cases c ON l.case_id = c.case_id
WHERE l.c_송장접수_지급 > 97.9
GROUP BY c.vendor
ORDER BY count(*) DESC
LIMIT 10;
-- 결과: 0136 7,694 / 0120 3,493 / 0103 2,241 / 0182 1,453 / 0278 519 / …

-- 2단계: 전체 지연 건수
SELECT count(*) AS 전체_지연건수
FROM lead_times
WHERE c_송장접수_지급 > 97.9;
-- 결과: 17,165 (172,241의 10.0%) → 1위 44.8%, 상위 4곳 86.7%, 상위 10곳 92.9%

-- 3단계: 공급사별 전체 품목·지연 품목·지연 비율
SELECT c.vendor,
       count(*) AS 전체품목,
       count(*) FILTER (WHERE l.c_송장접수_지급 > 97.9) AS 지연품목,
       round(100.0 * count(*) FILTER (WHERE l.c_송장접수_지급 > 97.9) / count(*), 1) AS 지연비율
FROM lead_times l
JOIN cases c ON l.case_id = c.case_id
GROUP BY c.vendor
ORDER BY 지연품목 DESC
LIMIT 10;
-- 결과: 0136 10,518/7,694 = 73.2% / 0120 10,411/3,493 = 33.6% / 0103 58.5% / 0182 30.0% / 0278 55.4% / 7~10위 3~11%
-- 판단(리드): 지연 누적 90%를 덮는 상위 10곳 중 지연 비율 30%(평균 10%의 3배) 이상 = 우선 관리 5곳

-- 4단계: 검증 — 0136 지연 품목 1건 활동 순서
SELECT ts, activity
FROM events
WHERE case_id = '4508044951_00020'
ORDER BY ts;
-- 결과: 송장 접수 8/9 → 보류 해제 8/10 → (4개월 활동 없음) → 지급 12/7 = 119.9일, 쿼리 결과와 일치

-- 5단계: 0136 지연 품목 vs 지연 아닌 품목의 보류 해제 기록 비율
SELECT count(DISTINCT e.case_id) AS 보류해제_있는_품목
FROM lead_times l
JOIN cases c  ON l.case_id = c.case_id
JOIN events e ON l.case_id = e.case_id
WHERE c.vendor = 'vendorID_0136'
  AND l.c_송장접수_지급 > 97.9
  AND e.activity = 'Remove Payment Block';
-- 결과: 4,455 / 7,694 = 57.9%

SELECT count(DISTINCT e.case_id) AS 보류해제_있는_품목
FROM lead_times l
JOIN cases c  ON l.case_id = c.case_id
JOIN events e ON l.case_id = e.case_id
WHERE c.vendor = 'vendorID_0136'
  AND l.c_송장접수_지급 BETWEEN 0 AND 97.9
  AND e.activity = 'Remove Payment Block';
-- 결과: 1,201 / 2,824 = 42.5% → 보류만으로는 지연 설명 안 됨

SELECT activity, count(*) AS 건수
FROM events
WHERE activity LIKE '%Payment Block'
GROUP BY activity;
-- 결과: Set 52 / Remove 54,458 → 보류를 거는 기록은 거의 없음 (해제 기록으로만 간접 확인)

-- 6단계: 지출 영역별
SELECT c.spend_area_text,
       count(*) AS 전체품목,
       count(*) FILTER (WHERE l.c_송장접수_지급 > 97.9) AS 지연품목,
       round(100.0 * count(*) FILTER (WHERE l.c_송장접수_지급 > 97.9) / count(*), 1) AS 지연비율
FROM lead_times l
JOIN cases c ON l.case_id = c.case_id
GROUP BY c.spend_area_text
ORDER BY 지연품목 DESC
LIMIT 10;
-- 결과: Packaging 73,056/16,024 = 21.9% (전체 지연의 93.4%) / 나머지 영역 2.5% 이하 / 영역 이름 빈 품목 1,413

-- 7단계: 공급사 × 지출 영역
SELECT c.vendor, c.spend_area_text, count(*) AS 지연품목
FROM lead_times l
JOIN cases c ON l.case_id = c.case_id
WHERE l.c_송장접수_지급 > 97.9
GROUP BY c.vendor, c.spend_area_text
ORDER BY 지연품목 DESC
LIMIT 10;
-- 결과: 우선 관리 5곳 모두 Packaging (7,687 / 3,484 / 2,207 / 1,445 / 508 = 15,331 = 전체 지연의 89.3%)
