/*
  # Fix program management and RLS policies

  1. Changes
    - Update RLS policies for program management
    - Fix program deletion policy
    - Add proper validation for program updates

  2. Security
    - Enable RLS
    - Add proper policies for program management
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
    (
      CASE WHEN channel IS NOT NULL THEN
        channel IN (
          'TF1', 'France 2', 'France 3', 'Canal+', 'France 5',
          'M6', 'Arte', 'C8', 'W9', 'TMC'
        )
      ELSE true
      END
    ) AND
    (
      CASE WHEN genre IS NOT NULL THEN
        genre IN (
          'Divertissement', 'Série', 'Film', 'Information',
          'Sport', 'Documentaire', 'Magazine', 'Jeunesse'
        )
      ELSE true
      END
    )
  );

CREATE POLICY "Programs can be deleted by creators"
  ON public.programs
  FOR DELETE
  TO authenticated
  USING (auth.uid() = created_by);

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;