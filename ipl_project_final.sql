use ipl;
describe ipl.ball_by_ball;

SELECT coalesce(SUM(b.Runs_scored)) + coalesce(SUM(er.Extra_runs),0) AS total_runs
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
LEFT JOIN extra_runs er ON b.Ball_Id = er.Ball_Id
	AND b.Over_Id =er.Over_Id
	AND b.Match_Id = er.Match_Id
	AND b.Innings_No =er.Innings_No
WHERE m.Season_Id = 6
AND b.Team_Batting = (SELECT Team_Id FROM team WHERE Team_Name = 'Royal Challengers Bangalore');


 
 
SELECT COUNT(DISTINCT p.player_id) AS player_count
FROM player p
JOIN player_match pm ON p.player_id= pm.player_id
JOIN matches m ON pm.match_id = m.match_id
JOIN season s ON m.season_id = s.season_id
WHERE YEAR(p.DOB)< '1989' and s.Season_Year =2014;


SELECT COUNT(*)  AS RCB_win_2013
FROM matches m 
JOIN season s ON m.season_id=s.season_id
JOIN team t ON t.Team_Id=m.Match_Winner 
WHERE Season_Year = '2013' AND t.Team_Name ='Royal Challengers Bangalore';

SELECT p.Player_Id,p.Player_Name,
SUM(Runs_Scored) AS Runs_Scored, 
COUNT(ball_id) AS balls_faced, 
ROUND((SUM(Runs_Scored)/COUNT(ball_id))*100,2) AS Strike_Rate
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
JOIN player p ON b.Striker=p.Player_Id
JOIN season s ON s.Season_Id =m.Season_Id
JOIN 
	(SELECT Season_Id 
    FROM season 
    ORDER BY Season_Year DESC
    LIMIT 4) AS recent ON recent.Season_Id =s.Season_Id
GROUP BY p.Player_Id,p.Player_Name
ORDER BY Strike_Rate DESC LIMIT 10;


WITH player_details AS (
	SELECT striker AS Player_Id,
    SUM(Runs_Scored) AS total_runs,
    COUNT(DISTINCT CONCAT(Match_Id,'-',Innings_No)) AS total_innings
    FROM ball_by_ball
    GROUP BY striker )
    
    SELECT p.Player_name AS batsmen, pd.total_runs,pd.total_innings,
           ROUND((total_runs/total_innings),2) AS average_runs
	FROM player p 
    JOIN player_details pd ON p.Player_Id =pd.Player_Id
    ORDER BY average_runs DESC;
    
SELECT p.Player_Name AS Bowler,
	COUNT(w.Ball_Id) AS total_wickets,
    COUNT(DISTINCT CONCAT(b.Match_Id,'-',b.Innings_No)) AS total_Innings,
	ROUND(COUNT(w.Ball_Id)/COUNT(DISTINCT CONCAT(b.Match_Id,'-',b.Innings_No)),2) AS Average_wickets
FROM wicket_taken w
JOIN ball_by_ball b ON 
		w.Match_Id = b.Match_Id 
    AND w.Over_Id = b.Over_Id 
    AND w.Ball_Id = b.Ball_Id
    AND w.Innings_No = b.Innings_No
JOIN player p ON p.Player_Id =b.Bowler
GROUP BY p.Player_Id,p.Player_Name
ORDER BY Average_wickets desc;
	
WITH batting_data AS (
	SELECT s.Striker AS Player_Id,
			AVG(s.Runs_Scored) AS avg_runs
	FROM ball_by_ball s 
    GROUP BY s.Striker 
    ),
    bowling_data AS (
	SELECT b.Bowler AS Player_Id,
		COUNT(w.Ball_id) AS total_wickets
    FROM ball_by_ball b
    LEFT JOIN wicket_taken w ON
		b.Match_Id = w.Match_Id
	AND b.Over_Id = w.Over_Id
    AND b.Ball_Id = w.Ball_Id
    AND b.Innings_No = w. Innings_No
    GROUP BY b.Bowler
    )
    
    SELECT p.Player_Name,bd.avg_runs,wd.total_wickets
    FROM batting_data bd
    JOIN bowling_data wd ON bd.Player_Id = wd.Player_Id
    JOIN player p ON p.Player_Id =bd.Player_Id
    WHERE bd.avg_runs > (SELECT AVG(avg_runs) FROM batting_data)
		  AND wd.total_wickets >(SELECT AVG(total_wickets) FROM bowling_data)
          ORDER BY bd.avg_runs DESC;
          

