/*
  # Add weekly leaderboard view and rename general leaderboard

  1. Changes
    - Create view for weekly leaderboard
    - Calculate scores for last 7 days
    - Include user profile information
    - Add proper ordering

  2. Security
    - Grant access to authenticated users
*/

-- Create view for weekly leaderboard
CREATE VIEW public.weekly_leaderboard AS
WITH weekly_scores AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as weekly_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as weekly_accuracy,
    COUNT(*) as predictions_count
  FROM public.predictions p
  WHERE 
    p.created_at >= CURRENT_DATE - INTERVAL '7 days'
    AND p.calculated_score IS NOT NULL
  GROUP BY p.user_id
),
ranked_users AS (
  SELECT 
    ms.*,
    pr.username,
    pr.avatar_url,
    ROW_NUMBER() OVER (
      ORDER BY 
        ms.weekly_score DESC,
        ms.weekly_accuracy DESC
    ) as weekly_rank
  FROM weekly_scores ms
  JOIN public.profiles pr ON pr.id = ms.user_id
)
SELECT 
  user_id,
  username,
  avatar_url,
  weekly_score as total_score,
  weekly_accuracy as precision_score,
  weekly_rank as rank,
  predictions_count
FROM ranked_users
WHERE weekly_score > 0;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;