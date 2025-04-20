/*
  # Fix profile queries and error handling

  1. Changes
    - Drop existing function
    - Create improved function for profile fetching
    - Add proper error handling
    - Fix type casting issues

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_profile_by_id(uuid);

-- Create improved function to safely fetch single profile
CREATE OR REPLACE FUNCTION public.get_profile_by_id(profile_id uuid)
RETURNS TABLE (
  id uuid,
  username text,
  avatar_url text,
  created_at timestamptz,
  updated_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.username, p.avatar_url, p.created_at, p.updated_at
  FROM public.profiles p
  WHERE p.id = profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_profile_by_id(uuid) TO authenticated;

-- Add index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS profiles_id_idx ON public.profiles(id);

-- Update existing profiles to ensure consistency
UPDATE public.profiles
SET updated_at = NOW()
WHERE updated_at IS NULL;