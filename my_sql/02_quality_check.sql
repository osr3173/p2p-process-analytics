-- ② 품질 점검: 키 확인 (10/21, 직접 작성)
-- 목적: cases.case_id가 PK, events.case_id가 FK로 쓸 수 있는지
-- DB에는 PK·FK 제약이 설정돼 있지 않아서 데이터로 직접 확인

-- 1. cases.case_id 중복 확인
--    전체 행 수와 서로 다른 case_id 수가 같으면 중복 없음
select count(*)
from cases;
-- 결과: 217,406

select count(distinct case_id)
from cases;
-- 결과: 217,406 → 중복 없음, PK로 사용 가능

-- 2. events에는 있는데 cases에 없는 case_id (짝 없는 활동)
--    events 기준 LEFT JOIN → cases 쪽이 NULL인 행 = 짝 없는 활동
SELECT count(*)
FROM events E
LEFT JOIN cases C ON E.case_id = C.case_id
WHERE C.case_id IS NULL;
-- 결과: 0 → 모든 활동이 품목에 연결됨, FK로 사용 가능

-- 3. cases에는 있는데 events에 활동이 없는 품목
--    cases 기준 LEFT JOIN → events 쪽이 NULL인 행 = 활동 없는 품목
SELECT count(*)
FROM cases C
LEFT JOIN events E ON C.case_id = E.case_id
WHERE E.case_id IS NULL;
-- 결과: 0 → 모든 품목에 활동이 최소 1개

-- 결론: cases 1 : events N 관계가 데이터상 깨진 곳 없음

-- 4. item_category 종류별 품목 수
select item_category, count(*)
from cases
group by item_category
order by count(*) DESC;
-- 결과: "3-way match, invoice before GR" 217,406 → 1종류뿐
-- 원인: 원본을 못 받아 Zenodo 부분집합(before GR 표준 PO만, 원본의 86.36%)을 적재함 (PROJECT_BRIEF.md 45~46줄)
-- 영향: 방식 간 비교 불가. 분석 범위 = 이 방식 안에서 단계별 지연. 보고서에 한계로 기록

-- 5. 두 플래그 조합별 품목 수
select goods_receipt, gr_based_inv__verif, count(*)
from cases
group by goods_receipt, gr_based_inv__verif
order by count(*) DESC;
-- 결과: true / false 217,406 → 1조합뿐
-- 해석: 입고 확인은 필요, 입고 수량 기준 송장 검사는 안 함 = 설명서의 before GR 조합과 일치

-- 6. 결측 확인
-- 원리: COUNT(*) = 전체 행, COUNT(컬럼) = NULL 아닌 행 → 뺀 값이 NULL 개수

-- 6-1. events 5개 컬럼
select count(*)-count(case_id), count(*)-count(activity), count(*)-count(net_worth_eur), count(*)-count(resource), count(*)-count(ts)
from events;
-- 결과: 0, 0, 0, 0, 0 → NULL 없음

-- 6-2. resource의 'NONE' = 글자로 채워진 숨은 결측 (설명서: 사용자 미기록)
select count(*)
from events
where resource = 'NONE';
-- 결과: 215,245 (전체 1,214,244의 17.7%)

-- 6-3. 'NONE'이 어떤 활동에 붙어 있나
select activity, count(*)
from events
where resource = 'NONE'
group by activity
order by count(*) desc;
-- 결과: Vendor creates invoice 202,293 / Clear Invoice 7,455 / Vendor creates debit memo 5,497
-- 해석: 공급사 활동(96.5%)은 담당자가 없는 게 정상. Clear Invoice 7,455건은 자동(배치) 처리 가능성 [추정]
-- 영향: 담당자별 분석에서는 제외. 소요일 계산에는 영향 없음

-- 6-4. cases 8개 컬럼 (분석에 쓰는 것만)
select count(*)-count(case_id), count(*)-count(purchasing_document), count(*)-count(item), count(*)-count(vendor), count(*)-count(name), count(*)-count(item_type), count(*)-count(document_type), count(*)-count(company)
from cases;
-- 결과: 전부 0 → NULL 없음

