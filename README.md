# 🏏 IPL Data Analysis Using SQL

## Introduction

📊 Dive into the world of IPL cricket analytics! Focusing on player performance, team strategies, and match outcomes, this project explores 🏆 top-performing players, 🎯 key team KPIs, and 📈 data-driven insights for team building and match strategy.

🔍 SQL queries? Check them out here: [ipl_project_final.sql](./ipl_project_final.sql)


---

## Background

This project was built as part of an end-to-end SQL analytics case study on IPL (Indian Premier League) data, with a focus on **Royal Challengers Bangalore (RCB)**. The goal was to analyze historical match and player data to uncover performance patterns, derive team KPIs, and provide data-backed recommendations for auction strategy, team selection, and match planning.

The dataset spans multiple IPL seasons and includes ball-by-ball delivery data, match results, player records, venue information, and wicket details.

### The questions I wanted to answer through my SQL queries were:

1. What KPIs best measure team performance across seasons?
2. How do individual players perform in batting and bowling across all seasons?
3. Which players consistently deliver results across multiple seasons?
4. How does venue impact team and player performance?

---

## Tools I Used

- **SQL (MySQL):** The backbone of the entire analysis — used for querying, aggregating, filtering, and deriving insights from relational tables.
- **CTEs & Window Functions:** Used extensively for ranking bowlers by venue, identifying consistent players, and year-over-year team performance comparison.
- **Excel:** Used for building charts and visual dashboards — including scatter plots, bar charts, and venue-wise performance breakdowns.
- **MySQL Workbench:** Primary environment for writing and executing SQL queries.
- **PowerPoint:** Used to present findings and data stories from the analysis.
- **Git & GitHub:** For version control and sharing the project publicly.

---

## 📊 The Analysis

The analysis in this project focuses on understanding player performance, team dynamics, and match outcomes using IPL data. The key areas explored include team KPIs, batting and bowling strength, player consistency, and venue impact.

---

### 1. Team KPIs — Measuring Performance Beyond Wins

To go beyond simple win/loss counts, I derived three strategic KPIs to measure team effectiveness across seasons.

**Win Percentage:**
```sql
SELECT t.Team_Name,
    (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100) /
    NULLIF(COUNT(CASE WHEN m.Match_Winner IS NOT NULL THEN 1 END), 0) AS Win_Percentage
FROM Team t
JOIN Matches m ON m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_ID
GROUP BY t.Team_Name
ORDER BY Win_Percentage DESC;
```

**Dot Ball Percentage** *(how often a team fails to score — lower is better)*:
```sql
SELECT t.Team_name,
    ROUND(COUNT(CASE WHEN b.Runs_Scored = 0 THEN 1 END) * 100 / COUNT(*), 2) AS dot_ball_percentage
FROM Team t
JOIN ball_by_ball b ON t.Team_Id = b.Team_Batting
GROUP BY t.Team_name
ORDER BY dot_ball_percentage DESC;
```

**Year-on-Year Performance Comparison:**
```sql
WITH team_season AS (
    SELECT t.Team_Id, s.Season_Year,
        SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
    FROM matches m
    JOIN season s ON s.Season_Id = m.Season_Id
    JOIN ball_by_ball b ON m.Match_Id = b.Match_Id
    JOIN team t ON b.Team_batting = t.Team_Id
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id AND b.Ball_Id = w.Ball_Id
    GROUP BY t.Team_Id, s.Season_Year
),
compare AS (
    SELECT tsc.Team_Id, tsc.Season_Year,
        tsc.total_runs AS current_runs, tsc.total_wickets AS current_wickets,
        tsp.total_runs AS previous_runs, tsp.total_wickets AS previous_wickets
    FROM team_season tsc
    LEFT JOIN team_season tsp ON tsc.Team_Id = tsp.Team_Id
        AND tsc.Season_Year = tsp.Season_Year + 1
)
SELECT Team_Id, Season_Year, current_runs, current_wickets, previous_runs, previous_wickets,
    CASE WHEN previous_runs IS NULL THEN 'No Previous Data'
         WHEN current_runs > previous_runs AND current_wickets > previous_wickets THEN 'Better'
         WHEN current_runs = previous_runs AND current_wickets = previous_wickets THEN 'Same'
         ELSE 'Worse'
    END AS performance_status
FROM compare
ORDER BY Team_Id, Season_Year;
```

