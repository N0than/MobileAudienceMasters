/*
  # Fix leaderboard table schema

  1. Changes
    - Drop existing leaderboard table
    - Recreate leaderboard table with correct user_id type (uuid)
    - Add proper foreign key constraints
    - Add indexes for performance
    - Add RLS policies

  2. Security
    - Enable RLS
    - Add policies for authenticated users
*/

-- Drop existing table
DROP TABLE IF EXISTS public.leaderboard CASCADE;

-- Create leaderboard table with correct types
CREATE TABLE public.leaderboard (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  total_score integer DEFAULT 0,
  precision_score numeric(5,2) DEFAULT 0,
  rank integer,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Users can view all leaderboard entries"
  ON public.leaderboard
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own leaderboard entry"
  ON public.leaderboard
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_leaderboard_user_id ON public.leaderboard(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_rank ON public.leaderboard(rank);
CREATE INDEX IF NOT EXISTS idx_leaderboard_total_score ON public.leaderboard(total_score DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_precision_score ON public.leaderboard(precision_score DESC);