CREATE TABLE rcb_record AS
SELECT 
    v.Venue_Name,
    SUM(CASE 
        WHEN m.Match_Winner = 2 AND (m.Team_1 = 2 OR m.Team_2 = 2) THEN 1
        ELSE 0
    END) AS Wins,
    SUM(CASE 
        WHEN m.Match_Winner != 2 AND (m.Team_1 = 2 OR m.Team_2 = 2)
             AND m.OutCome_Type = 1 THEN 1
        ELSE 0
    END) AS Losses
FROM matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
GROUP BY v.Venue_Name;
SELECT * FROM rcb_record;



SELECT bs.Bowling_skill AS bowling_style,
	COUNT(*) AS total_wickets
FROM Wicket_Taken wt
JOIN Ball_by_Ball b ON wt.Match_Id =b. Match_Id
	AND wt.Over_Id = b.Over_Id
    AND wt.Ball_Id = b.Ball_Id
    AND wt.Innings_No =b.Innings_No
JOIN Player p ON b.Bowler =p.Player_Id
JOIN Bowling_Style bs ON p.Bowling_skill =bs.Bowling_Id
GROUP BY bs.Bowling_skill
ORDER BY total_wickets DESC;


WITH team_season AS (
	SELECT t.Team_Id,s.Season_Year,
		SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
	FROM matches m
    JOIN season s ON s.Season_Id = m.Season_Id
    JOIN ball_by_ball b ON m.Match_Id = b.Match_Id
    JOIN team t ON b.Team_batting =t.Team_Id
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id
							AND b.Ball_Id = w.Ball_Id
	GROUP BY t.Team_Id,s.Season_Year
),

compare AS (
	SELECT tsc.Team_Id, tsc.Season_Year,
		   tsc.total_runs AS current_runs,
           tsc.total_wickets AS current_wickets,
           tsp.total_runs AS previous_runs,
           tsp.total_wickets AS previous_wickets
	FROM team_season tsc
    LEFT JOIN team_season tsp ON tsc.Team_Id = tsp.Team_Id
							AND tsc.Season_Year =tsp.Season_Year + 1 
			)
SELECT Team_Id,Season_Year, current_runs,current_wickets,previous_runs,previous_wickets,
		CASE WHEN previous_runs IS NULL THEN 'No Previous Data'
			 WHEN current_runs > previous_runs AND current_wickets > previous_wickets 
             THEN 'Better'
             WHEN current_runs = previous_runs AND current_wickets = previous_wickets 
             THEN 'Same'
             ELSE 'Worse'
		END AS performance_status
FROM compare
ORDER BY Team_Id,Season_Year;

SELECT t.Team_Name,
	(SUM(CASE WHEN m.Match_Winner =t.Team_Id THEN 1 ELSE 0 END)*100)/
    NULLIF(COUNT(CASE WHEN m.Match_Winner IS NOT NULL THEN 1 END),0) AS Win_Percentage
FROM Team t
JOIN Matches m ON m.Team_1 =t.Team_Id OR m.Team_2 =t.Team_ID
GROUP BY t.Team_Name
ORDER BY Win_Percentage DESC;

SELECT Player_Id,
	STDDEV(match_runs) AS consistency_index
FROM (
	SELECT Striker AS Player_Id,Match_Id,
		SUM(Runs_Scored) AS match_runs
	FROM ball_by_ball
    GROUP BY Striker,Match_Id) t
GROUP BY Player_Id
ORDER BY consistency_index ASC;


WITH bowler_venue_details AS (
	SELECT v.Venue_Name, b.Bowler AS Bowler_id,
		COUNT(w.Player_Out) AS total_wickets,
        COUNT(DISTINCT b.Match_id) AS matches_played,
        COUNT(w.Player_Out)*1.0 / COUNT(DISTINCT b.Match_id) AS avg_wickets
	FROM ball_by_ball b
    JOIN matches m ON b.Match_Id = m.Match_Id
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_id
							AND b.Ball_Id = w.Ball_Id
	GROUP BY v.Venue_Name,b.Bowler
) 