Here's the breakdown of team KPIs across seasons:

- **Win Percentage** reveals that Chennai Super Kings (62.74%) and Mumbai Indians (57.81%) lead, while RCB sits at 51.67% — strong but not a title-winning rate
- **Dot Ball Percentage** shows Pune Warriors facing the most dot balls (42.33%), while Rising Pune Supergiants had the fewest (34.87%) — indicating better strike rotation
- **Year-on-Year trends** expose seasons where teams regressed in both runs and wickets simultaneously, helping pinpoint weak rebuilding years

| Team | Win Percentage |
|------|---------------|
| Chennai Super Kings | 62.74 |
| Mumbai Indians | 57.81 |
| Gujarat Lions | 56.25 |
| Rajasthan Royals | 55.56 |
| Royal Challengers Bangalore | 51.67 |

*Win percentage across IPL teams — a core KPI for measuring overall team effectiveness*

---

### 2. Player Performance — Batting & Bowling

To identify the best players for team selection, I analyzed batting averages, strike rates, and bowling wicket rates across all seasons.

**Top Batters** *(minimum 20 matches, batting average ≥ 30, strike rate ≥ 130)*:
```sql
SELECT p.Player_Id, p.Player_Name,
    COUNT(DISTINCT b.Match_Id) AS matches_played,
    SUM(b.Runs_Scored) AS total_runs,
    ROUND(100.0 * SUM(b.Runs_Scored) / COUNT(b.Ball_Id), 2) AS strike_rate,
    ROUND(SUM(b.Runs_Scored) * 1.0 /
        NULLIF(SUM(CASE WHEN w.Player_Out = p.Player_Id THEN 1 ELSE 0 END), 0), 2) AS batting_average
FROM Player p
JOIN Ball_by_Ball b ON p.Player_Id = b.Striker
LEFT JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id AND b.Over_Id = w.Over_Id
    AND b.Ball_Id = w.Ball_Id AND b.Innings_No = w.Innings_No AND w.Player_Out = p.Player_Id
GROUP BY p.Player_id, p.Player_Name
HAVING matches_played >= 20 AND batting_average >= 30 AND strike_rate >= 130
ORDER BY batting_average DESC, strike_rate DESC;
```

**Top Bowlers** *(minimum 20 matches, ranked by total wickets)*:
```sql
SELECT p.Player_Name AS Bowler,
    COUNT(w.Ball_Id) AS total_wickets,
    COUNT(DISTINCT CONCAT(b.Match_Id, '-', b.Innings_No)) AS total_Innings,
    ROUND(COUNT(w.Ball_Id) / COUNT(DISTINCT CONCAT(b.Match_Id, '-', b.Innings_No)), 2) AS Average_wickets
FROM wicket_taken w
JOIN ball_by_ball b ON w.Match_Id = b.Match_Id AND w.Over_Id = b.Over_Id
    AND w.Ball_Id = b.Ball_Id AND w.Innings_No = b.Innings_No
JOIN player p ON p.Player_Id = b.Bowler
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Average_wickets DESC;
```

Here's the breakdown of top player performances:

- **V Kohli** leads all batters with a batting average of **49.44** and a strike rate of 135.68 across 62 matches — the most dependable top-order batter in IPL history
- **AB de Villiers** stands out with an exceptional strike rate of **164.27** combined with a 46.86 average — the rare combination of speed and reliability
- **DJ Bravo** leads all bowlers with **81 total wickets** and an average of 1.93 wickets per match — the most impactful death-over bowler in the dataset
- Bowling styles analysis shows **Right-arm medium** bowlers account for the most wickets (617), highlighting the dominance of pace in T20 conditions

