"""my_sql/01~06을 순서대로, 연결 하나로, 쿼리마다 결과를 출력한다. (AI 초안 10/26)

    .venv/bin/python src/run_my_sql.py              # 전부
    .venv/bin/python src/run_my_sql.py 03 04 05     # 번호만 골라서

- 연결 하나를 끝까지 쓰므로 03의 case_times, 04의 lead_times(TEMP)가 뒤 파일에서도 살아 있다.
- 읽기 전용으로 연다. DBeaver가 같은 DB를 쓰기 모드로 열고 있으면 잠금 오류 → DBeaver 연결을 끊거나 read-only로.
- 쿼리는 ';'로 나눈다. 주석만 있는 조각은 건너뛴다.
"""
import sys
from pathlib import Path

import duckdb

DB = "data/p2p.duckdb"
SQL_DIR = Path("my_sql")


def statements(text: str):
    """';' 기준으로 나누고, 주석만 남는 조각은 버린다."""
    for chunk in text.split(";"):
        lines = [ln for ln in chunk.splitlines() if ln.strip() and not ln.strip().startswith("--")]
        if lines:
            yield chunk.strip(), lines[0].strip()


def main(prefixes):
    files = sorted(SQL_DIR.glob("*.sql"))
    if prefixes:
        files = [f for f in files if f.name[:2] in prefixes]
    con = duckdb.connect(DB, read_only=True)
    for f in files:
        print(f"\n{'=' * 70}\n# {f.name}\n{'=' * 70}")
        for stmt, head in statements(f.read_text(encoding="utf-8")):
            print(f"\n-- {head}")
            res = con.sql(stmt)
            if res is not None:
                print(res)


if __name__ == "__main__":
    main(sys.argv[1:])
