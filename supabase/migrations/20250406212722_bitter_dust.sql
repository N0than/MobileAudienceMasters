/*
  # Add notifications system

  1. New Tables
    - notifications: Store user notifications
      - id (uuid, primary key)
      - user_id (uuid, references auth.users)
      - type (text): program, badge, info
      - title (text)
      - message (text)
      - read (boolean)
      - created_at (timestamptz)
      - updated_at (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for authenticated users
    - Add functions for notification management
*/

-- Create notifications table
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type text NOT NULL CHECK (type IN ('program', 'badge', 'info')),
  title text NOT NULL,
  message text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Users can view their own notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Function to update updated_at on notifications
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating updated_at
CREATE TRIGGER update_notifications_timestamp
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

-- Function to create program notification
CREATE OR REPLACE FUNCTION create_program_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert notification for all users when a new program is added
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message
  )
  SELECT 
    id as user_id,
    'program',
    'Nouveau programme',
    'Le programme "' || NEW.name || '" est maintenant disponible pour vos pronostics !'
  FROM auth.users;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new programs
CREATE TRIGGER on_program_created
  AFTER INSERT ON public.programs
  FOR EACH ROW
  EXECUTE FUNCTION create_program_notification();

-- Function to create badge notification
CREATE OR REPLACE FUNCTION create_badge_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Create notification when user reaches certain milestones
  IF NEW.total_score >= 1000 AND OLD.total_score < 1000 THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué',
      'Félicitations ! Vous avez obtenu le badge "Expert TV" !'
    );
  END IF;

  -- Add more badge conditions here
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for badge notifications
CREATE TRIGGER on_leaderboard_update
  AFTER UPDATE OF total_score ON public.leaderboard
  FOR EACH ROW
  EXECUTE FUNCTION create_badge_notification();

-- Add indexes for better performance
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);
CREATE INDEX idx_notifications_read ON public.notifications(read);

-- Create view for notifications with user info
CREATE VIEW public.notifications_with_user AS
SELECT 
  n.*,
  p.username,
  p.avatar_url
FROM public.notifications n
JOIN public.profiles p ON p.id = n.user_id;

-- Grant access to the view
GRANT SELECT ON public.notifications_with_user TO authenticated;