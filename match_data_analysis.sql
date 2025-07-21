
-- OWCS EMEA Stage 2 SQL Analysis
-- Author: [Majed Almusayhil]
-- Desc: All key analytical queries on match_data_raw table
CREATE TABLE match_data_raw (
  match_id TEXT,
  team TEXT,
  opp_team TEXT,
  match_phase TEXT,
  map TEXT,
  map_type TEXT,
  round TEXT,
  map_duration INTEGER,
  player TEXT,
  role TEXT,
  starting_hero TEXT,
  switches TEXT,
  ultimates_used INTEGER,
  hero_bans TEXT,
  result TEXT,
  map_number INTEGER,
  region TEXT,
  damage INTEGER,
  healing INTEGER,
  mit INTEGER,
  elim INTEGER,
  assists INTEGER,
  deaths INTEGER,
  has_sb BOOLEAN
);
select * from match_data_raw

--Team win rates by phase (e.g. Regular Season vs Playoffs) (map winrate)
SELECT team, match_phase, COUNT(*) FILTER (WHERE result = 'Win') * 1.0 / COUNT(*) AS win_rate
FROM match_data_raw
GROUP BY team, match_phase;

--Map performance per team
SELECT team, map, COUNT(*) FILTER (WHERE result = 'Win') * 1.0 / COUNT(*) AS map_win_rate
FROM match_data_raw
GROUP BY team, map
ORDER BY map_win_rate DESC;

--Hero bans frequency
WITH all_heroes AS (
  SELECT unnest(ARRAY[
    'Ana','Ashe','Baptiste','Bastion','Brigitte','Cassidy','D.va','Doomfist',
    'Echo','Genji','Hanzo','Illari','Junkerqueen','Junkrat','Kiriko','Lifeweaver',
    'Lucio','Mei','Mercy','Moira','Orisa','Pharah','Ramattra','Reaper','Reinhardt',
    'Roadhog','Sigma','Sojourn','Soldier:76','Sombra','Symmetra','Torbjorn',
    'Tracer','Venture','Widowmaker','Winston','Wrecking Ball','Zarya','Zenyatta',
    'Hazard','Freja'
  ]) AS hero
),
unique_maps AS (
  SELECT DISTINCT match_id, map_number, hero_bans
  FROM match_data_raw
  WHERE hero_bans IS NOT NULL
),
banned_heroes AS (
  SELECT unnest(string_to_array(hero_bans, ', ')) AS hero
  FROM unique_maps
),
ban_counts AS (
  SELECT hero, COUNT(*) AS ban_count
  FROM banned_heroes
  GROUP BY hero
)
SELECT a.hero, COALESCE(b.ban_count, 0) AS ban_count
FROM all_heroes a
LEFT JOIN ban_counts b ON a.hero = b.hero
ORDER BY ban_count DESC, hero;

--Top players by average damage / healing / elims
SELECT player,
       ROUND(AVG(damage)) AS avg_damage,
       ROUND(AVG(healing)) AS avg_healing,
       ROUND(AVG(elim)) AS avg_elims
FROM match_data_raw
WHERE damage IS NOT NULL AND healing IS NOT NULL AND elim IS NOT NULL
GROUP BY player
ORDER BY avg_damage DESC
LIMIT 10;

--Player hero pick distribution
SELECT player, starting_hero, role, COUNT(*) AS matches
FROM match_data_raw
GROUP BY player, starting_hero, role
ORDER BY player, matches DESC;

--Hero win rate
WITH hero_appearances AS (
  SELECT
    match_id,
    map_number,
    player,
    result,
    hero
  FROM (
    SELECT
      match_id,
      map_number,
      player,
      result,
      UNNEST(ARRAY[starting_hero] || STRING_TO_ARRAY(switches, ',')) AS hero
    FROM match_data_raw
  ) AS raw_heroes
  WHERE hero IS NOT NULL AND TRIM(hero) != '' AND TRIM(hero) != 'None'
),
deduplicated_heroes AS (
  SELECT DISTINCT match_id, map_number, player, hero, result
  FROM hero_appearances
)
SELECT
  hero,
  COUNT(*) FILTER (WHERE result = 'Win') * 1.0 / COUNT(*) AS win_rate,
  COUNT(*) AS total_matches