-- 7. 오류값 확인: 2018년 이전 ts 행 197건 (01 파일 5번에서 활동별 집계)
-- 1948년은 01 파일 7번에서 확인: 발주서 4507004931, 2018-01-27 같은 시각 송장이 따로 있음 → 중복

-- 7-1. 1993년
select ts, case_id, activity
from events
where year(ts) = 1993;
-- 결과: 9행, 발주서 4507014062 품목 9줄, 전부 Vendor creates invoice, 1993-05-19 06:59

select ts, case_id, activity
from events
where case_id like '4507014062%'
order by case_id, ts;
-- 결과: 품목 9줄 모두 송장(1993) → 발주 3/5 → 입고 3/5 → 송장 접수 3/19 → 지급 4/12
-- 2018년 송장 발행 행 없음 → 단독 오류값. 올바른 날짜 추정 불가 (2018-05-19는 지급 4/12보다 뒤)

-- 7-2. 2008년
select ts, case_id, activity
from events
where year(ts) = 2008;
-- 결과: 33행, 발주서 4507037128 품목 33줄, 전부 Vendor creates invoice, 2008-06-20 06:59

select ts, case_id
from events
where case_id like '4507037128%' and activity = 'Vendor creates invoice'
order by case_id, ts;
-- 결과: 31줄은 2008 송장만(단독), _00070은 2008 + 2018-07-04(월·일 다름, 중복 아님), _00360은 2018 송장 3개만(정상)

-- 7-3. 2017년 구매요청 6건 (우리 회사 활동이라 공급사 규칙에 안 걸림)
select ts, case_id
from events
where ts < '2018-01-01' and activity = 'Create Purchase Requisition Item'
order by ts;
-- 결과: 2017-02-04 ×2, 2017-12-07, 2017-12-31 ×3 → 전부 2017년. 연말 요청 후 해 넘겨 발주 = 정상
-- 2월 2건은 요청→발주 약 1년이라 이상치 후보

-- 7-4. 확정 규칙
-- (1) 공급사 활동(Vendor creates invoice·debit memo)의 ts < 2018-01-01 → 날짜 신뢰 불가 표시, 소요일 계산 제외 (191건)
--     패턴은 기록에 남김: 중복(1948) / 단독(1993·2008) / 2017년 말(정상일 수 있음)
-- (2) 구매요청 2017년 6건 → 정상 유지, 2월 2건은 간격 긴 것으로 표시
-- (3) 197 = 191 + 6, 그 외 2018년 이전 행 없음
-- ④ 소요일은 발주 생성→입고→송장 접수→지급으로 재므로 공급사 송장 발행 날짜는 어느 구간에도 안 들어감 → 이 규칙이 결과에 영향 없음
-- 단, 나중에 "품목당 송장 횟수"를 세면 1948 중복 행만 따로 제거

-- 8. 중복 확인: events에서 case_id·activity·ts가 완전히 같은 행
-- 세 컬럼 조합으로 묶고, 묶음 안 행이 2개 이상인 것만 (묶은 뒤 조건 → HAVING)
select case_id, activity, ts
from events
group by case_id, activity, ts
having count(*) >= 2;
-- 결과: DBeaver는 처음 200행만 보여 줌. 대부분 Record Goods Receipt, 그다음 Clear Invoice·Change Quantity

-- 전체 개수: 위 쿼리를 괄호로 감싸 행 수 세기 (서브쿼리)
select count(*)
from (
select case_id, activity, ts
from events
group by case_id, activity, ts
having count(*) >= 2);
-- 결과: 1,384묶음 (최소 2,768행, 전체의 약 0.2%)

-- 하나 골라 확인
select *
from events
where case_id = '4507008001_00020'
order by ts;
-- 결과: 2018-03-19 20:37 입고 2행이 금액(1426.0)·담당자(user_061)까지 완전히 같음
-- 그런데 금액은 모든 활동에 같은 값(품목 금액) → 입고 수량이 없어서 진짜 중복인지 분할 입고인지 구분 불가 [미확인]
-- 영향: 시각이 같아 소요일에는 영향 없음. 활동 횟수를 셀 때만 주의
