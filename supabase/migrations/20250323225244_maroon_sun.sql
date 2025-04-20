/*
  # Create leaderboard table and fix predictions

  1. New Tables
    - leaderboard: Store user rankings and scores
      - id (uuid, primary key)
      - user_id (uuid, references auth.users)
      - total_score (integer)
      - precision_score (numeric)
      - rank (integer)
      - updated_at (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for authenticated users
*/

-- Create leaderboard table
CREATE TABLE IF NOT EXISTS public.leaderboard (
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

-- Create initial leaderboard entries for existing users
INSERT INTO public.leaderboard (
  user_id,
  total_score,
  precision_score,
  rank,
  updated_at
)
SELECT 
  u.id,
  0,
  0,
  ROW_NUMBER() OVER (ORDER BY u.created_at),
  NOW()
FROM auth.users u
LEFT JOIN public.leaderboard l ON l.user_id = u.id
WHERE l.id IS NULL
ON CONFLICT (user_id) DO NOTHING;