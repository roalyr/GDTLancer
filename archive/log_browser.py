import hashlib
import html
import json
import os
import sqlite3
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlencode, urlparse


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
PAGE_SNAPSHOT_LIMIT = 200
PAGE_EVENT_LIMIT = 200
PAGE_MUTATION_LIMIT = 300
PAGE_AGENT_LIMIT = 80
PAGE_SECTOR_LIMIT = 80
RELATED_MUTATION_LIMIT = 5
ENTITY_HISTORY_LIMIT = 6
DETAIL_CHANGE_LIMIT = 40
DETAIL_EVENT_LIMIT = 40


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


def readable_value(value, depth=0):
    if value is None:
        return "none"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if depth >= 2:
        return short_value(value, 80)
    if isinstance(value, list):
        if not value:
            return "none"
        rendered = [readable_value(item, depth + 1) for item in value[:4]]
        text = ", ".join(rendered)
        if len(value) > 4:
            text += f", +{len(value) - 4} more"
        return text
    if isinstance(value, dict):
        if not value:
            return "none"
        rendered = []
        items = list(value.items())
        for key, item in items[:3]:
            rendered.append(f"{field_label(str(key))}: {readable_value(item, depth + 1)}")
        text = "; ".join(rendered)
        if len(items) > 3:
            text += f"; +{len(items) - 3} more"
        return text
    return str(value)


def summary_list_html(pairs, empty_text="Nothing captured."):
    items = []
    for label, value in pairs:
        if value in (None, "", "none"):
            continue
        items.append(
            f"<li><b>{html.escape(label)}</b>: {html.escape(str(value))}</li>"
        )
    if not items:
        return f"<span class='muted'><i>{html.escape(empty_text)}</i></span>"
    return "<ul class='compact-list'>" + "".join(items) + "</ul>"


def run_range_text(row):
    start_tick = row["tick_start"]
    latest_tick = row["latest_tick"]
    if start_tick is None and latest_tick is None:
        return "unknown"
    if latest_tick is None or latest_tick == start_tick:
        return f"t{start_tick}"
    return f"t{start_tick} -> t{latest_tick}"


def snapshot_summary(row):
    parts = [
        f"age {row['world_age'] or 'unknown'}",
        f"{row['discovered_sectors']} discovered",
        f"{row['active_contracts']} active contracts",
        f"{row['chronicle_event_count']} events",
        f"{row['mutation_count']} changes",
    ]
    if row["deaths"]:
        parts.append(f"{row['deaths']} deaths")
    return " | ".join(parts)


def agent_state_summary_html(agent_data):
    pairs = [
        ("role", readable_value(agent_data.get("agent_role"))),
        ("condition", readable_value(agent_data.get("condition_tag"))),
        ("wealth", readable_value(agent_data.get("wealth_tag"))),
        ("cargo", readable_value(agent_data.get("cargo_tag"))),
        ("sector", readable_value(agent_data.get("current_sector_id"))),
        ("goal", readable_value(agent_data.get("goal_archetype"))),
    ]
    if agent_data.get("rest_ticks_remaining"):
        pairs.append(("rest ticks", readable_value(agent_data.get("rest_ticks_remaining"))))
    if agent_data.get("is_disabled"):
        pairs.append(("disabled", "yes"))
    if agent_data.get("sentiment_tags"):
        pairs.append(("sentiment", readable_value(agent_data.get("sentiment_tags"))))
    if agent_data.get("dynamic_tags"):
        pairs.append(("dynamic", readable_value(agent_data.get("dynamic_tags"))))
    return summary_list_html(pairs, "No agent state captured.")


def sector_state_summary_html(sector_data):
    dominion = sector_data.get("dominion") if isinstance(sector_data.get("dominion"), dict) else {}
    pairs = [
        ("security", readable_value(dominion.get("security_tag"))),
        ("colony", readable_value(sector_data.get("colony_level"))),
        ("tags", readable_value(sector_data.get("tags"))),
        ("contract pressure", readable_value(sector_data.get("generation_pressure"))),
        ("cargo supply", readable_value(sector_data.get("cargo_supply"))),
        ("payment supply", readable_value(sector_data.get("payment_supply"))),
    ]
    return summary_list_html(pairs, "No sector state captured.")


