/*
  # Fix permissions for programs table

  1. Changes
    - Add RLS policies for programs table to allow admin users to manage programs
    - Add RLS policies for users to view programs
  
  2. Security
    - Enable RLS on programs table
    - Add policies for admin users to manage programs
    - Add policies for authenticated users to view programs
*/

-- Enable RLS on programs table
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Allow admin users to manage programs
CREATE POLICY "Admin users can manage programs"
ON programs
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

-- Allow authenticated users to view programs
CREATE POLICY "Authenticated users can view programs"
ON programs
FOR SELECT
TO authenticated
USING (true);