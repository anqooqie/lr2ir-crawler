#!/bin/bash -u

set -e
set -o pipefail

if [ "$#" -ne 1 ]; then
    echo 'usage: '"$0"' <sqlite3 database>' >&2
    exit 1
fi

cat <<'_EOT_' | sqlite3 "$1"
CREATE TABLE bms_files (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    play_rank TEXT NOT NULL CHECK (play_rank IN ('easy', 'normal', 'hard', 'very_hard'))
);
CREATE TABLE players (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    grade INTEGER NOT NULL CHECK (grade BETWEEN 0 AND 22)
);
CREATE TABLE scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bms_file_id INTEGER NOT NULL REFERENCES bms_files(id) ON UPDATE CASCADE ON DELETE CASCADE,
    player_id INTEGER NOT NULL REFERENCES players(id) ON UPDATE CASCADE ON DELETE CASCADE,
    clear TEXT NOT NULL CHECK (clear IN ('failed', 'easy', 'clear', 'hard', 'full_combo', 'perfect')),
    combo INTEGER NOT NULL,
    total_notes INTEGER NOT NULL,
    bp INTEGER NOT NULL,
    just_great INTEGER NOT NULL,
    great INTEGER NOT NULL,
    good INTEGER NOT NULL,
    bad INTEGER NOT NULL,
    poor INTEGER NOT NULL,
    gauge_option TEXT NOT NULL CHECK (gauge_option IN ('easy', 'groove', 'survival', 'good_attack', 'death', 'perfect_attack')),
    random_option TEXT NOT NULL CHECK (random_option IN ('normal', 'mirror', 'random', 'super_random')),
    input TEXT NOT NULL CHECK (input IN ('keyboard', 'beatmania', 'midi_controller')),
    program TEXT NOT NULL CHECK (program IN ('lunatic_rave_2', 'simple_bms_player')),
    UNIQUE (bms_file_id, player_id)
);
CREATE INDEX scores_bms_file_id ON scores(bms_file_id);
CREATE TABLE difficulty_tables (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    uri TEXT NOT NULL UNIQUE,
    symbol TEXT NOT NULL,
    tag TEXT NOT NULL
);
CREATE TABLE levels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    difficulty_table_id INTEGER NOT NULL REFERENCES difficulty_tables(id) ON UPDATE CASCADE ON DELETE CASCADE,
    level_order INTEGER NOT NULL,
    name TEXT NOT NULL,
    UNIQUE (difficulty_table_id, level_order)
);
CREATE TABLE level_registrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON UPDATE CASCADE ON DELETE CASCADE,
    bms_file_id INTEGER NOT NULL REFERENCES bms_files(id) ON UPDATE CASCADE ON DELETE CASCADE
);
_EOT_
