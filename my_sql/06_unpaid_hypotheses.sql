-- ④-3 미지급 44,594품목 가설 구분 (10/26)
-- 가설 4개·경계: 직접 (notes/my_03_metrics.md, my_04_lead_time.md) / 쿼리: 0단계는 직접 작성, 나머지는 AI 도구로 초안 작성 후 실행·검증
-- 전제: 03 1단계(case_times) 먼저 실행

-- 0단계: 미지급 품목의 공급사 × 지출 영역 상위 10
SELECT c.vendor, c.spend_area_text, count(*) AS 미지급품목
FROM case_times t
JOIN cases c ON t.case_id = c.case_id
WHERE t.pay_ts IS NULL
GROUP BY c.vendor, c.spend_area_text
ORDER BY 미지급품목 DESC
LIMIT 10;
-- 결과: 0136 3,705 / 0120 2,915 / 0104 2,473 / 0103 2,040 / 0182 1,943 … → 우선 관리 5곳 중 4곳 상위, 합 10,603 = 23.8%

-- 1단계: 마지막 활동 분포
--   arg_max(activity, ts) = ts가 가장 큰 줄의 activity (MAX는 시각만, arg_max는 그 줄의 다른 칸)
SELECT last_activity, count(*) AS 품목수
FROM (
    SELECT e.case_id, arg_max(e.activity, e.ts) AS last_activity
    FROM events e
    JOIN case_times t ON e.case_id = t.case_id
    WHERE t.pay_ts IS NULL
    GROUP BY e.case_id
)
GROUP BY last_activity
ORDER BY 품목수 DESC;
-- 결과: Record Invoice Receipt 20,734 / Delete PO Item 7,311 / Record GR 7,206 / Remove Payment Block 5,044 / Create PO Item 3,778 / Cancel IR 460 / 그 외 61
-- 분류: 가설 2(삭제·취소) 7,774 (17.4%) / 가설 1(변경) 58 (0.1%) / 나머지 36,762는 시각으로 가름

-- 2단계: 정상 단계에서 멈춘 36,762건의 마지막 시각 (월별)
SELECT strftime(last_ts, '%Y-%m') AS 마지막_월, count(*) AS 품목수
FROM (
    SELECT e.case_id,
           arg_max(e.activity, e.ts) AS last_activity,
           max(e.ts) AS last_ts
    FROM events e
    JOIN case_times t ON e.case_id = t.case_id
    WHERE t.pay_ts IS NULL
    GROUP BY e.case_id
)
WHERE last_activity IN ('Record Invoice Receipt', 'Record Goods Receipt',
                        'Remove Payment Block', 'Create Purchase Order Item')
GROUP BY 마지막_월
ORDER BY 마지막_월;
-- 결과: 2018-01~06 856 / 07~09 2,233 / 10~2019-01 33,673 (91.6%)
-- 결정: 데이터 끝에서 P90(97.9일) 안 = 2018-10 이후를 가설 4(진행 중) 33,673 (75.5%), 그 전은 가설 3(기록 끊김 후보) 3,089 (6.9%)
