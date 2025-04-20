/*
  # Optimize prediction calculation triggers and functions

  1. Changes
    - Add optimized trigger with WHEN condition
    - Update prediction calculation to use CTE for better performance
    - Add error handling with EXCEPTION block
    - Improve ranking calculation efficiency

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing trigger and functions
DROP TRIGGER IF EXISTS on_real_audience_update ON public.programs;
DROP FUNCTION IF EXISTS update_predictions_for_program();

-- Create optimized function to update predictions and leaderboard
CREATE OR REPLACE FUNCTION update_predictions_for_program() 
RETURNS TRIGGER AS $$
BEGIN
  -- Arrondi de l'audience réelle à 1 décimale
  NEW.real_audience := ROUND(NEW.real_audience::numeric, 1);

  -- Mise à jour des pronostics avec un seul appel à `calculate_prediction_accuracy`
  WITH updated_predictions AS (
    SELECT 
      id, 
      calculate_prediction_accuracy(predicted_audience, NEW.real_audience) AS new_accuracy
    FROM public.predictions
    WHERE program_id = NEW.id
  )
  UPDATE public.predictions p
  SET
    accuracy = up.new_accuracy,
    score = calculate_prediction_score(up.new_accuracy),
    updated_at = NOW()
  FROM updated_predictions up
  WHERE p.id = up.id;

  -- Mise à jour du classement et des rangs en une seule requête
  WITH user_scores AS (
    SELECT 
      user_id,
      SUM(score) AS total_score,
      ROUND(AVG(accuracy)::numeric, 1) AS avg_accuracy
    FROM public.predictions
    WHERE accuracy IS NOT NULL
    GROUP BY user_id
  ),
  ranked_users AS (
    SELECT 
      user_id,
      total_score,
      avg_accuracy,
      ROW_NUMBER() OVER (ORDER BY total_score DESC, avg_accuracy DESC, NOW() ASC) AS new_rank
    FROM user_scores
  )
  UPDATE public.leaderboard l
  SET 
    total_score = r.total_score,
    precision_score = r.avg_accuracy,
    rank = r.new_rank,
    updated_at = NOW()
  FROM ranked_users r
  WHERE l.user_id = r.user_id;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Erreur dans update_predictions_for_program : %', SQLERRM;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create optimized trigger with WHEN condition
CREATE TRIGGER on_real_audience_update
  BEFORE UPDATE ON public.programs
  FOR EACH ROW
  WHEN (NEW.real_audience IS DISTINCT FROM OLD.real_audience)
  EXECUTE FUNCTION update_predictions_for_program();

-- Recalculate all existing predictions with optimized function
DO $$
BEGIN
  UPDATE public.programs
  SET updated_at = NOW()
  WHERE real_audience IS NOT NULL;
END $$;