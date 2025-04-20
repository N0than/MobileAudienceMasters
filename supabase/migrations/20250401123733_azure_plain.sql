/*
  # Add new TV channels

  1. Changes
    - Add new TV channels to valid_channel constraint
    - Update existing constraint with new channels
    - Maintain existing data integrity

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing constraint
ALTER TABLE public.programs 
DROP CONSTRAINT IF EXISTS valid_channel;

-- Add new constraint with updated channel list
ALTER TABLE public.programs
ADD CONSTRAINT valid_channel CHECK (
  channel IN (
    'TF1', 'France 2', 'France 3', 'Canal+', 'France 5',
    'M6', 'Arte', 'C8', 'W9', 'TMC', 'TFX', 'CSTAR',
    'Gulli', 'TF1 Séries Films', '6ter', 'RMC Story',
    'RMC Découverte', 'Chérie 25', 'L''Équipe'
  )
);

-- Update policies to include new channels
DROP POLICY IF EXISTS "Programs can be updated by creators" ON public.programs;

CREATE POLICY "Programs can be updated by creators"
  ON public.programs
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