/*
  # Update badge images with new designs

  1. Changes
    - Update icon_url for "Top Chef" badge
    - Update icon_url for "Hit Machine" badge
    - Update icon_url for "Graine de Star" badge
    - Update icon_url for "Nouvelle Star" badge

  2. Security
    - Maintain existing RLS policies
*/

-- Update the icon_url for the "Top Chef" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/KYHk8Bfy/Chat-GPT-Image-14-avr-2025-01-53-20.png'
WHERE name = 'Top Chef (Or)';

-- Update the icon_url for the "Hit Machine" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/7P1rND2F/Chat-GPT-Image-14-avr-2025-01-56-42.png'
WHERE name = 'Hit Machine (Argent)';

-- Update the icon_url for the "Graine de Star" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/pLk53gnr/Chat-GPT-Image-14-avr-2025-01-54-49.png'
WHERE name = 'Graine de Star (Bronze)';

-- Update the icon_url for the "Nouvelle Star" badge
UPDATE public.badges 
SET icon_url = 'https://i.postimg.cc/cHPnXwtc/Chat-GPT-Image-14-avr-2025-01-54-58.png'
WHERE name = 'Nouvelle Star';