// Fonction de calcul de la précision
export function calculateAccuracy(predicted: number, actual: number): number | null {
  if (!predicted || !actual) return null;
  return predicted <= actual
    ? Math.round((predicted / actual) * 100 * 100) / 100
    : Math.round((actual / predicted) * 100 * 100) / 100;
}

// Fonction de calcul du score
export function calculateScore(accuracy: number | null): number {
  if (!accuracy) return 0;
  if (accuracy >= 95) return 100;
  if (accuracy >= 90) return 80;
  if (accuracy >= 85) return 60;
  if (accuracy >= 80) return 50;
  if (accuracy >= 70) return 30;
  if (accuracy >= 60) return 20;
  if (accuracy >= 50) return 10;
  return 0;
}