def mutation_line_html(mutation_row, include_tick=False):
    entity_type = mutation_row["entity_type"]
    entity_id = mutation_row["entity_id"]
    summary = mutation_row["summary"]
    prefix = ""
    if include_tick:
        prefix = f"<span class='tick-pill'>t{mutation_row['tick']}</span> "
    return (
        f"<li>{prefix}{mutation_badge(entity_type)} <b>{html.escape(entity_id)}</b>: "
        f"{html.escape(summary)}</li>"
    )


def mutation_list_html(rows, limit, empty_text, include_tick=False):
    if not rows:
        return f"<span class='muted'><i>{html.escape(empty_text)}</i></span>"
    shown_rows = rows[:limit]
    items = [mutation_line_html(row, include_tick=include_tick) for row in shown_rows]
    hidden_count = len(rows) - len(shown_rows)
    if hidden_count > 0:
        items.append(f"<li class='muted'>+{hidden_count} more changes not shown.</li>")
    return "<ul class='compact-list'>" + "".join(items) + "</ul>"


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


def query_value(query, key, default=""):
    values = query.get(key)
    if not values:
        return default
    return values[0]


def query_page(query, key="page", default=1):
    return max(1, safe_int(query_value(query, key, default), default))


def total_pages(total_count, per_page):
    if per_page <= 0:
        return 1
    return max(1, (total_count + per_page - 1) // per_page)


def clamp_page(page, total_count, per_page):
    return min(max(1, page), total_pages(total_count, per_page))


def page_offset(page, per_page):
    return max(0, (page - 1) * per_page)


def build_url(path, params=None):
    filtered = {}
    for key, value in (params or {}).items():
        if value in (None, ""):
            continue
        filtered[key] = value
    query_string = urlencode(filtered)
    if not query_string:
        return path
    return f"{path}?{query_string}"


def pagination_html(path, current_page, per_page, total_count, base_params=None, param_name="page"):
    total_page_count = total_pages(total_count, per_page)
    if total_page_count <= 1:
        return ""

    current_page = clamp_page(current_page, total_count, per_page)
    base_params = dict(base_params or {})
    links = []

    def link_html(label, page_number, current=False):
        if current:
            return f"<span class='current-page'>{html.escape(str(label))}</span>"
        params = dict(base_params)
        params[param_name] = page_number
        return f"<a class='page-link' href='{html.escape(build_url(path, params))}'>{html.escape(str(label))}</a>"

    if current_page > 1:
        links.append(link_html("First", 1))
        links.append(link_html("Prev", current_page - 1))

    start_page = max(1, current_page - 2)
    end_page = min(total_page_count, current_page + 2)
    if start_page > 1:
        links.append("<span class='muted'>...</span>")

    for page_number in range(start_page, end_page + 1):
        links.append(link_html(page_number, page_number, current=page_number == current_page))

    if end_page < total_page_count:
        links.append("<span class='muted'>...</span>")

    if current_page < total_page_count:
        links.append(link_html("Next", current_page + 1))
        links.append(link_html("Last", total_page_count))

    return (
        "<div class='pagination'>"
        f"<span class='muted'>Page {current_page} of {total_page_count} ({total_count} items)</span>"
        + "".join(links)
        + "</div>"
    )


def fetch_related_mutations(c, run_id, tick, actor_id, target_id, sector_id, limit):
    c.execute(
        """
        SELECT entity_type, entity_id, summary, data, tick
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
        LIMIT ?
        """,
        [run_id, tick, actor_id or "", target_id or "", sector_id or "", limit],
    )
    return c.fetchall()


def event_list_html(c, rows, empty_text, related_limit=RELATED_MUTATION_LIMIT):
    if not rows:
        return f"<span class='muted'><i>{html.escape(empty_text)}</i></span>"

    items = []
    for row in rows:
        event_data = json.loads(row["data"])
        related_rows = fetch_related_mutations(
            c,
            row["run_id"],
            row["tick"],
            row["actor_id"],
            row["target_id"],
            row["sector_id"],
            related_limit + 1,
        )
        items.append(
            "<li class='history-entry'>"
            f"<div><span class='tick-pill'>t{row['tick']}</span>{format_event(event_data)}</div>"
            f"<div class='history-outcome'>{mutation_list_html(related_rows, related_limit, 'No same-tick outcome matched this event.')}</div>"
            "</li>"
        )
    return "<ul class='history-list'>" + "".join(items) + "</ul>"


def page_shell(title, body):
    return f"""
    <html>
    <head>
        <title>{html.escape(title)}</title>
        <style>
            body {{ font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #10141a; color: #d7dae0; padding: 20px; line-height: 1.5; }}
            a {{ color: #79c0ff; text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            h1, h2, h3 {{ margin-bottom: 0.4em; }}
            h1 {{ font-size: 1.7rem; }}
            table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
            th, td {{ border: 1px solid #2d3440; padding: 10px; text-align: left; vertical-align: top; }}
            th {{ background: #242833; }}
            .nav {{ margin-bottom: 24px; padding-bottom: 12px; border-bottom: 1px solid #3a3f4b; }}
            .nav a {{ margin-right: 12px; }}
            .hint {{ color: #9da5b4; max-width: 90ch; margin: 0 0 12px; }}
            .muted {{ color: #8b949e; }}
            .badge {{ display: inline-block; padding: 1px 6px; border-radius: 10px; font-size: 0.9em; margin-right: 6px; }}
            .badge-agent {{ background: #1f6feb33; color: #79c0ff; }}
            .badge-sector {{ background: #2ea04333; color: #7ee787; }}
            .badge-contract {{ background: #d2992233; color: #e3b341; }}
            .badge-world {{ background: #8957e533; color: #d2a8ff; }}
            .mutation-entry {{ margin-bottom: 8px; }}
            ul {{ margin: 6px 0; padding-left: 18px; }}
            .compact-list {{ margin: 0; padding-left: 18px; }}
            .compact-list li {{ margin: 0 0 4px; }}
            .tick-pill {{ display: inline-block; padding: 1px 6px; border-radius: 999px; background: #21262d; color: #c9d1d9; font-size: 0.82em; margin-right: 6px; }}
            .pagination {{ display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin: 14px 0; }}
            .page-link, .current-page {{ padding: 4px 9px; border: 1px solid #2d3440; border-radius: 999px; }}
            .current-page {{ background: #1f6feb33; color: #79c0ff; }}
            .history-list {{ margin: 0; padding-left: 18px; }}
            .history-entry {{ margin: 0 0 14px; }}
            .history-outcome {{ margin: 6px 0 0 8px; }}
            .event-move {{ color: #79c0ff; }}
            .event-attack {{ color: #ff7b72; }}
            .event-dock {{ color: #7ee787; }}
            .event-trade {{ color: #e3b341; }}
            .event-fail {{ color: #ffa657; }}
            .event-default {{ color: #d7dae0; }}
            small {{ color: #8b949e; }}
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
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()

        if path == "/snapshots":
            requested_page = query_page(query)
            c.execute("SELECT COUNT(*) FROM snapshots")
            total_count = c.fetchone()[0]
            page = clamp_page(requested_page, total_count, PAGE_SNAPSHOT_LIMIT)
            c.execute(
                """
                SELECT run_id, tick, tick_index, discovered_sectors, deaths, world_age, active_contracts, chronicle_event_count, mutation_count
                FROM snapshots
                ORDER BY run_id DESC, tick DESC
                LIMIT ?
                OFFSET ?
                """,
                (PAGE_SNAPSHOT_LIMIT, page_offset(page, PAGE_SNAPSHOT_LIMIT)),
            )
            rows = c.fetchall()
            pager = pagination_html("/snapshots", page, PAGE_SNAPSHOT_LIMIT, total_count)
            body = [
                "<h2>Timeline Snapshots</h2>",
                f"<p class='hint'>Browse the full snapshot timeline page by page. Newest snapshots stay first here; use pagination to walk older history.</p>",
                pager,
                "<table><tr><th>Run</th><th>Tick</th><th>Summary</th></tr>",
            ]
            for row in rows:
                body.append(
                    "<tr>"
                    f"<td>{html.escape(row['run_id'])}</td>"
                    f"<td><b>t{row['tick']}</b><br><small>tick index {row['tick_index']}</small></td>"
                    f"<td>{html.escape(snapshot_summary(row))}</td>"
                    "</tr>"
                )
            body.append("</table>")
            body.append(pager)
            html_body = "".join(body)

        elif path == "/events":
            requested_page = query_page(query)
            c.execute("SELECT COUNT(*) FROM events")
            total_count = c.fetchone()[0]
            page = clamp_page(requested_page, total_count, PAGE_EVENT_LIMIT)
            c.execute(
                """
                SELECT run_id, tick, action, actor_id, target_id, sector_id, data
                FROM events
                ORDER BY run_id DESC, tick DESC
                LIMIT ?
                OFFSET ?
                """
                ,
                (PAGE_EVENT_LIMIT, page_offset(page, PAGE_EVENT_LIMIT))
            )
            rows = c.fetchall()
            pager = pagination_html("/events", page, PAGE_EVENT_LIMIT, total_count)
            body = [
                "<h2>Chronicle Events</h2>",
                f"<p class='hint'>Browse chronicle events page by page. Each row pairs the event with the most relevant same-tick outcome summaries.</p>",
                pager,
                "<table><tr><th>Tick</th><th>Event</th><th>Observed Outcome</th></tr>",
            ]
            for row in rows:
                event_data = json.loads(row["data"])
                related = fetch_related_mutations(
                    c,
                    row["run_id"],
                    row["tick"],
                    row["actor_id"],
                    row["target_id"],
                    row["sector_id"],
                    RELATED_MUTATION_LIMIT + 1,
                )
                mutation_block = mutation_list_html(
                    related,
                    RELATED_MUTATION_LIMIT,
                    "No same-tick outcome matched this event.",
                )
                body.append(
                    "<tr>"
                    f"<td>{row['tick']}<br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{format_event(event_data)}</td>"
                    f"<td>{mutation_block}</td>"
                    "</tr>"
                )
            body.append("</table>")
            body.append(pager)
            html_body = "".join(body)

        elif path == "/mutations":
            requested_page = query_page(query)
            c.execute("SELECT COUNT(*) FROM mutations")
            total_count = c.fetchone()[0]
            page = clamp_page(requested_page, total_count, PAGE_MUTATION_LIMIT)
            c.execute(
                """
                SELECT run_id, tick, entity_type, entity_id, summary, data
                FROM mutations
                ORDER BY run_id DESC, tick DESC, entity_type ASC, entity_id ASC
                LIMIT ?
                OFFSET ?
                """
                ,
                (PAGE_MUTATION_LIMIT, page_offset(page, PAGE_MUTATION_LIMIT))
            )
            rows = c.fetchall()
            pager = pagination_html("/mutations", page, PAGE_MUTATION_LIMIT, total_count)
            body = [
                "<h2>Mutations</h2>",
                f"<p class='hint'>Browse inferred changes page by page. This remains the highest-signal outcome view when you want history without raw snapshot noise.</p>",
                pager,
                "<table><tr><th>Tick</th><th>Entity</th><th>Outcome</th></tr>",
            ]
            for row in rows:
                body.append(
                    "<tr>"
                    f"<td>{row['tick']}<br><small>{html.escape(row['run_id'])}</small></td>"
                    f"<td>{mutation_badge(row['entity_type'])}<b>{html.escape(row['entity_id'])}</b></td>"
                    f"<td>{html.escape(row['summary'])}</td>"
                    "</tr>"
                )
            body.append("</table>")
            body.append(pager)
            html_body = "".join(body)

        elif path == "/agent":
            run_id = query_value(query, "run_id")
            agent_id = query_value(query, "agent_id")
            list_page = query_value(query, "list_page", 1)
            if not run_id or not agent_id:
                html_body = (
                    "<h2>Agent History</h2>"
                    "<p class='hint'>Choose an agent from the Agents page to view the full paged history.</p>"
                )
            else:
                c.execute(
                    "SELECT data FROM agents WHERE run_id = ? AND agent_id = ?",
                    (run_id, agent_id),
                )
                agent_row = c.fetchone()
                if agent_row is None:
                    html_body = (
                        f"<h2>Agent History: {html.escape(agent_id)}</h2>"
                        "<p class='hint'>That agent was not found in the parsed run cache.</p>"
                    )
                else:
                    agent_data = json.loads(agent_row["data"])
                    c.execute(
                        "SELECT COUNT(*) FROM mutations WHERE run_id = ? AND entity_type = 'agent' AND entity_id = ?",
                        (run_id, agent_id),
                    )
                    change_count = c.fetchone()[0]
                    c.execute(
                        "SELECT COUNT(*) FROM events WHERE run_id = ? AND (actor_id = ? OR target_id = ?)",
                        (run_id, agent_id, agent_id),
                    )
                    event_count = c.fetchone()[0]
                    changes_page = clamp_page(query_page(query, "changes_page"), change_count, DETAIL_CHANGE_LIMIT)
                    events_page = clamp_page(query_page(query, "events_page"), event_count, DETAIL_EVENT_LIMIT)
                    c.execute(
                        """
                        SELECT tick, entity_type, entity_id, summary, data
                        FROM mutations
                        WHERE run_id = ? AND entity_type = 'agent' AND entity_id = ?
                        ORDER BY tick ASC
                        LIMIT ?
                        OFFSET ?
                        """,
                        (run_id, agent_id, DETAIL_CHANGE_LIMIT, page_offset(changes_page, DETAIL_CHANGE_LIMIT)),
                    )
                    change_rows = c.fetchall()
                    c.execute(
                        """
                        SELECT run_id, tick, action, actor_id, target_id, sector_id, data
                        FROM events
                        WHERE run_id = ? AND (actor_id = ? OR target_id = ?)
                        ORDER BY tick ASC, signature ASC
                        LIMIT ?
                        OFFSET ?
                        """,
                        (run_id, agent_id, agent_id, DETAIL_EVENT_LIMIT, page_offset(events_page, DETAIL_EVENT_LIMIT)),
                    )
                    event_rows = c.fetchall()
                    change_pager = pagination_html(
                        "/agent",
                        changes_page,
                        DETAIL_CHANGE_LIMIT,
                        change_count,
                        base_params={"run_id": run_id, "agent_id": agent_id, "events_page": events_page, "list_page": list_page},
                        param_name="changes_page",
                    )
                    event_pager = pagination_html(
                        "/agent",
                        events_page,
                        DETAIL_EVENT_LIMIT,
                        event_count,
                        base_params={"run_id": run_id, "agent_id": agent_id, "changes_page": changes_page, "list_page": list_page},
                        param_name="events_page",
                    )
                    body = [
                        f"<h2>Agent History: {html.escape(agent_id)}</h2>",
                        f"<p class='hint'><a href='{html.escape(build_url('/agents', {'page': list_page}))}'>Back to agents</a> | Run {html.escape(run_id)} | This timeline is ordered from earliest to latest.</p>",
                        "<h3>Current State</h3>",
                        agent_state_summary_html(agent_data),
                        f"<p class='hint'>{change_count} recorded agent changes and {event_count} related chronicle events.</p>",
                        "<h3>Change Timeline</h3>",
                        change_pager,
                        mutation_list_html(change_rows, DETAIL_CHANGE_LIMIT, "No recorded agent changes.", include_tick=True),
                        change_pager,
                        "<h3>Event Timeline</h3>",
                        event_pager,
                        event_list_html(c, event_rows, "No chronicle events involve this agent.", related_limit=3),
                        event_pager,
                    ]
                    html_body = "".join(body)

        elif path == "/sector":
            run_id = query_value(query, "run_id")
            sector_id = query_value(query, "sector_id")
            list_page = query_value(query, "list_page", 1)
            if not run_id or not sector_id:
                html_body = (
                    "<h2>Sector History</h2>"
                    "<p class='hint'>Choose a sector from the Sectors page to view the full paged history.</p>"
                )
            else:
                c.execute(
                    "SELECT data FROM sectors WHERE run_id = ? AND sector_id = ?",
                    (run_id, sector_id),
                )
                sector_row = c.fetchone()
                if sector_row is None:
                    html_body = (
                        f"<h2>Sector History: {html.escape(sector_id)}</h2>"
                        "<p class='hint'>That sector was not found in the parsed run cache.</p>"
                    )
                else:
                    sector_data = json.loads(sector_row["data"])
                    c.execute(
                        "SELECT COUNT(*) FROM mutations WHERE run_id = ? AND entity_type = 'sector' AND entity_id = ?",
                        (run_id, sector_id),
                    )
                    change_count = c.fetchone()[0]
                    c.execute(
                        "SELECT COUNT(*) FROM events WHERE run_id = ? AND sector_id = ?",
                        (run_id, sector_id),
                    )
                    event_count = c.fetchone()[0]
                    changes_page = clamp_page(query_page(query, "changes_page"), change_count, DETAIL_CHANGE_LIMIT)
                    events_page = clamp_page(query_page(query, "events_page"), event_count, DETAIL_EVENT_LIMIT)
                    c.execute(
                        """
                        SELECT tick, entity_type, entity_id, summary, data
                        FROM mutations
                        WHERE run_id = ? AND entity_type = 'sector' AND entity_id = ?
                        ORDER BY tick ASC
                        LIMIT ?
                        OFFSET ?
                        """,
                        (run_id, sector_id, DETAIL_CHANGE_LIMIT, page_offset(changes_page, DETAIL_CHANGE_LIMIT)),
                    )
                    change_rows = c.fetchall()
                    c.execute(
                        """
                        SELECT run_id, tick, action, actor_id, target_id, sector_id, data
                        FROM events
                        WHERE run_id = ? AND sector_id = ?
                        ORDER BY tick ASC, signature ASC
                        LIMIT ?
                        OFFSET ?
                        """,
                        (run_id, sector_id, DETAIL_EVENT_LIMIT, page_offset(events_page, DETAIL_EVENT_LIMIT)),
                    )
                    event_rows = c.fetchall()
                    change_pager = pagination_html(
                        "/sector",
                        changes_page,
                        DETAIL_CHANGE_LIMIT,
                        change_count,
                        base_params={"run_id": run_id, "sector_id": sector_id, "events_page": events_page, "list_page": list_page},
                        param_name="changes_page",
                    )
                    event_pager = pagination_html(
                        "/sector",
                        events_page,
                        DETAIL_EVENT_LIMIT,
                        event_count,
                        base_params={"run_id": run_id, "sector_id": sector_id, "changes_page": changes_page, "list_page": list_page},
                        param_name="events_page",
                    )
                    body = [
                        f"<h2>Sector History: {html.escape(sector_id)}</h2>",
                        f"<p class='hint'><a href='{html.escape(build_url('/sectors', {'page': list_page}))}'>Back to sectors</a> | Run {html.escape(run_id)} | This timeline is ordered from earliest to latest.</p>",
                        "<h3>Current State</h3>",
                        sector_state_summary_html(sector_data),
                        f"<p class='hint'>{change_count} recorded sector changes and {event_count} chronicle events in this sector.</p>",
                        "<h3>Change Timeline</h3>",
                        change_pager,
                        mutation_list_html(change_rows, DETAIL_CHANGE_LIMIT, "No recorded sector changes.", include_tick=True),
                        change_pager,
                        "<h3>Event Timeline</h3>",
                        event_pager,
                        event_list_html(c, event_rows, "No chronicle events occurred in this sector.", related_limit=3),
                        event_pager,
                    ]
                    html_body = "".join(body)

        elif path == "/agents":
            requested_page = query_page(query)
            c.execute("SELECT COUNT(*) FROM agents")
            total_count = c.fetchone()[0]
            page = clamp_page(requested_page, total_count, PAGE_AGENT_LIMIT)
            c.execute(
                "SELECT run_id, agent_id, data FROM agents ORDER BY run_id DESC, agent_id ASC LIMIT ? OFFSET ?",
                (PAGE_AGENT_LIMIT, page_offset(page, PAGE_AGENT_LIMIT)),
            )
            rows = c.fetchall()
            pager = pagination_html("/agents", page, PAGE_AGENT_LIMIT, total_count)
            body = [
                "<h2>Agents</h2>",
                f"<p class='hint'>Browse agents page by page. Open any row to inspect the full change and event history from start to finish.</p>",
                pager,
                "<table><tr><th>Agent</th><th>Current State</th><th>Recent Changes</th></tr>",
            ]
            for row in rows:
                agent_data = json.loads(row["data"])
                detail_link = build_url(
                    "/agent",
                    {"run_id": row["run_id"], "agent_id": row["agent_id"], "list_page": page},
                )
                c.execute(
                    """
                    SELECT tick, entity_type, entity_id, summary, data
                    FROM mutations
                    WHERE run_id = ? AND entity_type = 'agent' AND entity_id = ?
                    ORDER BY tick DESC
                    LIMIT ?
                    """,
                    (row["run_id"], row["agent_id"], ENTITY_HISTORY_LIMIT + 1),
                )
                mutation_rows = c.fetchall()
                mutation_block = mutation_list_html(
                    mutation_rows,
                    ENTITY_HISTORY_LIMIT,
                    "No recent changes recorded.",
                    include_tick=True,
                )
                body.append(
                    "<tr>"
                    f"<td><a href='{html.escape(detail_link)}'><b>{html.escape(row['agent_id'])}</b></a><br><small>{html.escape(row['run_id'])}</small><br><small><a href='{html.escape(detail_link)}'>View full history</a></small></td>"
                    f"<td>{agent_state_summary_html(agent_data)}</td>"
                    f"<td>{mutation_block}</td>"
                    "</tr>"
                )
            body.append("</table>")
            body.append(pager)
            html_body = "".join(body)

        elif path == "/sectors":
            requested_page = query_page(query)
            c.execute("SELECT COUNT(*) FROM sectors")
            total_count = c.fetchone()[0]
            page = clamp_page(requested_page, total_count, PAGE_SECTOR_LIMIT)
            c.execute(
                "SELECT run_id, sector_id, data FROM sectors ORDER BY run_id DESC, sector_id ASC LIMIT ? OFFSET ?",
                (PAGE_SECTOR_LIMIT, page_offset(page, PAGE_SECTOR_LIMIT)),
            )
            rows = c.fetchall()
            pager = pagination_html("/sectors", page, PAGE_SECTOR_LIMIT, total_count)
            body = [
                "<h2>Sectors</h2>",
                f"<p class='hint'>Browse sectors page by page. Open any row to inspect the full sector change and event history from start to finish.</p>",
                pager,
                "<table><tr><th>Sector</th><th>Current State</th><th>Recent Changes</th></tr>",
            ]
            for row in rows:
                sector_data = json.loads(row["data"])
                detail_link = build_url(
                    "/sector",
                    {"run_id": row["run_id"], "sector_id": row["sector_id"], "list_page": page},
                )
                c.execute(
                    """
                    SELECT tick, entity_type, entity_id, summary, data
                    FROM mutations
                    WHERE run_id = ? AND entity_type = 'sector' AND entity_id = ?
                    ORDER BY tick DESC
                    LIMIT ?
                    """,
                    (row["run_id"], row["sector_id"], ENTITY_HISTORY_LIMIT + 1),
                )
                mutation_rows = c.fetchall()
                mutation_block = mutation_list_html(
                    mutation_rows,
                    ENTITY_HISTORY_LIMIT,
                    "No recent sector changes recorded.",
                    include_tick=True,
                )
                body.append(
                    "<tr>"
                    f"<td><a href='{html.escape(detail_link)}'><b>{html.escape(row['sector_id'])}</b></a><br><small>{html.escape(row['run_id'])}</small><br><small><a href='{html.escape(detail_link)}'>View full history</a></small></td>"
                    f"<td>{sector_state_summary_html(sector_data)}</td>"
                    f"<td>{mutation_block}</td>"
                    "</tr>"
                )
            body.append("</table>")
            body.append(pager)
            html_body = "".join(body)

        else:
            c.execute(
                """
                SELECT run_id, stream_mode, tick_start,
                       COALESCE(tick_end, (SELECT MAX(tick) FROM snapshots WHERE snapshots.run_id = runs.run_id), tick_start) AS latest_tick,
                       finished_record,
                       (SELECT COUNT(*) FROM snapshots WHERE snapshots.run_id = runs.run_id) AS snapshot_count,
                       (SELECT COUNT(*) FROM events WHERE events.run_id = runs.run_id) AS event_count,
                       (SELECT COUNT(*) FROM mutations WHERE mutations.run_id = runs.run_id) AS mutation_count
                FROM runs
                ORDER BY run_id DESC
                """
            )
            rows = c.fetchall()
            body = [
                "<h2>Runs</h2>",
                "<p class='hint'>This browser now prioritizes readable outcomes: recent timelines, event lines, and compact change summaries. Raw payloads stay in the log file, not on the page.</p>",
                "<table><tr><th>Run</th><th>Status</th><th>Range</th><th>Activity</th></tr>",
            ]
            for row in rows:
                status = "finished" if row["finished_record"] else "open-ended"
                body.append(
                    "<tr>"
                    f"<td>{html.escape(row['run_id'])}</td>"
                    f"<td>{html.escape(str(row['stream_mode']))} / {status}</td>"
                    f"<td>{html.escape(run_range_text(row))}</td>"
                    f"<td>{row['snapshot_count']} snapshots | {row['event_count']} events | {row['mutation_count']} changes</td>"
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
