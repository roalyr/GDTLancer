import hashlib
import html
import json
import os
import sqlite3
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse


DB_FILE = "legends.db"
INTERESTING_AGENT_FIELDS = (
    "agent_role",
    "condition_tag",
    "wealth_tag",
    "cargo_tag",
    "current_sector_id",
    "goal_archetype",
    "rest_ticks_remaining",
    "is_disabled",
    "disabled_at_tick",
    "last_attack_tick",
    "sentiment_tags",
    "dynamic_tags",
)
WORLD_FIELDS = (
    "world_age",
    "world_tags",
    "discovered_sector_count",
    "discovered_sectors",
    "discovery_log",
    "mortal_agent_counter",
    "mortal_agent_deaths",
)
SECTOR_ROOTS = (
    ("sector_tags", "tags"),
    ("grid_dominion", "dominion"),
    ("colony_levels", "colony_level"),
    ("contract_generation_pressure", "generation_pressure"),
    ("contract_cargo_reserved", "cargo_reserved"),
    ("contract_payment_reserved", "payment_reserved"),
    ("contract_cargo_supply", "cargo_supply"),
    ("contract_payment_supply", "payment_supply"),
)
INTERESTING_CONTRACT_FIELDS = (
    "status",
    "claimant_agent_id",
    "source_sector_id",
    "target_sector_id",
    "source_reserved",
    "payment_reserved",
    "cargo_picked_up",
    "required_cargo_tag",
    "reward_credits",
    "completed_at_tick",
)


def connect_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db(conn):
    c = conn.cursor()
    c.executescript(
        """
        DROP TABLE IF EXISTS runs;
        DROP TABLE IF EXISTS snapshots;
        DROP TABLE IF EXISTS events;
        DROP TABLE IF EXISTS mutations;
        DROP TABLE IF EXISTS agents;
        DROP TABLE IF EXISTS sectors;

        CREATE TABLE runs (
            run_id TEXT PRIMARY KEY,
            world_seed TEXT,
            stream_mode TEXT,
            tick_start INTEGER,
            tick_end INTEGER,
            tick_count_requested INTEGER,
            started_record TEXT,
            finished_record TEXT
        );

        CREATE TABLE snapshots (
            run_id TEXT,
            tick INTEGER,
            tick_index INTEGER,
            discovered_sectors INTEGER,
            deaths INTEGER,
            world_age TEXT,
            active_contracts INTEGER,
            chronicle_event_count INTEGER,
            mutation_count INTEGER,
            PRIMARY KEY (run_id, tick)
        );

        CREATE TABLE events (
            run_id TEXT,
            tick INTEGER,
            signature TEXT,
            action TEXT,
            actor_id TEXT,
            target_id TEXT,
            sector_id TEXT,
            data TEXT,
            PRIMARY KEY (run_id, signature)
        );

        CREATE TABLE mutations (
            run_id TEXT,
            tick INTEGER,
            entity_type TEXT,
            entity_id TEXT,
            summary TEXT,
            data TEXT,
            PRIMARY KEY (run_id, tick, entity_type, entity_id)
        );

        CREATE TABLE agents (
            run_id TEXT,
            agent_id TEXT,
            data TEXT,
            PRIMARY KEY (run_id, agent_id)
        );

        CREATE TABLE sectors (
            run_id TEXT,
            sector_id TEXT,
            data TEXT,
            PRIMARY KEY (run_id, sector_id)
        );
        """
    )
    conn.commit()


def stable_json(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def stable_signature(value):
    return hashlib.sha1(stable_json(value).encode("utf-8")).hexdigest()


def pretty_json(value):
    return html.escape(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False))


def short_value(value, limit=120):
    text = json.dumps(value, sort_keys=True, ensure_ascii=False)
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def field_label(field_name):
    return field_name.replace("_", " ")


