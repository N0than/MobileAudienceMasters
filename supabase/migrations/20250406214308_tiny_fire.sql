/*
  # Fix program policies

  1. Changes
    - Drop existing policies to avoid conflicts
    - Recreate policies with unique names
    - Add proper validation for program updates

  2. Security
    - Maintain RLS enabled
    - Add proper validation for channel and genre
*/

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admin users can manage programs" ON programs;
DROP POLICY IF EXISTS "Programs are viewable by everyone" ON programs;
DROP POLICY IF EXISTS "Programs can be updated by creators" ON programs;
DROP POLICY IF EXISTS "Authenticated users can view programs" ON programs;

-- Enable RLS (in case it's not already enabled)
ALTER TABLE programs ENABLE ROW LEVEL SECURITY;

-- Create new policies with unique names
CREATE POLICY "programs_admin_manage"
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

CREATE POLICY "programs_view_all"
ON programs
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "programs_update_own"
ON programs
FOR UPDATE
TO authenticated
USING (auth.uid() = created_by)
WITH CHECK (
  auth.uid() = created_by AND
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