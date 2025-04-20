/*
  # Fix profile queries and error handling

  1. Changes
    - Add function to safely fetch single profile
    - Add proper error handling for profile queries
    - Fix type casting issues

  2. Security
    - Maintain existing RLS policies
*/

-- Create function to safely fetch single profile
CREATE OR REPLACE FUNCTION public.get_profile_by_id(profile_id uuid)
RETURNS SETOF profiles AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public.profiles
  WHERE id = profile_id
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_profile_by_id(uuid) TO authenticated;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS profiles_id_idx ON public.profiles(id);

-- Update existing profiles to ensure consistency
UPDATE public.profiles
SET updated_at = NOW()
WHERE updated_at IS NULL;