SELECT Venue_Name,Bowler_Id,avg_wickets,
	RANK() OVER (
			PARTITION BY Venue_Name
            ORDER BY avg_wickets DESC
            ) AS bowler_rank
FROM bowler_venue_details
ORDER BY Venue_Name,bowler_rank;

WITH player_season_details AS (
	SELECT p.Player_id,p.Player_Name,s.Season_Year,
    SUM(b.Runs_Scored) AS runs_in_season,
    COUNT(DISTINCT CONCAT(b.Match_Id,'-',b.Innings_No)) AS innings_played,
    COUNT(w.Player_Out) AS dismissals,
    ROUND(SUM(b.Runs_Scored)*1.0 / NULLIF(COUNT(w.Player_Out),0),2) AS batting_average_in_season
    FROM Player p
    JOIN ball_by_ball b ON p.player_Id =b.Striker
    LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id
							AND b.Over_Id =w.Over_Id
                            AND b.Ball_Id = w.ball_Id
                            AND b.Innings_No =w.Innings_No
                            AND w.Player_Out =p.Player_Id
	JOIN Matches m ON b.Match_Id =m.Match_Id
    JOIN Season s ON m.Season_Id = s.Season_Id
    GROUP BY p.Player_Id, p.Player_Name, s.Season_Year
     ),
     player_consistency AS (
			SELECT Player_Id,Player_Name,
				COUNT(Season_Year) AS seasons_played,
                ROUND(AVG(runs_in_season),2) AS avg_runs_per_season,
                ROUND(STDDEV_POP(runs_in_season),2) AS runs_stddev
			FROM player_season_details
            GROUP BY Player_Id,Player_Name
            )

SELECT Player_Id, Player_Name,seasons_played,avg_runs_per_season,runs_stddev
FROM player_consistency 
WHERE seasons_played >=3
AND avg_runs_per_season > (SELECT AVG(avg_runs_per_season)
                           FROM player_consistency)
AND runs_stddev < 100  
ORDER BY avg_runs_per_season DESC;


SELECT p.Player_Id,p.Player_Name,v.Venue_Id,v.Venue_Name,
	SUM(b.Runs_Scored) AS total_runs,
    COUNT(DISTINCT CONCAT(b.Match_Id,'-',b.Innings_No)) AS Innings_Played,
    ROUND(SUM(b.Runs_Scored)*1.0/ NULLIF(COUNT(DISTINCT CONCAT(b.Match_Id,'-',b.Innings_No)),0),2) AS avg_runs_per_inning
FROM Player p
JOIN Ball_by_Ball b ON p.Player_Id =b.Striker
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id =v.Venue_Id
GROUP BY p.Player_Id,p.Player_Name,v.Venue_Id,v.venue_Name
HAVING innings_played >=5
ORDER BY p.Player_Name,v.Venue_Name;
		
SELECT
  p.Player_Id,
  p.Player_Name,
  v.Venue_Id,
  v.Venue_Name,
  COUNT(DISTINCT CONCAT(wt.Match_Id, '-', wt.Over_Id, '-', wt.Ball_Id, '-', wt.Innings_No)) AS total_wickets
FROM
  Player p
  JOIN Ball_by_Ball b ON p.Player_Id = b.Bowler
  JOIN Matches m ON b.Match_Id = m.Match_Id
  JOIN Venue v ON m.Venue_Id = v.Venue_Id
  JOIN Wicket_Taken wt ON
    b.Match_Id = wt.Match_Id
    AND b.Over_Id = wt.Over_Id
    AND b.Ball_Id = wt.Ball_Id
    AND b.Innings_No = wt.Innings_No
GROUP BY
  p.Player_Id, p.Player_Name, v.Venue_Id, v.Venue_Name
ORDER BY
  v.Venue_Name, total_wickets DESC, p.Player_Name;
        
        
        
        
        
        
        
SELECT v.venue_Name, m.Toss_Decide,
	COUNT(*) AS matches_played,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS toss_win_and_match_win,
    ROUND(SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END)*100.0/COUNT(*),2 ) 
    AS toss_win_percentage
