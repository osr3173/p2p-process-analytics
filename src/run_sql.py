"""sql/ 파일을 DuckDB에 읽기 전용으로 실행해 결과를 출력한다.

    .venv/bin/python src/run_sql.py sql/04_case_classification.sql [data/p2p.duckdb]

DBeaver가 DB를 쓰기 모드로 열고 있으면 잠금 오류가 난다 → DBeaver 연결을 read-only로.
"""
import sys
from pathlib import Path

import duckdb

sql = Path(sys.argv[1]).read_text()
db = sys.argv[2] if len(sys.argv) > 2 else "data/p2p.duckdb"
print(duckdb.connect(db, read_only=True).sql(sql))
