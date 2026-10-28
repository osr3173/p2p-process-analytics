-- ①② 데이터 이해 (10/20~21, 직접 작성)
-- DB: data/p2p.duckdb, DBeaver에서 실행

-- 1. 구조 보기
describe cases;
describe events;

SELECT *
from cases
LIMIT 5;

SELECT *
FROM events
ORDER BY ts
LIMIT 5;

-- 2. 행 수 확인
select count(*)
from cases;
-- 결과: 217,406

select count(*)
from events;
-- 결과: 1,214,244 (기대값과 일치)

-- 3. 값 종류 보기
select goods_receipt, gr_based_inv__verif
from cases;
-- 결과: 둘 다 true/false

select activity
from events
group by activity;
-- 결과: 활동 이름 28종

-- 4. 시간 범위
SELECT ts
from events
order by ts;
-- 결과: 1948, 1993, 2001, 2008, 2015~2017년 행이 2018년 앞에 있음

SELECT ts
from events
where ts > '2018-01-01'
order by ts;

SELECT MIN(ts), MAX(ts) FROM events;
-- 결과: 1948-01-27 ~ 2019-01-18

-- 5. 2018년 이전 행 조사
SELECT activity, count(activity)
from events
where ts < '2018-01-01'
group by activity;
-- 결과: Vendor creates invoice 175, Vendor creates debit memo 16, Create Purchase Requisition Item 6 = 197

SELECT case_id
from events
where ts < '2018-01-01';
-- 결과: 197행. case_id = 발주번호(10자리)_품목줄번호(5자리) 구조 확인. 같은 발주서가 여러 줄 반복

-- 6. 품목 1건 흐름
select *
from events
where case_id = '4507000540_00010'
order by ts;
-- 결과: 송장 발행(2017-11-08) → 발주 1/3 → 입고 1/4 → 송장 접수 1/16 → 지급 1/18. 발주→지급 15일. 구매요청 단계 없음

select *
from cases
where case_id like '4507000540%';
-- 결과: 1행 → 이 발주서는 품목 1줄. item_category = "3-way match, invoice before GR" (입고 전에 송장이 먼저 올 수 있는 유형)

select *
from events
where case_id like '4507000540%'
order by ts;
-- 결과: 5행, case_id 1종류 → cases 결과와 일치

-- 정리: 2017-11 송장은 이 품목 유형("입고 전 송장")이면 정상 흐름일 수 있음 [추정].
-- 데이터로는 못 가리므로 오류값이 아니라 이상치 후보로 두고 ②에서 표시만.

-- 7. 1948년 행 확인
select *
from events
where year(ts) = 1948;
-- 결과: 10행 = 발주서 4507004931 품목 5줄 × (송장 + 차변메모). 전부 1948-01-27 07:59

select *
from events
where case_id like '4507004931%'
order by ts;
-- 결과: 55행. 같은 품목 5줄에 2018-01-27 07:59 송장이 따로 있고 월·일·시각·금액 동일 → 1948은 연도 오입력 중복 행 (확인)
-- 흐름: 발주 1/24 → 입고 1/26 → 송장 1/26~27 → 5/7 송장 접수 취소·재등록 → 5/9 지급. 발주→지급 105일, 지연은 송장 처리 구간 (재작업 사례)
-- 품목 _00060은 1948 행 없고 흐름도 다름 (2/23 입고 → 3/15 지급)
