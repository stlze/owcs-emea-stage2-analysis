import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Load your dataset
df = pd.read_csv("C:/Users/Admin/Downloads/owcs25_emea_stage2.csv")

map_winners = (
    df[df['result'] == 'Win']
    .groupby(['match_id', 'map_number'])['team']
    .first()
    .reset_index()
    .rename(columns={'team': 'map_winner'})
)

df = df.merge(map_winners, on=['match_id', 'map_number'], how='left')

df['won'] = (df['team'] == df['map_winner']).astype(int)


# Team win rate by phase (map winrate) (barplot)
team_winrates = (
    df.groupby(['team', 'match_phase'])['won']
    .mean()
    .reset_index()
    .rename(columns={'won': 'win_rate'})
)

plt.figure(figsize=(10, 6))
sns.barplot(data=team_winrates, x='team', y='win_rate', hue='match_phase')
plt.title('Team Win-Rate by Phase (map winrate)')
plt.ylabel('Win Rate')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

# Map Performance per Team (heatmap)
map_winrates = (
    df.groupby(['team', 'map'])['won']
    .mean()
    .unstack()
    .fillna(0)
    .round(2)
)

plt.figure(figsize=(14, 8))
sns.heatmap(map_winrates, annot=True, fmt=".2f", cmap="YlGnBu", linewidths=0.5)
plt.title("Team Map Win-Rates")
plt.ylabel("Team")
plt.xlabel("Map")
plt.tight_layout()
plt.show()

# Hero Ban Frequency
unique_bans = df[['match_id', 'map_number', 'hero_bans']].drop_duplicates()

unique_bans = unique_bans.dropna(subset=['hero_bans'])

unique_bans['hero_bans'] = unique_bans['hero_bans'].astype(str).str.split(',')

exploded_bans = unique_bans.explode('hero_bans')

exploded_bans['hero_bans'] = exploded_bans['hero_bans'].str.strip()

ban_counts = (
    exploded_bans['hero_bans']
    .value_counts()
    .reset_index()
    .rename(columns={'index': 'hero_bans', 'hero_bans': 'ban_count'})
)

ban_counts.columns = ['hero', 'ban_count']

plt.figure(figsize=(12, 6))
sns.barplot(data=ban_counts.head(20), x='hero', y='ban_count', palette='Reds')
plt.title('Top 20 Most Banned Heroes')
plt.ylabel('Ban Count')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()


hero_usage = (
    df.assign(all_heroes=df['starting_hero'].astype(str) + ',' + df['switches'].fillna(''))
    .assign(all_heroes=lambda d: d['all_heroes'].str.split(','))
    .explode('all_heroes')
    .assign(all_heroes=lambda d: d['all_heroes'].str.strip())
    .query("all_heroes != '' and all_heroes != 'None'")
)

hero_usage_unique = hero_usage[['match_id', 'map_number', 'player', 'all_heroes', 'result']].drop_duplicates()

hero_winrates = (
    hero_usage_unique.groupby('all_heroes')
    .agg(win_rate=('result', lambda x: (x == 'Win').mean()),
         total_matches=('result', 'count'))
    .query('total_matches > 10')
    .sort_values('win_rate', ascending=False)
)

for metric in ['damage', 'healing', 'elim']:
    top_players = (
        df.groupby('player')[metric]
        .mean()
        .reset_index()
        .sort_values(metric, ascending=False)
        .head(15)
    )

    plt.figure(figsize=(10, 5))
    sns.barplot(data=top_players, x='player', y=metric, palette='viridis')
    plt.title(f'(Games with scoreboard provided) Top 15 Players by Average {metric.capitalize()}')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

from collections import Counter

df['all_heroes'] = df['starting_hero'].fillna('') + ',' + df['switches'].fillna('')

df['all_heroes'] = df['all_heroes'].str.split(',').apply(
    lambda x: set(hero.strip() for hero in x if hero.strip() and hero.strip() != 'None')
)

exploded_switches = df.explode('all_heroes')

switch_counts = (
    exploded_switches['all_heroes']
    .value_counts()
    .head(20)
    .reset_index()
)
switch_counts.columns = ['hero', 'switch_count']
plt.figure(figsize=(10, 5))
sns.barplot(data=switch_counts, x='hero', y='switch_count', palette='mako')
plt.title("Most Frequent Hero Switches")
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