FROM deduplicated_heroes
GROUP BY hero
HAVING COUNT(*) > 10
ORDER BY win_rate DESC;

--Most frequent hero switches
SELECT unnest(string_to_array(switches, ', ')) AS hero_switched_to, COUNT(*) AS times_used
FROM match_data_raw
WHERE switches IS NOT NULL
GROUP BY hero_switched_to
ORDER BY times_used DESC;

--Match win rate per team
WITH match_results AS (
  SELECT
    match_id,
    team,
    match_phase,
    COUNT(*) FILTER (WHERE result = 'Win') AS map_wins,
    COUNT(*) AS total_maps
  FROM match_data_raw
  GROUP BY match_id, team, match_phase
),
match_win_flag AS (
  SELECT *,
         CASE WHEN map_wins > total_maps / 2 THEN 1 ELSE 0 END AS match_won
  FROM match_results
)
SELECT
  team,
  match_phase,
  ROUND(AVG(match_won)::numeric, 3) AS match_win_rate
FROM match_win_flag
GROUP BY team, match_phase
ORDER BY match_win_rate DESC;

--Most versatile players
SELECT 
  player,
  role,
  COUNT(DISTINCT hero) AS unique_heroes
FROM (
  SELECT 
    player, 
    role,
    starting_hero AS hero
  FROM match_data_raw
  WHERE starting_hero IS NOT NULL AND starting_hero != 'None'

  UNION

  SELECT 
    player,
    role,
    TRIM(UNNEST(STRING_TO_ARRAY(switches, ','))) AS hero
  FROM match_data_raw
  WHERE switches IS NOT NULL AND switches != ''
) AS combined
WHERE hero != 'None' AND hero != ''
GROUP BY player, role
ORDER BY unique_heroes DESC;

--Hero never picked
WITH all_heroes AS (
  SELECT unnest(ARRAY[
    'Ana','Ashe','Baptiste','Bastion','Brigitte','Cassidy','D.va','Doomfist',
    'Echo','Genji','Hanzo','Illari','Junkerqueen','Junkrat','Kiriko','Lifeweaver',
    'Lucio','Mei','Mercy','Moira','Orisa','Pharah','Ramattra','Reaper','Reinhardt',
    'Roadhog','Sigma','Sojourn','Soldier:76','Sombra','Symmetra','Torbjorn',
    'Tracer','Venture','Widowmaker','Winston','Wrecking Ball','Zarya','Zenyatta',
    'Hazard','Freja'
  ]) AS hero
),
played_heroes_combined AS (
  SELECT DISTINCT unnest(
    string_to_array(
      starting_hero || COALESCE(', ' || switches, ''),
      ', '
    )
  ) AS hero
  FROM match_data_raw
)
SELECT hero
FROM all_heroes
WHERE hero NOT IN (SELECT hero FROM played_heroes_combined)
ORDER BY hero;

-- Common out of the spawn team comps
WITH comps AS (
  SELECT 
    match_id,
    map_number,
    team,
    STRING_AGG(DISTINCT starting_hero, ', ' ORDER BY starting_hero) AS team_comp
  FROM match_data_raw
  WHERE starting_hero IS NOT NULL AND starting_hero != 'None'
  GROUP BY match_id, map_number, team
)
SELECT 
  team_comp,
  COUNT(*) AS usage_count
FROM comps
GROUP BY team_comp
ORDER BY usage_count DESC;

--Round type win rate per team
SELECT team, round, 
       COUNT(*) FILTER (WHERE result = 'Win') * 1.0 / COUNT(*) AS win_rate
FROM match_data_raw
GROUP BY round, team
ORDER BY round, win_rate DESC;