def changes_to_summary(changes):
    if not changes:
        return ""
    parts = []
    for field_name, delta in sorted(changes.items()):
        before = short_value(delta.get("before"))
        after = short_value(delta.get("after"))
        parts.append(f"{field_label(field_name)}: {before} -> {after}")
    return "; ".join(parts)


def build_change(before, after):
    return {"before": before, "after": after}


def diff_selected_fields(previous, current, field_names):
    changes = {}
    previous = previous or {}
    current = current or {}
    for field_name in field_names:
        before = previous.get(field_name)
        after = current.get(field_name)
        if before != after:
            changes[field_name] = build_change(before, after)
    return changes


def diff_indexed_branch(previous_branch, current_branch, key_field_names=None):
    rows = []
    previous_branch = previous_branch or {}
    current_branch = current_branch or {}
    all_ids = sorted(set(previous_branch.keys()) | set(current_branch.keys()))
    for entity_id in all_ids:
        previous_value = previous_branch.get(entity_id)
        current_value = current_branch.get(entity_id)
        if previous_value == current_value:
            continue
        if previous_value is None:
            changes = {"created": build_change(None, current_value)}
        elif current_value is None:
            changes = {"removed": build_change(previous_value, None)}
        elif key_field_names is None:
            changes = {"value": build_change(previous_value, current_value)}
        else:
            changes = diff_selected_fields(previous_value, current_value, key_field_names)
            if not changes:
                changes = {"value": build_change(previous_value, current_value)}
        rows.append((entity_id, changes))
    return rows


def infer_world_mutation(previous_state, current_state):
    changes = diff_selected_fields(previous_state, current_state, WORLD_FIELDS)
    if not changes:
        return None
    return {
        "entity_type": "world",
        "entity_id": "world",
        "summary": changes_to_summary(changes),
        "data": changes,
    }


def infer_agent_mutations(previous_state, current_state):
    mutations = []
    previous_agents = previous_state.get("agents", {})
    current_agents = current_state.get("agents", {})
    for agent_id, changes in diff_indexed_branch(previous_agents, current_agents, INTERESTING_AGENT_FIELDS):
        mutations.append(
            {
                "entity_type": "agent",
                "entity_id": agent_id,
                "summary": changes_to_summary(changes),
                "data": changes,
            }
        )
    return mutations


def infer_sector_mutations(previous_state, current_state):
    per_sector = {}
    for root_name, label in SECTOR_ROOTS:
        previous_branch = previous_state.get(root_name, {})
        current_branch = current_state.get(root_name, {})
        sector_ids = sorted(set(previous_branch.keys()) | set(current_branch.keys()))
        for sector_id in sector_ids:
            before = previous_branch.get(sector_id)
            after = current_branch.get(sector_id)
            if before == after:
                continue
            per_sector.setdefault(sector_id, {})[label] = build_change(before, after)
    mutations = []
    for sector_id, changes in sorted(per_sector.items()):
        mutations.append(
            {
                "entity_type": "sector",
                "entity_id": sector_id,
                "summary": changes_to_summary(changes),
                "data": changes,
            }
        )
    return mutations


def infer_contract_mutations(previous_state, current_state):
    mutations = []
    previous_contracts = previous_state.get("runtime_contract_occurrences", {})
    current_contracts = current_state.get("runtime_contract_occurrences", {})
    for occurrence_id, changes in diff_indexed_branch(previous_contracts, current_contracts, INTERESTING_CONTRACT_FIELDS):
        mutations.append(
            {
                "entity_type": "contract",
                "entity_id": occurrence_id,
                "summary": changes_to_summary(changes),
                "data": changes,
            }
        )
    return mutations


def infer_tick_mutations(previous_state, current_state):
    if not previous_state:
        return []
    mutations = []
    world_mutation = infer_world_mutation(previous_state, current_state)
    if world_mutation is not None:
        mutations.append(world_mutation)
    mutations.extend(infer_agent_mutations(previous_state, current_state))
    mutations.extend(infer_sector_mutations(previous_state, current_state))
    mutations.extend(infer_contract_mutations(previous_state, current_state))
    return mutations


