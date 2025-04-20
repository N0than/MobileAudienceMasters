import React, { useState } from 'react';
import { Tv, Calendar, Film } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Program {
  id: string;
  name: string;
  channel: string;
  air_date: string;
  genre: string | null;
  image_url: string | null;
  description: string | null;
}

interface ProgramCardProps {
  program: Program;
  onPredictionSubmit?: () => void;
}

const ProgramCard: React.FC<ProgramCardProps> = ({ program, onPredictionSubmit }) => {
  const [prediction, setPrediction] = useState<number>(0);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [hasPredicted, setHasPredicted] = useState(false);
  const [userPrediction, setUserPrediction] = useState<number | null>(null);

  React.useEffect(() => {
    const checkExistingPrediction = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: existingPrediction } = await supabase
        .from('predictions')
        .select('id, predicted_audience')
        .match({ user_id: user.id, program_id: program.id });

      if (existingPrediction && existingPrediction.length > 0) {
        setHasPredicted(true);
        setUserPrediction(existingPrediction[0].predicted_audience);
      }
    };

    checkExistingPrediction();
  }, [program.id]);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR');
  };

  const handlePredictionChange = (value: number) => {
    setPrediction(Math.min(Math.max(value, 0), 10));
  };

  const handleSubmit = async () => {
    try {
      setSubmitting(true);
      setError(null);
      setSuccess(false);

      if (prediction <= 0 || prediction > 10) {
        throw new Error('Le pronostic doit être compris entre 0 et 10 millions');
      }

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Utilisateur non connecté');

      // Check if user already made a prediction for this program
      const { data: existingPrediction, error: checkError } = await supabase
        .from('predictions')
        .select('id')
        .match({ user_id: user.id, program_id: program.id });

      if (checkError) {
        throw checkError;
      }

      if (existingPrediction && existingPrediction.length > 0) {
        throw new Error('Vous avez déjà fait un pronostic pour ce programme');
      }

      // Insert new prediction
      const { error: insertError } = await supabase
        .from('predictions')
        .insert([{
          user_id: user.id,
          program_id: program.id,
          predicted_audience: prediction,
          submitted_at: new Date().toISOString()
        }]);

      if (insertError) throw insertError;

      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);

      if (onPredictionSubmit) {
        onPredictionSubmit();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="bg-white dark:bg-[#1B2028] rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow flex flex-col">
      <div className="relative h-48">
        {program.image_url ? (
          <img
            src={program.image_url}
            alt={program.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center">
            <Tv size={48} className="text-gray-400 dark:text-gray-500" />
          </div>
        )}
        <div className="absolute top-2 right-2 bg-purple-600 text-white px-3 py-1 rounded-full text-sm font-medium">
          {program.channel}
        </div>
      </div>

      <div className="p-4 flex flex-col flex-1">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
          {program.name}
        </h3>

        <div className="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-4">
          <Calendar size={16} className="mr-1" />
          <span>
            {formatDate(program.air_date)} - {program.broadcast_period === 'Prime-time' ? 'Prime-time' :
              program.broadcast_period === 'Access' ? 'Access' :
              program.broadcast_period === 'Night' ? 'Nuit' : 'Journée'}
          </span>
        </div>

        <div className="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-4">
          <Film size={16} className="mr-1" />
          <span>{program.genre}</span>
        </div>

        {program.description && (
          <p className="text-sm text-gray-600 dark:text-gray-300 mb-4 line-clamp-2">
            {program.description}
          </p>
        )}

        <div className="mt-auto space-y-4 pt-4">
          {hasPredicted && userPrediction !== null ? (
            <div className="text-center p-4 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
              <p className="text-sm text-gray-600 dark:text-gray-300 mb-2">
                Votre pronostic
              </p>
              <p className="text-2xl font-bold text-purple-600 dark:text-purple-400">
                {userPrediction.toFixed(1)}M
              </p>
            </div>
          ) : (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Votre pronostic (en millions)
            </label>
            <div className="flex items-center gap-4">
              <input
                type="range"
                min="0"
                max="10"
                step="0.1"
                value={prediction}
                onChange={(e) => handlePredictionChange(parseFloat(e.target.value))}
                disabled={hasPredicted}
                className="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-purple-600"
              />
              <div className="w-16 px-2 py-1 bg-gray-100 dark:bg-gray-700 rounded text-center">
                {prediction.toFixed(1)}
              </div>
            </div>
          </div>)}

          {error && (
            <p className="text-sm text-red-500">{error}</p>
          )}
          {success && (
            <div className="flex items-center gap-2 text-sm text-green-500">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
              <span>Pronostic enregistré avec succès !</span>
            </div>
          )}

          <button
            onClick={handleSubmit}
            disabled={submitting || hasPredicted}
            className={`w-full px-4 py-2 rounded-lg transition-colors ${
              hasPredicted 
                ? 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 cursor-not-allowed'
                : 'bg-purple-600 text-white hover:bg-purple-700'
            } disabled:opacity-50 disabled:cursor-not-allowed`}
          >
            {hasPredicted ? 'Pronostic déjà soumis' : submitting ? 'Envoi...' : 'Valider mon pronostic'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ProgramCard;