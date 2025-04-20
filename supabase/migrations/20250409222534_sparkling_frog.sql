/*
  # Add view for registered users count

  1. Changes
    - Create view to get total number of registered users
    - Add proper indexes for performance

  2. Security
    - Grant access to authenticated users
*/

-- Create view for registered users count
CREATE VIEW public.registered_users_count AS
SELECT COUNT(*) as count
FROM public.profiles;

-- Grant access to the view
GRANT SELECT ON public.registered_users_count TO authenticated;

-- Add index to improve performance
CREATE INDEX IF NOT EXISTS idx_profiles_id ON public.profiles(id);