/*
  # Create leaderboard table and view

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

-- Create leaderboard table if it doesn't exist
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

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view all leaderboard entries" ON public.leaderboard;
DROP POLICY IF EXISTS "Users can update their own leaderboard entry" ON public.leaderboard;

-- Create policies
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

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.leaderboard_with_profiles;

-- Create view that joins leaderboard with profiles
CREATE VIEW public.leaderboard_with_profiles AS
SELECT 
  l.id,
  l.user_id,
  l.total_score,
  l.precision_score,
  l.rank,
  l.updated_at,
  p.username,
  p.avatar_url
FROM public.leaderboard l
JOIN public.profiles p ON p.id = l.user_id
ORDER BY 
  l.total_score DESC,
  l.precision_score DESC,
  l.updated_at ASC;

-- Grant access to the view
GRANT SELECT ON public.leaderboard_with_profiles TO authenticated;

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

-- Update ranks for all users
WITH ranked_users AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      ORDER BY total_score DESC, 
              precision_score DESC, 
              updated_at ASC
    ) as new_rank
  FROM public.leaderboard
)
UPDATE public.leaderboard l
SET rank = r.new_rank
FROM ranked_users r
WHERE l.id = r.id;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';