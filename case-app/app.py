#!/usr/bin/env python3
"""
KontaktApp - simple local case-logging tool for a Kontaktbefalingsmand.
Runs fully offline, stores data in a local SQLite database under the
user's home folder (so it survives on the persistent USB partition).
"""

import csv
import io
import os
import sqlite3
from datetime import datetime, date

from flask import (
    Flask, g, render_template, request, redirect, url_for, flash, Response
)

APP_DIR = os.path.join(os.path.expanduser("~"), ".local", "share", "kontaktapp")
os.makedirs(APP_DIR, exist_ok=True)
DB_PATH = os.path.join(APP_DIR, "cases.db")

CATEGORIES = ["Henvendelse", "Hændelse", "Anmodning", "Klage", "Underretning", "Andet"]
STATUSES = ["Åben", "Under behandling", "Afsluttet"]

app = Flask(__name__)
app.secret_key = "kontaktapp-local-secret"  # local single-user app, not exposed to network


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exception=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = sqlite3.connect(DB_PATH)
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS cases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            case_number TEXT NOT NULL,
            created_at TEXT NOT NULL,
            title TEXT NOT NULL,
            contact_name TEXT,
            contact_phone TEXT,
            contact_email TEXT,
            location TEXT,
            category TEXT,
            description TEXT,
            actions_taken TEXT,
            status TEXT NOT NULL DEFAULT 'Åben',
            follow_up_date TEXT,
            closed_at TEXT
        )
        """
    )
    db.commit()
    db.close()


def next_case_number(db):
    year = date.today().year
    row = db.execute(
        "SELECT COUNT(*) AS c FROM cases WHERE case_number LIKE ?", (f"KB-{year}-%",)
    ).fetchone()
    seq = row["c"] + 1
    return f"KB-{year}-{seq:04d}"


@app.route("/")
def index():
    db = get_db()
    status_filter = request.args.get("status", "")
    query = request.args.get("q", "").strip()

    sql = "SELECT * FROM cases"
    conditions = []
    params = []
    if status_filter:
        conditions.append("status = ?")
        params.append(status_filter)
    if query:
        conditions.append(
            "(case_number LIKE ? OR title LIKE ? OR contact_name LIKE ? OR location LIKE ?)"
        )
        like = f"%{query}%"
        params.extend([like, like, like, like])
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)
    sql += " ORDER BY created_at DESC"

    cases = db.execute(sql, params).fetchall()
    open_count = db.execute(
        "SELECT COUNT(*) c FROM cases WHERE status != 'Afsluttet'"
    ).fetchone()["c"]

    return render_template(
        "index.html",
        cases=cases,
        statuses=STATUSES,
        status_filter=status_filter,
        query=query,
        open_count=open_count,
    )


@app.route("/case/new", methods=["GET", "POST"])
def new_case():
    db = get_db()
    if request.method == "POST":
        case_number = next_case_number(db)
        db.execute(
            """INSERT INTO cases
               (case_number, created_at, title, contact_name, contact_phone,
                contact_email, location, category, description, actions_taken,
                status, follow_up_date)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                case_number,
                datetime.now().isoformat(timespec="seconds"),
                request.form.get("title", "").strip(),
                request.form.get("contact_name", "").strip(),
                request.form.get("contact_phone", "").strip(),
                request.form.get("contact_email", "").strip(),
                request.form.get("location", "").strip(),
                request.form.get("category", ""),
                request.form.get("description", "").strip(),
                request.form.get("actions_taken", "").strip(),
                request.form.get("status", "Åben"),
                request.form.get("follow_up_date", "") or None,
            ),
        )
        db.commit()
        flash(f"Sag {case_number} oprettet.")
        return redirect(url_for("index"))

    return render_template("form.html", categories=CATEGORIES, statuses=STATUSES, case=None)


@app.route("/case/<int:case_id>", methods=["GET", "POST"])
def view_case(case_id):
    db = get_db()
    if request.method == "POST":
        closed_at = None
        new_status = request.form.get("status", "Åben")
        existing = db.execute("SELECT status FROM cases WHERE id=?", (case_id,)).fetchone()
        if new_status == "Afsluttet" and existing and existing["status"] != "Afsluttet":
            closed_at = datetime.now().isoformat(timespec="seconds")
        elif new_status != "Afsluttet":
            closed_at = None

        db.execute(
            """UPDATE cases SET title=?, contact_name=?, contact_phone=?, contact_email=?,
               location=?, category=?, description=?, actions_taken=?, status=?,
               follow_up_date=?, closed_at=COALESCE(?, closed_at)
               WHERE id=?""",
            (
                request.form.get("title", "").strip(),
                request.form.get("contact_name", "").strip(),
                request.form.get("contact_phone", "").strip(),
                request.form.get("contact_email", "").strip(),
                request.form.get("location", "").strip(),
                request.form.get("category", ""),
                request.form.get("description", "").strip(),
                request.form.get("actions_taken", "").strip(),
                new_status,
                request.form.get("follow_up_date", "") or None,
                closed_at,
                case_id,
            ),
        )
        if new_status != "Afsluttet":
            db.execute("UPDATE cases SET closed_at=NULL WHERE id=?", (case_id,))
        db.commit()
        flash("Sag opdateret.")
        return redirect(url_for("view_case", case_id=case_id))

    case = db.execute("SELECT * FROM cases WHERE id=?", (case_id,)).fetchone()
    if case is None:
        flash("Sag ikke fundet.")
        return redirect(url_for("index"))
    return render_template("form.html", categories=CATEGORIES, statuses=STATUSES, case=case)


@app.route("/case/<int:case_id>/delete", methods=["POST"])
def delete_case(case_id):
    db = get_db()
    db.execute("DELETE FROM cases WHERE id=?", (case_id,))
    db.commit()
    flash("Sag slettet.")
    return redirect(url_for("index"))


@app.route("/export.csv")
def export_csv():
    db = get_db()
    cases = db.execute("SELECT * FROM cases ORDER BY created_at DESC").fetchall()
    output = io.StringIO()
    writer = csv.writer(output)
    if cases:
        writer.writerow(cases[0].keys())
        for c in cases:
            writer.writerow(list(c))
    return Response(
        output.getvalue(),
        mimetype="text/csv",
        headers={"Content-Disposition": "attachment; filename=kontaktapp-sager.csv"},
    )


if __name__ == "__main__":
    init_db()
    app.run(host="127.0.0.1", port=5157, debug=False)
