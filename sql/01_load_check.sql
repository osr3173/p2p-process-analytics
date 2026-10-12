-- 적재 검증: DB 행 수가 원본 XES의 <trace>/<event> 개수와 같은가
-- 기대값 (Zenodo 17295283): cases 217,406 / events 1,214,244
-- 결과 (2026-10-12): 일치 ✅  → notes/data_understanding.md 4절
SELECT
    (SELECT count(*) FROM cases)  AS cases_rows,
    (SELECT count(*) FROM events) AS events_rows;
