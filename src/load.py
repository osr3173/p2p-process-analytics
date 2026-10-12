"""BPI Challenge 2019 XES -> DuckDB.

XES 이벤트 로그(728MB)를 스트리밍으로 읽어 cases / events 두 테이블로 적재한다.
trace(구매 발주 품목) 속성은 cases, event(활동) 속성은 events에 들어간다.

    python src/load.py data/raw/BPI_Challenge_2019.xes data/p2p.duckdb
"""
import csv
import json
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import duckdb

VALUE_TAGS = {"string", "date", "float", "int", "boolean", "id"}


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


EVENT_KEYS = ["concept:name", "time:timestamp", "Cumulative net worth (EUR)", "org:resource"]


def parse(xes_path: Path, out_dir: Path) -> tuple[Path, Path]:
    """Stream rows straight to disk: 1.6M events never sit in memory at once."""
    cases_path, events_path = out_dir / "cases.jsonl", out_dir / "events.csv"
    in_event = False
    trace_attrs: dict = {}
    event_attrs: dict = {}
    with open(cases_path, "w") as fc, open(events_path, "w", newline="") as fe:
        w = csv.writer(fe)
        w.writerow(["case_id", *EVENT_KEYS])
        for ev, el in ET.iterparse(xes_path, events=("start", "end")):
            tag = local(el.tag)
            if ev == "start":
                if tag == "trace":
                    trace_attrs = {}
                elif tag == "event":
                    in_event, event_attrs = True, {}
                continue
            if tag in VALUE_TAGS:
                if el.get("key") is not None:
                    (event_attrs if in_event else trace_attrs)[el.get("key")] = el.get("value")
            elif tag == "event":
                in_event = False
                w.writerow([trace_attrs.get("concept:name"), *(event_attrs.get(k) for k in EVENT_KEYS)])
                el.clear()
            elif tag == "trace":
                fc.write(json.dumps(trace_attrs, ensure_ascii=False) + "\n")
                el.clear()
    return cases_path, events_path


def snake(name: str) -> str:
    return "".join(c if c.isalnum() else "_" for c in name.lower()).strip("_")


def load(xes_path: Path, db_path: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        cases_path, events_path = parse(xes_path, Path(tmp))
        con = duckdb.connect(str(db_path))
        # every trace attribute stays VARCHAR; analysis casts what it needs
        con.execute(f"""CREATE OR REPLACE TABLE cases_raw AS SELECT * FROM read_json('{cases_path}',
                        format='newline_delimited', union_by_name=true, sample_size=-1, auto_detect=true)""")
        con.execute(f"CREATE OR REPLACE TABLE events_raw AS SELECT * FROM read_csv('{events_path}', all_varchar=true, header=true)")
        for table in ("cases_raw", "events_raw"):
            cols = [r[0] for r in con.execute(f"DESCRIBE {table}").fetchall()]
            for c in cols:
                if snake(c) != c:
                    con.execute(f'ALTER TABLE {table} RENAME "{c}" TO {snake(c)}')
        con.execute("CREATE OR REPLACE TABLE cases AS SELECT * RENAME (concept_name AS case_id) FROM cases_raw")
        con.execute("""
            CREATE OR REPLACE TABLE events AS
            SELECT case_id,
                   concept_name AS activity,
                   TRY_CAST(time_timestamp AS TIMESTAMPTZ) AS ts,
                   TRY_CAST(cumulative_net_worth__eur AS DOUBLE) AS net_worth_eur,
                   org_resource AS resource
            FROM events_raw""")
        con.execute("DROP TABLE cases_raw; DROP TABLE events_raw")
        n_c, n_e = con.execute("SELECT (SELECT count(*) FROM cases), (SELECT count(*) FROM events)").fetchone()
        print(f"loaded {n_c:,} cases, {n_e:,} events -> {db_path}")
        con.close()


if __name__ == "__main__":
    load(Path(sys.argv[1]), Path(sys.argv[2]))
