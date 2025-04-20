/*
  # Update Nouvelle Star badge image

  1. Changes
    - Update icon_url for "Nouvelle Star" badge with new image

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Nouvelle Star" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/KjYZjY06/Nouveau-projet-5.png'
WHERE name = 'Nouvelle Star';