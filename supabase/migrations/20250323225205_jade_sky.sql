/*
  # Fix predictions table and policies

  1. Changes
    - Drop and recreate predictions table
    - Add proper constraints and types
    - Add RLS policies with unique names
    - Add performance indexes

  2. Security
    - Enable RLS
    - Add proper policies for predictions
*/

-- Drop existing table and policies
DROP TABLE IF EXISTS public.predictions CASCADE;

-- Create predictions table
CREATE TABLE public.predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  program_id uuid REFERENCES public.programs(id) ON DELETE CASCADE NOT NULL,
  predicted_audience numeric(5,2) NOT NULL CHECK (predicted_audience >= 0 AND predicted_audience <= 15),
  submitted_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(user_id, program_id)
);

-- Enable RLS
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

-- Add RLS policies with unique names
CREATE POLICY "prediction_insert_policy"
  ON public.predictions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "prediction_select_policy"
  ON public.predictions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_predictions_user_id ON public.predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_program_id ON public.predictions(program_id);
CREATE INDEX IF NOT EXISTS idx_predictions_submitted_at ON public.predictions(submitted_at);