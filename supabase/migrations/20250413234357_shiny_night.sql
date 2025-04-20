/*
  # Update Nouvelle Star badge image URL

  1. Changes
    - Update icon_url for "Nouvelle Star" badge
    - Keep all other badge data unchanged

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Nouvelle Star" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/bYGzs2rY/Chat-GPT-Image-14-avr-2025-01-10-15-2-min.png'
WHERE name = 'Nouvelle Star';