/*
  # Update user management functions and triggers

  1. Changes
    - Add function to generate random usernames
    - Update profile sync function
    - Add display name handling
    - Update existing users

  2. Security
    - Maintain existing RLS policies
    - Ensure proper error handling
*/

-- Function to generate a random username
CREATE OR REPLACE FUNCTION public.generate_random_username(base_name TEXT)
RETURNS TEXT AS $$
DECLARE
  result TEXT;
  random_suffix TEXT;
BEGIN
  -- Generate a random 4-character suffix
  random_suffix := array_to_string(ARRAY(
    SELECT chr((48 + round(random() * 9))::integer)
    FROM generate_series(1, 4)
  ), '');
  
  result := base_name || '_' || random_suffix;
  
  -- If username exists, try again
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = result) LOOP
    random_suffix := array_to_string(ARRAY(
      SELECT chr((48 + round(random() * 9))::integer)
      FROM generate_series(1, 4)
    ), '');
    result := base_name || '_' || random_suffix;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to sync profile changes with auth metadata and display name
CREATE OR REPLACE FUNCTION public.sync_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users metadata and display_name when username changes
  IF (OLD.username IS DISTINCT FROM NEW.username) THEN
    UPDATE auth.users
    SET 
      raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object('username', NEW.username),
      raw_app_meta_data = 
        COALESCE(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object('display_name', NEW.username)
    WHERE id = NEW.id;
  END IF;
  
  -- Always update timestamp on changes
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update existing users without display_name
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT 
      u.id,
      p.username
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
    WHERE (u.raw_app_meta_data->>'display_name') IS NULL
  LOOP
    UPDATE auth.users
    SET raw_app_meta_data = 
      COALESCE(raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('display_name', user_record.username)
    WHERE id = user_record.id;
  END LOOP;
END;
$$;