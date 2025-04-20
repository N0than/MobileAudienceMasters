/*
  # Add accuracy calculation function and trigger

  1. Changes
    - Add function to calculate accuracy and score
    - Add trigger to update predictions when real_audience changes
    - Update existing predictions with new calculations

  2. Security
    - Maintain existing RLS policies
*/

-- Create function to update calculated_accuracy and calculated_score
CREATE OR REPLACE FUNCTION update_accuracy_and_score()
RETURNS TRIGGER AS $$
BEGIN
  -- Calcul de la précision (calculated_accuracy)
  UPDATE public.predictions
  SET calculated_accuracy = 
      CASE
          WHEN NEW.real_audience IS NULL THEN NULL  -- Si l'audience réelle est NULL, la précision est aussi NULL
          WHEN NEW.predicted_audience <= NEW.real_audience THEN ROUND((NEW.predicted_audience / NEW.real_audience) * 100, 2)  -- Précision pour sous-estimation ou égalité
          ELSE ROUND((NEW.real_audience / NEW.predicted_audience) * 100, 2)  -- Précision pour surestimation
      END,
  
      -- Calcul des points (calculated_score)
      calculated_score = 
      CASE
          WHEN calculated_accuracy >= 95 THEN 100   -- 95-100% : 100 points
          WHEN calculated_accuracy >= 90 THEN 80    -- 90-94.99% : 80 points
          WHEN calculated_accuracy >= 85 THEN 60    -- 85-89.99% : 60 points
          WHEN calculated_accuracy >= 80 THEN 50    -- 80-84.99% : 50 points
          WHEN calculated_accuracy >= 70 THEN 30    -- 70-79.99% : 30 points
          WHEN calculated_accuracy >= 60 THEN 20    -- 60-69.99% : 20 points
          WHEN calculated_accuracy >= 50 THEN 10    -- 50-59.99% : 10 points
          ELSE 0                                    -- < 50% : 0 point
      END
  WHERE id = NEW.id;  -- On met à jour uniquement la ligne concernée
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update calculated_accuracy and calculated_score
CREATE TRIGGER update_accuracy_and_score_trigger
  AFTER INSERT OR UPDATE OF real_audience
  ON public.predictions
  FOR EACH ROW
  EXECUTE FUNCTION update_accuracy_and_score();

-- Update existing predictions to calculate accuracy and score
UPDATE public.predictions p
SET updated_at = NOW()
WHERE real_audience IS NOT NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';