FROM Matches m
JOIN Venue v ON m.venue_Id = v.Venue_Id
WHERE m.Toss_Winner IS NOT NULL
GROUP BY v.Venue_Name, m.Toss_Decide
ORDER BY v.Venue_Name, toss_win_percentage DESC;


SELECT p.Player_Id,p.Player_Name, -- Subjective Question NO.4--
	SUM(CASE WHEN b.Striker= p.Player_id THEN b.Runs_Scored ELSE 0 END) AS total_runs,
    SUM(CASE WHEN b.Bowler= p.Player_id AND w.Player_Out IS NOT NULL THEN 1 END) AS total_wickets
FROM player p
LEFT JOIN ball_by_ball b ON p.Player_Id = b.Striker OR p.Player_Id= b.Bowler
LEFT JOIN wicket_taken w ON b.Match_Id =w.Match_Id AND b.Ball_Id = w. Ball_Id 
						AND b.Over_Id = w.Over_Id AND b.Innings_No =w.Innings_No
						AND w.Player_Out IS NOT NULL
GROUP BY p.Player_Id,p.Player_Name
HAVING total_runs >= 200 AND total_wickets >= 15
ORDER BY total_runs DESC, total_wickets DESC;


SELECT Player_Name,
	COUNT(*) AS Matches_Played,
    SUM(CASE WHEN Team_Id =Match_Winner THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(SUM(CASE WHEN Team_Id =Match_winner THEN 1 ELSE 0 END)*100/ COUNT(*),2) AS Win_Percentage
FROM ( SELECT DISTINCT m.Match_Id,p.Player_Name,pb.Team_Batting AS Team_Id,m.Match_Winner  
		FROM ball_by_ball pb
        JOIN Matches m ON pb.Match_Id =m.Match_Id
        JOIN player p ON pb.Striker =p.Player_Id ) AS player_matches
GROUP BY Player_Name
HAVING Matches_Played >=10 AND Matches_Won >=5
ORDER BY Win_Percentage DESC, Matches_Won DESC;


SELECT p.Player_Id,p.Player_Name,
	COUNT(DISTINCT b.Match_Id) AS matches_played,
    SUM(b.Runs_Scored) AS total_runs,
    ROUND(100.0* SUM(b.Runs_Scored)/COUNT(b.Ball_Id),2) AS strike_rate,
    ROUND(SUM(b.Runs_Scored)*1.0/NULLIF(SUM(CASE WHEN w.Player_Out=p.Player_Id THEN 1 ELSE 0 END),0),2) AS batting_average
FROM Player p
JOIN Ball_by_Ball b ON p.Player_Id = b.Striker
LEFT JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id 
						AND b.Over_Id =w.Over_Id
						AND b.Ball_Id =w.Ball_Id
						AND b.Innings_No =w.Innings_No
						AND w.Player_Out = p.Player_Id
GROUP BY p.Player_id,p.Player_Name
HAVING matches_played >=20
	AND batting_average >=30
	AND strike_rate >=130
ORDER BY batting_average DESC,strike_rate DESC;


WITH batting_details AS (
	SELECT p.Player_Id,p.Player_Name,
		SUM(b.Runs_Scored) AS total_runs
	FROM Player p
    JOIN Ball_by_Ball b ON p.Player_id = b.Striker
    GROUP BY p.Player_Id,p.Player_name),
    
    bowling_details AS (
		SELECT p.Player_Id,
			COUNT(DISTINCT CONCAT(w.Match_id,'-',w.ball_Id,'-',w.Innings_No)) AS total_wickets
		FROM Player p
        JOIN Ball_by_Ball b ON p.Player_Id=b.Bowler
        JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id 
			AND b.Over_Id = w.Over_Id
            AND b.Ball_Id = w.Ball_Id 
			AND b.Innings_No = w.Innings_No 
            AND w  .Player_Out IS NOT NULL
  GROUP BY p.Player_Id
)
SELECT
  bat.Player_Id, bat.Player_Name, bat.total_runs, bowl.total_wickets
FROM batting_details bat
JOIN bowling_details bowl ON bat.Player_Id = bowl.Player_Id
WHERE bat.total_runs >= 500 AND bowl.total_wickets >= 25
ORDER BY bat.total_runs DESC, bowl.total_wickets DESC;
 

SELECT * 
FROM matches
WHERE Team_2 = 'Delhi_Capitals';


   

 

