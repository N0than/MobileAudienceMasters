/*
  # Fix programs table RLS policies

  1. Changes
    - Enable RLS on programs table
    - Add policies for:
      - Public read access to all programs
      - Admin users can insert/update/delete programs
  
  2. Security
    - Enable RLS on programs table
    - Add policies to control access based on user role
*/

-- Enable RLS on programs table
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view programs" ON programs;
DROP POLICY IF EXISTS "Admin users can insert programs" ON programs;
DROP POLICY IF EXISTS "Admin users can update programs" ON programs;
DROP POLICY IF EXISTS "Admin users can delete programs" ON programs;

-- Create new policies
CREATE POLICY "Anyone can view programs"
ON programs FOR SELECT
TO public
USING (true);

CREATE POLICY "Admin users can insert programs"
ON programs FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

CREATE POLICY "Admin users can update programs"
ON programs FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);

CREATE POLICY "Admin users can delete programs"
ON programs FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'::app_role
  )
);