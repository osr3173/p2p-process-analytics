-- ============================================================
-- 05. 미지급 44,590건은 어디서 멈췄나? (마지막 활동별 건수)
-- ============================================================
-- 질문    : 지급 기록이 없는 품목들은 "마지막으로 무슨 일"까지 하고 멈춰 있나?
-- 왜 하나 : "미지급 = 돈이 묶인 것"이라는 가설을 확인하려고.
--           마지막 활동을 보면 취소된 건지, 다음 단계를 기다리는 건지 갈린다.
-- 결과    : 2026-10-12 → notes/metrics.md 4절
--           청구서 접수 46.5% / 주문 삭제(=취소) 16.4% / 입고 16.2% / 보류 해제 11.3% / 주문 생성 8.5% ...
-- 읽는 법 : "Delete Purchase Order Item"이 마지막이면 취소 → 낼 돈이 없으니 문제 아님.
--           나머지는 어떤 단계를 "기다리는 중". 얼마나 오래 기다렸는지는 06에서 본다.
-- ============================================================

-- 1단계: 품목마다 첫 시각, 지급 시각, 마지막 활동을 한 줄로
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,                                        -- 가장 이른 활동 시각 (데이터 오류 거르기용)
           min(ts) FILTER (WHERE activity = 'Clear Invoice') AS paid,  -- 지급 시각. 없으면 NULL = 미지급
           arg_max(activity, ts) AS last_activity                      -- 시각(ts)이 가장 늦은 행의 활동 이름 = 마지막 활동
    FROM events
    GROUP BY case_id
)
-- 2단계: 미지급 품목만 골라 마지막 활동별로 센다
SELECT last_activity,
       count(*) AS 건수,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS 비율
FROM c
WHERE paid IS NULL                                            -- 지급 기록 없음 = 미지급
  AND first_ts >= TIMESTAMPTZ '2018-01-01 00:00:00+00'        -- 데이터 오류(2018년 이전)는 제외
GROUP BY 1
ORDER BY 건수 DESC;

-- 참고: arg_max(activity, ts) 는 DuckDB 함수. "ts가 최대인 행의 activity"를 돌려준다.
--       MySQL에는 없어서 서브쿼리나 ROW_NUMBER() 윈도우 함수로 길게 써야 한다.
