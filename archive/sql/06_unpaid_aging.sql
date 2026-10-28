-- ============================================================
-- 06. 기다리는 중인 미지급 건: 마지막 활동 후 며칠이나 지났나?
-- ============================================================
-- 질문    : "다음 단계를 기다리는 중"인 미지급 품목이, 마지막 활동 이후 얼마나 오래 멈춰 있나?
-- 왜 하나 : 05만으로는 "데이터 끝나기 3일 전에 청구서 받은 건"(진행 중)과
--           "6개월 전에 받고 멈춘 건"(묶임)을 구분할 수 없다. 경과일을 붙여야 갈린다.
-- 기준일  : 데이터의 마지막 이벤트 시각 (2019-01-18). "오늘"이 아니라 이 날을 기준으로 센다.
-- 구간    : 30일 이내 / 31~90일 / 90일 초과. ← 임시 기준. 일반 케이스 소요일을 잰 뒤 근거 있게 다시 정한다.
-- 대상    : 05에서 "기다리는 단계"로 본 네 가지 마지막 활동만
--           (주문 생성 / 입고 / 청구서 접수 / 지급 보류 해제). 취소·기타는 제외.
-- 결과    : 2026-10-12 → notes/metrics.md 4절
--           90일 초과 = 4,713건 (미지급의 10.6%). "주문만 함"·"입고까지 됨"은 각각 29%가 90일 초과.
-- 읽는 법 : 한 줄 = 마지막 활동 하나. 오른쪽 열(90일 초과)이 "묶인 돈" 후보.
-- ============================================================

-- 1단계: 품목마다 첫 시각, 마지막 시각, 지급 시각, 마지막 활동
WITH c AS (
    SELECT case_id,
           min(ts) AS first_ts,                                        -- 가장 이른 활동 시각
           max(ts) AS last_ts,                                         -- 가장 늦은 활동 시각 = 멈춘 시점
           min(ts) FILTER (WHERE activity = 'Clear Invoice') AS paid,  -- 지급 시각. NULL이면 미지급
           arg_max(activity, ts) AS last_activity                      -- 마지막 활동 이름
    FROM events
    GROUP BY case_id
),
-- 2단계: 기준일 = 데이터 전체에서 가장 늦은 시각
ref AS (SELECT max(ts) AS end_ts FROM events)
-- 3단계: 기다리는 중인 미지급 품목만 골라, 경과일 구간별로 센다
SELECT last_activity,
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) <= 30)             AS "30일 이내",
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) BETWEEN 31 AND 90) AS "31~90일",
       count(*) FILTER (WHERE date_diff('day', last_ts, end_ts) > 90)              AS "90일 초과"
FROM c, ref
WHERE paid IS NULL                                                       -- 미지급
  AND first_ts >= TIMESTAMPTZ '2018-01-01 00:00:00+00'                   -- 데이터 오류 제외
  AND last_activity IN ('Record Invoice Receipt', 'Record Goods Receipt', -- 기다리는 단계 네 가지만
                        'Remove Payment Block', 'Create Purchase Order Item')
GROUP BY 1
ORDER BY 1;

-- 참고: date_diff('day', a, b) = a부터 b까지 며칠인지. MySQL의 DATEDIFF(b, a) 또는 TIMESTAMPDIFF(DAY, a, b)에 해당.