def sector_snapshot(game_state, sector_id):
    snapshot = {}
    for root_name, label in SECTOR_ROOTS:
        value = game_state.get(root_name, {}).get(sector_id)
        if value is not None:
            snapshot[label] = value
    return snapshot


def upsert_run(c, record):
    run_id = record.get("run_id") or "unknown"
    c.execute(
        """
        INSERT INTO runs (run_id, world_seed, stream_mode, tick_start, tick_end, tick_count_requested, started_record, finished_record)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(run_id) DO UPDATE SET
            world_seed = excluded.world_seed,
            stream_mode = excluded.stream_mode,
            tick_start = COALESCE(runs.tick_start, excluded.tick_start),
            tick_end = COALESCE(excluded.tick_end, runs.tick_end),
            tick_count_requested = COALESCE(excluded.tick_count_requested, runs.tick_count_requested),
            started_record = COALESCE(excluded.started_record, runs.started_record),
            finished_record = COALESCE(excluded.finished_record, runs.finished_record)
        """,
        (
            run_id,
            record.get("world_seed"),
            record.get("stream_mode"),
            record.get("tick_start"),
            record.get("tick_end"),
            record.get("tick_count_requested"),
            stable_json(record) if record.get("record_type") == "run_started" else None,
            stable_json(record) if record.get("record_type") == "run_finished" else None,
        ),
    )
    return run_id


def upsert_snapshot(c, run_id, record, mutation_count):
    game_state = record.get("game_state") or {}
    discovered_sectors = game_state.get("discovered_sectors") or []
    deaths = game_state.get("mortal_agent_deaths") or []
    c.execute(
        """
        INSERT OR REPLACE INTO snapshots
        (run_id, tick, tick_index, discovered_sectors, deaths, world_age, active_contracts, chronicle_event_count, mutation_count)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            run_id,
            safe_int(record.get("sim_tick")),
            safe_int(record.get("tick_index")),
            len(discovered_sectors) if isinstance(discovered_sectors, list) else safe_int(game_state.get("discovered_sector_count")),
            len(deaths) if isinstance(deaths, list) else safe_int(deaths),
            game_state.get("world_age"),
            len(game_state.get("runtime_contract_occurrences") or {}),
            len(game_state.get("chronicle_events") or []),
            mutation_count,
        ),
    )


def insert_events(c, run_id, tick, events):
    for chronicle_index, event in enumerate(events):
        metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
        target_id = metadata.get("target")
        signature = stable_signature({
            "chronicle_index": chronicle_index,
            "event": event,
        })
        c.execute(
            """
            INSERT OR IGNORE INTO events
            (run_id, tick, signature, action, actor_id, target_id, sector_id, data)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                tick,
                signature,
                event.get("action"),
                event.get("actor_id"),
                target_id,
                event.get("sector_id"),
                stable_json(event),
            ),
        )


