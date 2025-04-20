/*
  # Add monthly leaderboard view

  1. Changes
    - Create view for monthly leaderboard
    - Calculate scores for current month only
    - Include user profile information
    - Add proper ordering

  2. Security
    - Grant access to authenticated users
*/

-- Create view for monthly leaderboard
CREATE VIEW public.monthly_leaderboard AS
WITH monthly_scores AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as monthly_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as monthly_accuracy,
    COUNT(*) as predictions_count
  FROM public.predictions p
  WHERE 
    EXTRACT(MONTH FROM p.created_at) = EXTRACT(MONTH FROM CURRENT_DATE)
    AND EXTRACT(YEAR FROM p.created_at) = EXTRACT(YEAR FROM CURRENT_DATE)
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
        ms.monthly_score DESC,
        ms.monthly_accuracy DESC
    ) as monthly_rank
  FROM monthly_scores ms
  JOIN public.profiles pr ON pr.id = ms.user_id
)
SELECT 
  user_id,
  username,
  avatar_url,
  monthly_score as total_score,
  monthly_accuracy as precision_score,
  monthly_rank as rank,
  predictions_count
FROM ranked_users;

-- Grant access to the view
GRANT SELECT ON public.monthly_leaderboard TO authenticated;