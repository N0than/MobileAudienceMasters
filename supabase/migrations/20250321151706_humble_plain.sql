/*
  # Fix profile sync and update policies

  1. Changes
    - Add function to sync profile changes with auth metadata
    - Add trigger for profile updates
    - Update profile update policy with proper checks
    - Fix variable references in trigger function

  2. Security
    - Maintain RLS on profiles table
    - Add proper validation for profile updates
*/

-- Function to sync profile updates with auth metadata
CREATE OR REPLACE FUNCTION public.sync_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users metadata when username changes
  IF (OLD.username IS DISTINCT FROM NEW.username) THEN
    UPDATE auth.users
    SET raw_user_meta_data = 
      COALESCE(raw_user_meta_data, '{}'::jsonb) || 
      jsonb_build_object('username', NEW.username)
    WHERE id = NEW.id;
  END IF;
  
  -- Always update timestamp on changes
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for profile updates
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_changes();

-- Update profile policies
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    LENGTH(COALESCE(username, '')) >= 3 AND
    NOT EXISTS (
      SELECT 1 
      FROM public.profiles 
      WHERE username = COALESCE(username, '') 
      AND id != auth.uid()
    )
  );