def insert_mutations(c, run_id, tick, mutations):
    for mutation in mutations:
        c.execute(
            """
            INSERT OR REPLACE INTO mutations
            (run_id, tick, entity_type, entity_id, summary, data)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                tick,
                mutation["entity_type"],
                mutation["entity_id"],
                mutation["summary"],
                stable_json(mutation["data"]),
            ),
        )


def upsert_latest_state(c, run_id, game_state):
    for agent_id, agent_data in (game_state.get("agents") or {}).items():
        c.execute(
            "INSERT OR REPLACE INTO agents (run_id, agent_id, data) VALUES (?, ?, ?)",
            (run_id, agent_id, stable_json(agent_data)),
        )

    sector_ids = set()
    for root_name, _label in SECTOR_ROOTS:
        sector_ids.update((game_state.get(root_name) or {}).keys())
    for sector_id in sorted(sector_ids):
        c.execute(
            "INSERT OR REPLACE INTO sectors (run_id, sector_id, data) VALUES (?, ?, ?)",
            (run_id, sector_id, stable_json(sector_snapshot(game_state, sector_id))),
        )


def parse_log(filepath):
    conn = connect_db()
    init_db(conn)
    c = conn.cursor()
    previous_state_by_run = {}

    with open(filepath, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line.startswith("{"):
                continue

            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            record_type = record.get("record_type")
            if record_type == "run_started":
                run_id = upsert_run(c, record)
                previous_state_by_run[run_id] = None
                continue

            if record_type == "run_finished":
                upsert_run(c, record)
                continue

            if record_type != "tick_snapshot":
                continue

            run_id = record.get("run_id") or "unknown"
            if run_id not in previous_state_by_run:
                upsert_run(
                    c,
                    {
                        "record_type": "run_started",
                        "run_id": run_id,
                        "world_seed": record.get("world_seed"),
                        "stream_mode": record.get("stream_mode"),
                        "tick_start": record.get("sim_tick"),
                        "tick_count_requested": None,
                    },
                )
                previous_state_by_run[run_id] = None

            tick = safe_int(record.get("sim_tick"))
            game_state = record.get("game_state") if isinstance(record.get("game_state"), dict) else {}
            mutations = infer_tick_mutations(previous_state_by_run.get(run_id), game_state)
            upsert_snapshot(c, run_id, record, len(mutations))
            insert_events(c, run_id, tick, game_state.get("chronicle_events") or [])
            insert_mutations(c, run_id, tick, mutations)
            upsert_latest_state(c, run_id, game_state)
            previous_state_by_run[run_id] = game_state

    conn.commit()
    conn.close()


def format_event(event_data):
    action = event_data.get("action", "unknown")
    actor = html.escape(str(event_data.get("actor_id", "Someone")))
    sector = html.escape(str(event_data.get("sector_id", "unknown sector")))
    metadata = event_data.get("metadata") if isinstance(event_data.get("metadata"), dict) else {}
    target = html.escape(str(metadata.get("target", "someone")))

    if action == "move":
        source = html.escape(str(metadata.get("from", "unknown")))
        return f"<span class='event-move'><b>{actor}</b> moved from <i>{source}</i> to <i>{sector}</i>.</span>"
    if action == "attack":
        return f"<span class='event-attack'><b>{actor}</b> attacked <b>{target}</b> in <i>{sector}</i>.</span>"
    if action == "dock":
        return f"<span class='event-dock'><b>{actor}</b> docked at <i>{sector}</i>.</span>"
    if action == "agent_trade":
        return f"<span class='event-trade'><b>{actor}</b> traded with <b>{target}</b> in <i>{sector}</i>.</span>"
    if action == "expedition_failed":
        reason = html.escape(str(metadata.get("reason", "unknown")))
        return f"<span class='event-fail'><b>{actor}</b> failed an expedition in <i>{sector}</i> (reason: {reason}).</span>"
    return (
        f"<span class='event-default'><b>{actor}</b> performed '{html.escape(str(action))}' "
        f"in <i>{sector}</i>.</span>"
    )


def mutation_badge(entity_type):
    return f"<span class='badge badge-{html.escape(entity_type)}'>{html.escape(entity_type)}</span>"


def mutation_html(mutation_row):
    data = json.loads(mutation_row["data"])
    entity_type = mutation_row["entity_type"]
    entity_id = mutation_row["entity_id"]
    summary = mutation_row["summary"] or changes_to_summary(data)
    return (
        f"<div class='mutation-entry'>{mutation_badge(entity_type)} "
        f"<b>{html.escape(entity_id)}</b>: {html.escape(summary)}"
        f"<details><summary>View diff</summary><pre>{pretty_json(data)}</pre></details></div>"
    )


def page_shell(title, body):
    return f"""
    <html>
    <head>
        <title>{html.escape(title)}</title>
        <style>
            body {{ font-family: monospace; background: #181a1f; color: #d7dae0; padding: 20px; line-height: 1.45; }}
            a {{ color: #79c0ff; text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            h1, h2, h3 {{ margin-bottom: 0.4em; }}
            table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
            th, td {{ border: 1px solid #3a3f4b; padding: 10px; text-align: left; vertical-align: top; }}
            th {{ background: #242833; }}
            .nav {{ margin-bottom: 24px; padding-bottom: 12px; border-bottom: 1px solid #3a3f4b; }}
            .nav a {{ margin-right: 12px; }}
            .hint {{ color: #9da5b4; max-width: 90ch; }}
            .badge {{ display: inline-block; padding: 1px 6px; border-radius: 10px; font-size: 0.9em; margin-right: 6px; }}
            .badge-agent {{ background: #1f6feb33; color: #79c0ff; }}
            .badge-sector {{ background: #2ea04333; color: #7ee787; }}
            .badge-contract {{ background: #d2992233; color: #e3b341; }}
            .badge-world {{ background: #8957e533; color: #d2a8ff; }}
            .mutation-entry {{ margin-bottom: 8px; }}
            details {{ margin-top: 6px; }}
            pre {{ white-space: pre-wrap; word-break: break-word; margin: 8px 0 0; }}
            ul {{ margin: 6px 0; padding-left: 18px; }}
            .event-move {{ color: #79c0ff; }}
            .event-attack {{ color: #ff7b72; }}
            .event-dock {{ color: #7ee787; }}
            .event-trade {{ color: #e3b341; }}
            .event-fail {{ color: #ffa657; }}
            .event-default {{ color: #d7dae0; }}
        </style>
    </head>
    <body>
        <div class='nav'>
            <h1>Legends Browser</h1>
            <a href='/'>Home</a>
            <a href='/snapshots'>Snapshots</a>
            <a href='/events'>Chronicle Events</a>
            <a href='/mutations'>Mutations</a>
            <a href='/agents'>Agents</a>
            <a href='/sectors'>Sectors</a>
        </div>
        {body}
    </body>
    </html>
    """


class LegendsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        conn = connect_db()
        c = conn.cursor()
        path = urlparse(self.path).path

        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        if path == "/snapshots":
            c.execute(
                """
                SELECT run_id, tick, tick_index, discovered_sectors, deaths, world_age, active_contracts, chronicle_event_count, mutation_count
                FROM snapshots
                ORDER BY run_id ASC, tick ASC
                """
            )
            rows = c.fetchall()
            body = [
                "<h2>Timeline Snapshots</h2>",
                "<p class='hint'>Each row is a full raw snapshot summary. Mutation count is inferred from changed state between adjacent snapshots in the same run.</p>",
                "<table><tr><th>Run</th><th>Tick</th><th>Summary</th></tr>",
            ]
            for row in rows:
                summary = (
                    f"tick_index={row['tick_index']} | world_age={html.escape(str(row['world_age']))} | "
                    f"discovered={row['discovered_sectors']} | deaths={row['deaths']} | "
                    f"active_contracts={row['active_contracts']} | chronicle_events={row['chronicle_event_count']} | "
                    f"mutations={row['mutation_count']}"
                )
                body.append(
                    f"<tr><td>{html.escape(row['run_id'])}</td><td>{row['tick']}</td><td>{summary}</td></tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        elif path == "/events":
            c.execute(
                """
                SELECT run_id, tick, action, actor_id, target_id, sector_id, data
                FROM events
                ORDER BY run_id ASC, tick ASC
                """
            )
            rows = c.fetchall()
            body = [
                "<h2>Chronicle Events</h2>",
                "<p class='hint'>Related mutations are inferred from the same tick. They show what changed on that tick for the actor, target, touched sector, or world state; they do not claim perfect causal attribution yet.</p>",
                "<table><tr><th>Tick</th><th>Event</th><th>Observed Mutations</th><th>Raw JSON</th></tr>",
            ]
            for row in rows:
                event_data = json.loads(row["data"])
                params = [row["run_id"], row["tick"], row["actor_id"] or "", row["target_id"] or "", row["sector_id"] or ""]
                c.execute(
                    """
                    SELECT entity_type, entity_id, summary, data
                    FROM mutations
                    WHERE run_id = ? AND tick = ? AND (
                        (entity_type = 'agent' AND entity_id IN (?, ?)) OR
                        (entity_type = 'sector' AND entity_id = ?) OR
                        entity_type = 'world'
                    )
                    ORDER BY CASE entity_type
                        WHEN 'agent' THEN 0
                        WHEN 'sector' THEN 1
                        WHEN 'contract' THEN 2
                        WHEN 'world' THEN 3
                        ELSE 4
                    END, entity_id ASC
                    """,
                    params,
                )
                related = c.fetchall()
                if related:
                    mutation_block = "".join(mutation_html(mutation_row) for mutation_row in related)
                else:
                    mutation_block = "<i>No same-tick mutation summary matched this event.</i>"
                body.append(
                    "<tr>"
                    f"<td>{row['tick']}<br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{format_event(event_data)}</td>"
                    f"<td>{mutation_block}</td>"
                    f"<td><details><summary>View Data</summary><pre>{pretty_json(event_data)}</pre></details></td>"
                    "</tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        elif path == "/mutations":
            c.execute(
                """
                SELECT run_id, tick, entity_type, entity_id, summary, data
                FROM mutations
                ORDER BY run_id ASC, tick ASC, entity_type ASC, entity_id ASC
                """
            )
            rows = c.fetchall()
            body = [
                "<h2>Mutations</h2>",
                "<p class='hint'>These rows are inferred from diffs between adjacent snapshots in the same run. They are already useful for browsing current logs, and the table is ready to display future explicit runtime mutation records when the logger grows that task.</p>",
                "<table><tr><th>Tick</th><th>Entity</th><th>Summary</th><th>Diff</th></tr>",
            ]
            for row in rows:
                body.append(
                    "<tr>"
                    f"<td>{row['tick']}<br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{mutation_badge(row['entity_type'])}<b>{html.escape(row['entity_id'])}</b></td>"
                    f"<td>{html.escape(row['summary'])}</td>"
                    f"<td><details><summary>View diff</summary><pre>{pretty_json(json.loads(row['data']))}</pre></details></td>"
                    "</tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        elif path == "/agents":
            c.execute("SELECT run_id, agent_id, data FROM agents ORDER BY run_id ASC, agent_id ASC")
            rows = c.fetchall()
            body = [
                "<h2>Agents</h2>",
                "<table><tr><th>Agent</th><th>Latest State</th><th>Mutation History</th><th>Raw JSON</th></tr>",
            ]
            for row in rows:
                agent_data = json.loads(row["data"])
                latest = (
                    f"role={html.escape(str(agent_data.get('agent_role', 'unknown')))}<br>"
                    f"condition={html.escape(str(agent_data.get('condition_tag', 'unknown')))}<br>"
                    f"wealth={html.escape(str(agent_data.get('wealth_tag', 'unknown')))}<br>"
                    f"cargo={html.escape(str(agent_data.get('cargo_tag', 'unknown')))}<br>"
                    f"sector={html.escape(str(agent_data.get('current_sector_id', 'unknown')))}"
                )
                c.execute(
                    """
                    SELECT tick, entity_type, entity_id, summary, data
                    FROM mutations
                    WHERE run_id = ? AND entity_type = 'agent' AND entity_id = ?
                    ORDER BY tick ASC
                    """,
                    (row["run_id"], row["agent_id"]),
                )
                mutation_rows = c.fetchall()
                if mutation_rows:
                    mutation_block = "".join(
                        f"<div class='mutation-entry'>[tick {mutation_row['tick']}] {mutation_html(mutation_row)}</div>"
                        for mutation_row in mutation_rows
                    )
                else:
                    mutation_block = "<i>No inferred mutations recorded.</i>"
                body.append(
                    "<tr>"
                    f"<td><b>{html.escape(row['agent_id'])}</b><br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{latest}</td>"
                    f"<td>{mutation_block}</td>"
                    f"<td><details><summary>View Data</summary><pre>{pretty_json(agent_data)}</pre></details></td>"
                    "</tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        elif path == "/sectors":
            c.execute("SELECT run_id, sector_id, data FROM sectors ORDER BY run_id ASC, sector_id ASC")
            rows = c.fetchall()
            body = [
                "<h2>Sectors</h2>",
                "<table><tr><th>Sector</th><th>Latest State</th><th>Mutation History</th><th>Raw JSON</th></tr>",
            ]
            for row in rows:
                sector_data = json.loads(row["data"])
                latest_lines = []
                for key, value in sector_data.items():
                    latest_lines.append(f"<b>{html.escape(key)}</b>: {html.escape(short_value(value, 220))}")
                latest = "<br>".join(latest_lines) if latest_lines else "<i>No sector state captured.</i>"
                c.execute(
                    """
                    SELECT tick, entity_type, entity_id, summary, data
                    FROM mutations
                    WHERE run_id = ? AND entity_type = 'sector' AND entity_id = ?
                    ORDER BY tick ASC
                    """,
                    (row["run_id"], row["sector_id"]),
                )
                mutation_rows = c.fetchall()
                if mutation_rows:
                    mutation_block = "".join(
                        f"<div class='mutation-entry'>[tick {mutation_row['tick']}] {mutation_html(mutation_row)}</div>"
                        for mutation_row in mutation_rows
                    )
                else:
                    mutation_block = "<i>No inferred sector mutations recorded.</i>"
                body.append(
                    "<tr>"
                    f"<td><b>{html.escape(row['sector_id'])}</b><br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{latest}</td>"
                    f"<td>{mutation_block}</td>"
                    f"<td><details><summary>View Data</summary><pre>{pretty_json(sector_data)}</pre></details></td>"
                    "</tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        else:
            c.execute(
                """
                SELECT run_id, stream_mode, tick_start, tick_end,
                       (SELECT COUNT(*) FROM snapshots WHERE snapshots.run_id = runs.run_id) AS snapshot_count,
                       (SELECT COUNT(*) FROM events WHERE events.run_id = runs.run_id) AS event_count,
                       (SELECT COUNT(*) FROM mutations WHERE mutations.run_id = runs.run_id) AS mutation_count
                FROM runs
                ORDER BY run_id ASC
                """
            )
            rows = c.fetchall()
            body = [
                "<h2>Runs</h2>",
                "<p class='hint'>This browser keeps the raw snapshots intact and derives readable same-tick mutations from adjacent snapshots. That gives you an interim outcome view today while the runtime-side explicit mutation task remains pending.</p>",
                "<table><tr><th>Run</th><th>Mode</th><th>Range</th><th>Counts</th></tr>",
            ]
            for row in rows:
                body.append(
                    "<tr>"
                    f"<td>{html.escape(row['run_id'])}</td>"
                    f"<td>{html.escape(str(row['stream_mode']))}</td>"
                    f"<td>{row['tick_start']} -> {row['tick_end']}</td>"
                    f"<td>snapshots={row['snapshot_count']} | events={row['event_count']} | mutations={row['mutation_count']}</td>"
                    "</tr>"
                )
            body.append("</table>")
            html_body = "".join(body)

        self.wfile.write(page_shell("Legends Browser", html_body).encode("utf-8"))
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python log_browser.py <path_to_log.txt>")
        sys.exit(1)

    if DB_FILE != ":memory:" and os.path.exists(DB_FILE):
        os.remove(DB_FILE)

    print("Parsing log stream to SQLite database...")
    parse_log(sys.argv[1])

    port = 8080
    server = HTTPServer(("localhost", port), LegendsHandler)
    print(f"Database ready. Web interface running at: http://localhost:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
