-- 품목 10건의 활동 흐름(variant) 맛보기 → notes/data_understanding.md 2절
SELECT case_id,
       string_agg(activity, ' → ' ORDER BY ts) AS flow
FROM events
WHERE case_id IN (SELECT case_id FROM cases LIMIT 10)
GROUP BY case_id;
