/*
  # Fix program policies and permissions

  1. Changes
    - Drop all existing program policies
    - Create new policies with unique names
    - Add proper admin permissions
    - Fix policy conflicts

  2. Security
    - Enable RLS
    - Add proper validation for program updates
*/

-- Drop all existing policies to avoid conflicts
DROP POLICY IF EXISTS "Programs can be created by authenticated users" ON programs;
DROP POLICY IF EXISTS "Programs can be viewed by all authenticated users" ON programs;
DROP POLICY IF EXISTS "Programs can be updated by admins" ON programs;
DROP POLICY IF EXISTS "Programs can be deleted by admins" ON programs;
DROP POLICY IF EXISTS "realtime update access" ON programs;
DROP POLICY IF EXISTS "programs_admin_manage" ON programs;
DROP POLICY IF EXISTS "programs_view_all" ON programs;
DROP POLICY IF EXISTS "programs_update_own" ON programs;

-- Enable RLS
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Create new policies with unique names
CREATE POLICY "admin_insert_programs"
ON programs
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

CREATE POLICY "admin_update_programs"
ON programs
FOR UPDATE
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
  ) AND
  (channel IN (
    'TF1', 'France 2', 'France 3', 'Canal+', 'France 5',
    'M6', 'Arte', 'C8', 'W9', 'TMC', 'TFX', 'CSTAR',
    'Gulli', 'TF1 Séries Films', '6ter', 'RMC Story',
    'RMC Découverte', 'Chérie 25', 'L''Équipe'
  ) OR channel IS NULL) AND
  (genre IN (
    'Divertissement', 'Série', 'Film', 'Information',
    'Sport', 'Documentaire', 'Magazine', 'Jeunesse'
  ) OR genre IS NULL) AND
  (broadcast_period IN (
    'Day', 'Access', 'Prime-time', 'Night'
  ) OR broadcast_period IS NULL)
);

CREATE POLICY "admin_delete_programs"
ON programs
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role = 'admin'
  )
);

CREATE POLICY "authenticated_view_programs"
ON programs
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "public_realtime_programs"
ON programs
FOR SELECT
TO public
USING (true);