| Player | Matches | Total Runs | Strike Rate | Batting Avg |
|--------|---------|------------|-------------|-------------|
| V Kohli | 62 | 2472 | 135.68 | 49.44 |
| AB de Villiers | 57 | 1968 | 164.27 | 46.86 |
| DA Warner | 61 | 2348 | 140.94 | 46.04 |
| MS Dhoni | 60 | 1488 | 137.14 | 43.76 |

*Top batters filtered by batting average, strike rate, and matches played — ideal candidates for team selection*

---

### 3. Consistency Index — Identifying Reliable Performers

To go beyond career totals, I measured how stable each player's performance is across seasons using standard deviation of runs scored per season.

```sql
WITH player_season_details AS (
    SELECT p.Player_id, p.Player_Name, s.Season_Year,
        SUM(b.Runs_Scored) AS runs_in_season,
        COUNT(DISTINCT CONCAT(b.Match_Id, '-', b.Innings_No)) AS innings_played,
        ROUND(SUM(b.Runs_Scored) * 1.0 / NULLIF(COUNT(w.Player_Out), 0), 2) AS batting_average_in_season
    FROM Player p
    JOIN ball_by_ball b ON p.player_Id = b.Striker
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id AND b.Over_Id = w.Over_Id
        AND b.Ball_Id = w.ball_Id AND b.Innings_No = w.Innings_No AND w.Player_Out = p.Player_Id
    JOIN Matches m ON b.Match_Id = m.Match_Id
    JOIN Season s ON m.Season_Id = s.Season_Id
    GROUP BY p.Player_Id, p.Player_Name, s.Season_Year
),
player_consistency AS (
    SELECT Player_Id, Player_Name,
        COUNT(Season_Year) AS seasons_played,
        ROUND(AVG(runs_in_season), 2) AS avg_runs_per_season,
        ROUND(STDDEV_POP(runs_in_season), 2) AS runs_stddev
    FROM player_season_details
    GROUP BY Player_Id, Player_Name
)
SELECT Player_Id, Player_Name, seasons_played, avg_runs_per_season, runs_stddev
FROM player_consistency
WHERE seasons_played >= 3
  AND avg_runs_per_season > (SELECT AVG(avg_runs_per_season) FROM player_consistency)
  AND runs_stddev < 100
ORDER BY avg_runs_per_season DESC;
```

Here's the breakdown of the most consistent players across seasons:

- **RG Sharma**, **AM Rahane**, and **SK Raina** top the consistency rankings — high average runs per season combined with low standard deviation
- Players with a **low std dev and high average** (top-left of a consistency scatter plot) are ideal for building a stable team core
- Players with **high variation** may deliver impactful individual seasons but are risky picks for consistent squad roles

| Player | Seasons Played | Avg Runs/Season | Std Dev |
|--------|---------------|-----------------|---------|
| RG Sharma | 4 | 474.75 | 53.48 |
| AM Rahane | 4 | 461.75 | 74.52 |
| SK Raina | 4 | 461.00 | 75.54 |
| DR Smith | 4 | 426.75 | 87.74 |
| G Gambhir | 4 | 392.25 | 69.91 |

*Consistency Index — players filtered by seasons played ≥ 3, above-average runs, and std dev < 100*

---

### 4. Venue-Based Analysis — Does Location Matter?

To understand how venue conditions influence match outcomes and player performance, I analyzed win rates, bowling effectiveness, and batting averages broken down by ground.

**Toss Impact by Venue:**
```sql
SELECT v.venue_Name, m.Toss_Decide,
    COUNT(*) AS matches_played,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS toss_win_and_match_win,
    ROUND(SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
        AS toss_win_percentage
FROM Matches m
JOIN Venue v ON m.venue_Id = v.Venue_Id
WHERE m.Toss_Winner IS NOT NULL
GROUP BY v.Venue_Name, m.Toss_Decide
ORDER BY v.Venue_Name, toss_win_percentage DESC;
```

