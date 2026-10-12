-- 활동 28종과 건수 → notes/data_understanding.md 6-2절
SELECT activity, count(*) AS n
FROM events
GROUP BY activity
ORDER BY n DESC;
