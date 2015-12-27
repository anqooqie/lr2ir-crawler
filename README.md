# lr2ir-crawler

A crawler of [LunaticRave2 Internet Ranking](http://www.dream-pro.info/~lavalse/LR2IR/search.cgi)

## usage

    $ # Initialization
    $ make
    $ ./init.sh lr2ir.sqlite3
    $ # You can crawl score data of difficulty tables
    $ RUBYLIB=lib bundle exec ruby crawl.rb lr2ir.sqlite3 'http://www.ribbit.xyz/bms/tables/insane.html'
    $ RUBYLIB=lib bundle exec ruby crawl.rb lr2ir.sqlite3 'http://www.ribbit.xyz/bms/tables/overjoy.html'
    $ # You can analyze various things using crawled data
    $ sqlite3 lr2ir2.sqlite3
    sqlite> -- number of insane bms players
    sqlite> SELECT count(DISTINCT player_id) FROM scores INNER JOIN bms_files ON scores.bms_file_id = bms_files.id INNER JOIN level_registrations ON bms_files.id = level_registrations.bms_file_id INNER JOIN levels ON level_registrations.level_id = levels.id INNER JOIN difficulty_tables ON levels.difficulty_table_id = difficulty_tables.id WHERE difficulty_tables.name = '発狂BMS難易度表';
    39797
    sqlite> -- number of overjoy players
    sqlite> SELECT count(DISTINCT player_id) FROM scores INNER JOIN bms_files ON scores.bms_file_id = bms_files.id INNER JOIN level_registrations ON bms_files.id = level_registrations.bms_file_id INNER JOIN levels ON level_registrations.level_id = levels.id INNER JOIN difficulty_tables ON levels.difficulty_table_id = difficulty_tables.id WHERE difficulty_tables.name = 'Overjoy';
    16061
    sqlite> -- grade distribution of insane bms players
    sqlite> SELECT grade, count(*) FROM players WHERE id IN (SELECT player_id FROM scores INNER JOIN bms_files ON scores.bms_file_id = bms_files.id INNER JOIN level_registrations ON bms_files.id = level_registrations.bms_file_id INNER JOIN levels ON level_registrations.level_id = levels.id INNER JOIN difficulty_tables ON levels.difficulty_table_id = difficulty_tables.id WHERE difficulty_tables.name = '発狂BMS難易度表') GROUP BY grade ORDER BY grade;
    0|26665
    1|129
    2|158
    3|65
    4|412
    5|140
    6|905
    7|791
    8|808
    9|949
    10|362
    11|1460
    12|743
    13|811
    14|1518
    15|433
    16|1235
    17|633
    18|441
    19|541
    20|242
    21|334
    22|22
    sqlite> -- acceptable BP to achieve FDFD hard clear
    sqlite> SELECT max(bp) FROM scores INNER JOIN bms_files ON scores.bms_file_id = bms_files.id WHERE title = 'FREEDOM DiVE [FOUR DIMENSIONS]' AND clear IN ('hard', 'full_combo', 'perfect');
    83
    sqlite> -- most played bms in insane bms table
    sqlite> SELECT title, count(*) FROM scores INNER JOIN bms_files ON scores.bms_file_id = bms_files.id INNER JOIN level_registrations ON bms_files.id = level_registrations.bms_file_id INNER JOIN levels ON level_registrations.level_id = levels.id INNER JOIN difficulty_tables ON levels.difficulty_table_id = difficulty_tables.id WHERE difficulty_tables.name = '発狂BMS難易度表' GROUP BY bms_files.id, title ORDER BY count(*) DESC LIMIT 1;
    星の器～STAR OF ANDROMEDA (ANOTHER)|18686
