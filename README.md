
# OWCS EMEA Stage 2 Analysis (2025)

This project analyzes Overwatch Champion Series (OWCS) EMEA Stage 2 match data using PostgreSQL and Python.

## 📁 Project Structure

```
.
├── exports/                  # CSV summaries and generated charts
├── owcs_analysis.py          # Python script to generate charts
├── match_data_analysis.sql   # Full cleaned SQL query file
└── README.md                 # Project documentation
```

## 📊 Key Insights

- Team map and match win rates (per phase)
- Hero pick and ban rates
- Hero win rates (min 10 games)
- Player average performance (damage, healing, elims)
- Saudi team head-to-head win tracking

## 🛠️ Tools Used

- PostgreSQL 15
- Python 3.10
  - pandas
  - seaborn
  - matplotlib

## 📦 How to Run

1. Run all SQL in `match_data_analysis.sql` on a PostgreSQL database with `match_data_raw` table.
2. Export the query results into `exports/` as CSV files.
3. Run the Python script:

```bash
python owcs_analysis.py
```

Charts will be saved in `exports/`.

## 📈 Example Visuals

- Team win rates by phase
- Top 20 banned heroes
- Hero win rates
- Player stats comparison

## 📌 Data Collection Notes

- Matches are counted from the moment **“Assemble Heroes” starts**, not when the team fight begins.
- Switches made **at the last second to touch the objective** are only counted **if the team won the fight**. Otherwise, they’re ignored.
- **Symmetra (for TP)** and **Lucio (for speed)** used only briefly at the start are **not counted as starting heroes**, unless they were used in the first fight.
- All match data was gathered from **[OW Esports YouTube VODs](https://www.youtube.com/@ow_esports)**.
- Final scoreboard verification was done using **[ObsSojourn VODs](https://www.youtube.com/@ObsSojourn)**.

---

**Author**: [Majed Almusayhil]  
**Data Source**: Manually curated OWCS EMEA Stage 2 dataset (2025)