**Bowler Rankings by Venue** *(using Window Function)*:
```sql
WITH bowler_venue_details AS (
    SELECT v.Venue_Name, b.Bowler AS Bowler_id,
        COUNT(w.Player_Out) AS total_wickets,
        COUNT(DISTINCT b.Match_id) AS matches_played,
        COUNT(w.Player_Out) * 1.0 / COUNT(DISTINCT b.Match_id) AS avg_wickets
    FROM ball_by_ball b
    JOIN matches m ON b.Match_Id = m.Match_Id
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_id AND b.Ball_Id = w.Ball_Id
    GROUP BY v.Venue_Name, b.Bowler
)
SELECT Venue_Name, Bowler_Id, avg_wickets,
    RANK() OVER (PARTITION BY Venue_Name ORDER BY avg_wickets DESC) AS bowler_rank
FROM bowler_venue_details
ORDER BY Venue_Name, bowler_rank;
```

Here's the breakdown of venue-based findings:

- **M. Chinnaswamy Stadium** is RCB's strongest venue — 16 wins vs 11 losses, with the highest average runs scored (299.81 per match), confirming its batting-friendly nature
- **Toss impact is venue-specific**: At venues like Eden Gardens and Feroz Shah Kotla, batting first after winning the toss shows a significantly higher win rate; at others, chasing is the better strategy
- **Fewer wickets are taken at Chinnaswamy** compared to Wankhede Stadium, confirming pitch conditions strongly influence bowling effectiveness
- Players like **V Kohli at Chinnaswamy** and **RG Sharma at Wankhede** clearly dominate their home grounds — venue familiarity translates directly into better output

| Venue | RCB Wins | RCB Losses |
|-------|---------|------------|
| M Chinnaswamy Stadium | 16 | 11 |
| Feroz Shah Kotla | 2 | 0 |
| Subrata Roy Sahara Stadium | 1 | 0 |
| Wankhede Stadium | 1 | 3 |

*RCB wins and losses by venue — home advantage at Chinnaswamy is clearly the strongest pattern*

---

## What I Learned

- **🧩 Advanced Query Design:** Mastered multi-level CTEs, self-joins, and correlated subqueries to answer complex analytical questions across multiple related tables.
- **📊 Window Functions:** Applied `RANK()`, `STDDEV_POP()`, and partitioned aggregations to derive ranked and statistical insights.
- **💡 KPI Engineering:** Translated real-world cricket strategy concepts — win percentage, boundary rate, consistency index, dot ball rate — into precise SQL metrics.
- **🏏 Domain Thinking:** Learned to combine data analysis with cricket domain knowledge to derive insights that are statistically sound and practically actionable.
- **📈 Visual Storytelling:** Paired SQL outputs with Excel charts and scatter plots to present findings clearly to a non-technical audience.

---

## Conclusions

### Key Insights

1. **KPIs reveal what scorecards hide:** Win percentage alone doesn't tell the full story — dot ball rate, boundary percentage, and year-on-year run trends expose deeper structural strengths and weaknesses.
2. **Batting strength is RCB's core identity:** Kohli, ABD, and Warner consistently rank among the top batters in the league — but over-reliance on this group is also the team's biggest vulnerability.
3. **Consistency beats peaks:** Players with steady season-on-season performance (low std dev, high average) are more valuable squad picks than those with one breakout season.
4. **Venue strategy is non-negotiable:** The toss and batting/fielding decision should always be guided by venue history — a fixed strategy applied across all grounds is a statistically losing approach.

### Closing Thoughts

This project combined SQL analytics, cricket domain knowledge, and data visualization to generate real strategic insights — the kind that could inform an IPL team's actual auction decisions, squad selection, and match planning. It reinforced that data-driven decision making in sports is not just possible, but essential for building competitive teams sustainably.

---

## Project Files

| File | Description |
|------|-------------|
| `ipl_project_final.sql` | All SQL queries — objective and subjective |
| `FINAL_EXCEL.xlsx` | Excel dashboard with charts and KPI visuals |
| `FINAL_WORD_DOC.pdf` | Detailed written report with query outputs |
| `RCBIPL_SQL_Project.pptx` | PowerPoint presentation of findings |
