/*
  # Add broadcast period to programs table

  1. Changes
    - Add broadcast_period column to programs table
    - Update constraints for broadcast period validation
    - Modify existing programs to set default period

  2. Security
    - Maintain existing RLS policies
*/

-- Add broadcast_period column to programs table
ALTER TABLE public.programs 
ADD COLUMN broadcast_period text NOT NULL DEFAULT 'Prime-time'
CHECK (broadcast_period IN ('Day', 'Access', 'Prime-time', 'Night'));

-- Update existing programs to have a default period
UPDATE public.programs SET broadcast_period = 'Prime-time' WHERE broadcast_period IS NULL;