--Average map duration per map
SELECT map, ROUND(AVG(map_duration)) AS avg_duration_sec, map_type
FROM match_data_raw
GROUP BY map, map_type
ORDER BY avg_duration_sec DESC;

--Ults used per role
SELECT role, ROUND(AVG(ultimates_used)) AS avg_ults_used
FROM match_data_raw
WHERE ultimates_used IS NOT NULL
GROUP BY role
ORDER BY avg_ults_used DESC;

--Highest ultimate used in a game
WITH ults AS (
  SELECT
    match_id, player, team, ultimates_used, map, map_number, starting_hero, role
  FROM match_data_raw
  WHERE ultimates_used IS NOT NULL
),
max_val AS (
  SELECT MAX(ultimates_used) AS max_ults FROM ults
)
SELECT *
FROM ults
WHERE ultimates_used = (SELECT max_ults FROM max_val);

--Longest map and shortest map (duration)
WITH map_durations AS (
  SELECT DISTINCT match_id, map_number, map, map_duration
  FROM match_data_raw
  WHERE map_duration IS NOT NULL
),
teams_per_map AS (
  SELECT match_id, map_number,
         STRING_AGG(DISTINCT team, ' vs ') AS teams
  FROM match_data_raw
  GROUP BY match_id, map_number
),
ranked_maps AS (
  SELECT m.*, t.teams,
         RANK() OVER (ORDER BY m.map_duration DESC) AS max_rank,
         RANK() OVER (ORDER BY m.map_duration ASC) AS min_rank
  FROM map_durations m
  JOIN teams_per_map t USING (match_id, map_number)
)
SELECT *
FROM ranked_maps
WHERE max_rank = 1 OR min_rank = 1
ORDER BY map_duration DESC;

-- Most maps played by each team
SELECT
  team,
  map,
  COUNT(DISTINCT (match_id, map_number)) AS times_played
FROM match_data_raw
GROUP BY team, map
ORDER BY times_played DESC;

--Matchups between saudi owned teams only
SELECT
  match_id,
  team,
  opp_team,
  map,
  map_number,
  result,
  ultimates_used,
  player
FROM match_data_raw
WHERE team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
  AND opp_team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
ORDER BY match_id, map_number;

--Average ultimates used per player per saudi owned team vs saudi owned team match
WITH saudi_vs_saudi AS (
  SELECT *
  FROM match_data_raw
  WHERE team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
    AND opp_team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
    AND ultimates_used IS NOT NULL
)
SELECT team, player, ROUND(AVG(ultimates_used), 2) AS avg_ults
FROM saudi_vs_saudi
GROUP BY team, player
ORDER BY avg_ults DESC;

--Saudi owned team Head-to-Head win-rates (Only against each other)
WITH saudi_matches AS (
  SELECT match_id, team, result
  FROM match_data_raw
  WHERE team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
    AND opp_team IN ('Twisted Minds', 'Al Qadsiah', 'The Ultimates')
),
map_wins AS (
  SELECT match_id, team, COUNT(*) FILTER (WHERE result = 'Win') AS map_wins
  FROM saudi_matches
  GROUP BY match_id, team
),
match_winners AS (
  SELECT match_id, team AS winner
  FROM (
    SELECT *, RANK() OVER (PARTITION BY match_id ORDER BY map_wins DESC) AS r
    FROM map_wins
  ) ranked
  WHERE r = 1
),
all_match_teams AS (
  SELECT DISTINCT match_id, team
  FROM saudi_matches
),
summary AS (
  SELECT
    t.team,
    COUNT(DISTINCT t.match_id) AS total_matches,
    COUNT(DISTINCT w.match_id) AS wins,
    ROUND(COUNT(DISTINCT w.match_id) * 1.0 / COUNT(DISTINCT t.match_id), 2) AS win_rate,
    STRING_AGG(w.match_id, ', ') AS match_ids_won
  FROM all_match_teams t
  LEFT JOIN match_winners w ON t.match_id = w.match_id AND t.team = w.winner
  GROUP BY t.team
)
SELECT *
FROM summary
ORDER BY win_rate DESC;