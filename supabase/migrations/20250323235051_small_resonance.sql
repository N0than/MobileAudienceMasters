/*
  # Fix program update policies

  1. Changes
    - Drop existing program policies
    - Create new policies with proper validation
    - Fix validation checks without using NEW table reference
    - Maintain creator-only restrictions

  2. Security
    - Maintain RLS enabled
    - Ensure proper validation of channel and genre
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Programs can be updated by creators" ON public.programs;
DROP POLICY IF EXISTS "Programs can be deleted by creators" ON public.programs;

-- Create improved policies for program management
CREATE POLICY "Programs can be updated by creators"
  ON public.programs
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = created_by)
  WITH CHECK (
    auth.uid() = created_by AND
    (channel IN (
      'TF1', 'France 2', 'France 3', 'Canal+', 'France 5',
      'M6', 'Arte', 'C8', 'W9', 'TMC'
    ) OR channel IS NULL) AND
    (genre IN (
      'Divertissement', 'Série', 'Film', 'Information',
      'Sport', 'Documentaire', 'Magazine', 'Jeunesse'
    ) OR genre IS NULL) AND
    (broadcast_period IN (
      'Day', 'Access', 'Prime-time', 'Night'
    ) OR broadcast_period IS NULL)
  );

-- Allow program deletion by creators
CREATE POLICY "Programs can be deleted by creators"
  ON public.programs
  FOR DELETE
  TO authenticated
  USING (auth.uid() = created_by);