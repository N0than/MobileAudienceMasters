/*
  # Fix database schema issues

  1. Changes
    - Add score and accuracy columns to predictions table
    - Add broadcast_period column to programs table
    - Update existing data with default values

  2. Security
    - Maintain existing RLS policies
*/

-- Add score column to predictions if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'predictions' AND column_name = 'score'
  ) THEN
    ALTER TABLE public.predictions 
    ADD COLUMN score integer DEFAULT 0,
    ADD COLUMN accuracy numeric(5,2) DEFAULT 0;
  END IF;
END $$;

-- Add broadcast_period to programs if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'programs' AND column_name = 'broadcast_period'
  ) THEN
    ALTER TABLE public.programs 
    ADD COLUMN broadcast_period text NOT NULL DEFAULT 'Prime-time'
    CHECK (broadcast_period IN ('Day', 'Access', 'Prime-time', 'Night'));
  END IF;
END $$;

-- Update existing programs to have a default period
UPDATE public.programs 
SET broadcast_period = 'Prime-time' 
WHERE broadcast_period IS NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';