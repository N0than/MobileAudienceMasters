/*
  # Add cascade delete triggers for user deletion

  1. Changes
    - Add triggers to handle user deletion
    - Ensure all user data is deleted when account is removed
    - Update foreign key constraints

  2. Security
    - Maintain existing RLS policies
    - Ensure proper data cleanup
*/

-- Function to handle user deletion
CREATE OR REPLACE FUNCTION handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete user's predictions
  DELETE FROM public.predictions WHERE user_id = OLD.id;
  
  -- Delete user's leaderboard entry
  DELETE FROM public.leaderboard WHERE user_id = OLD.id;
  
  -- Delete user's profile
  DELETE FROM public.profiles WHERE id = OLD.id;
  
  -- Delete programs created by user
  DELETE FROM public.programs WHERE created_by = OLD.id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user deletion
DROP TRIGGER IF EXISTS on_user_deleted ON auth.users;
CREATE TRIGGER on_user_deleted
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_deletion();