/*
  # Fix weekly leaderboard calculation

  1. Changes
    - Drop existing weekly leaderboard view
    - Create new view with proper week calculation
    - Add proper filtering for completed predictions
    - Add proper ordering and ranking

  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard
CREATE VIEW public.weekly_leaderboard AS
WITH current_week AS (
  SELECT 
    date_trunc('week', CURRENT_TIMESTAMP) as week_start,
    date_trunc('week', CURRENT_TIMESTAMP) + INTERVAL '6 days 23:59:59' as week_end
),
weekly_scores AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as weekly_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as weekly_accuracy,
    COUNT(*) as predictions_count
  FROM public.predictions p, current_week w
  WHERE 
    p.created_at >= w.week_start
    AND p.created_at <= w.week_end
    AND p.calculated_score IS NOT NULL
    AND p.calculated_accuracy IS NOT NULL
  GROUP BY p.user_id
  HAVING SUM(p.calculated_score) > 0
),
ranked_users AS (
  SELECT 
    ws.*,
    pr.username,
    pr.avatar_url,
    ROW_NUMBER() OVER (
      ORDER BY 
        ws.weekly_score DESC,
        ws.weekly_accuracy DESC,
        pr.created_at ASC
    ) as weekly_rank
  FROM weekly_scores ws
  JOIN public.profiles pr ON pr.id = ws.user_id
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
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;