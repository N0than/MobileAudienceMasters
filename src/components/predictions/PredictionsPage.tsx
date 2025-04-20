import React, { useEffect, useState } from 'react';
import { Target, Clock, TrendingUp, RotateCw } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface StatCardProps {
  icon: React.ReactNode;
  title: string;
  value: string;
}

interface PredictionData {
  prediction_id: string;
  user_id: string;
  program_id: string;
  predicted_audience: number;
  real_audience: number | null;
  calculated_accuracy: number | null;
  calculated_score: number | null;
  program: {
    name: string;
    channel: string;
    image_url: string | null;
  };
}

const StatCard = ({ icon, title, value }: StatCardProps) => (
  <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm">
    <div className="text-purple-500 mb-4">{icon}</div>
    <div className="text-gray-500 dark:text-gray-400 text-sm mb-2">{title}</div>
    <div className="text-gray-900 dark:text-white text-3xl font-bold">{value}</div>
  </div>
);

const PredictionRow = ({ prediction }: { prediction: PredictionData }) => {
  return (
    <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 py-4 border-b border-gray-100 dark:border-gray-800">
      <div className="w-16 h-16 rounded-lg overflow-hidden bg-gray-200 dark:bg-gray-700 flex-shrink-0">
        {prediction.program.image_url ? (
          <img
            src={prediction.program.image_url}
            alt={prediction.program.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <Tv size={24} className="text-gray-400" />
          </div>
        )}
      </div>
      <div className="flex-grow w-full sm:w-auto">
        <h3 className="font-medium text-gray-900 dark:text-white">
          {prediction.program.name}
        </h3>
        <p className="text-sm text-gray-500 dark:text-gray-400">
          {prediction.program.channel}
        </p>
        <div className="mt-1 flex items-center gap-2">
          {prediction.real_audience !== null && (
            <>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                Audience réelle: {prediction.real_audience.toFixed(1)}M{' '}
              </span>
              {prediction.calculated_accuracy !== null && (
                <span className="text-sm font-medium px-2 py-0.5 rounded-full bg-purple-100 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400">
                  {prediction.calculated_accuracy.toFixed(1)}% précision
                </span>
              )}
            </>
          )}
        </div>
      </div>
      <div className="flex justify-between sm:flex-col sm:items-end mt-2 sm:mt-0 w-full sm:w-auto">
        <div className="font-medium text-gray-900 dark:text-white">
          {prediction.predicted_audience.toFixed(1)}M
        </div>
        {prediction.calculated_score !== null && (
          <span className="text-sm font-medium text-green-600 dark:text-green-400">
            {prediction.calculated_score > 0 ? `+${prediction.calculated_score} points` : '0 point'}
          </span>
        )}
      </div>
    </div>
  );
};

const PredictionsPage = () => {
  const [predictions, setPredictions] = useState<PredictionData[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<{
    averagePrecision: number,
    totalPredictions: number,
    totalPoints: number
  }>({
    averagePrecision: 0,
    totalPredictions: 0,
    totalPoints: 0
  });
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchPredictions = async () => {
    try {
      setLoading(true);
      setIsRefreshing(true);
      setError(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Utilisateur non connecté');

      const { data, error } = await supabase
        .from('predictions_with_accuracy')
        .select(`
          prediction_id,
          user_id,
          program_id,
          predicted_audience,
          real_audience,
          calculated_accuracy,
          calculated_score,
          program:programs(
            name,
            channel,
            image_url
          )
        `)
        .eq('user_id', user.id)
        .order('prediction_id', { ascending: false });

      if (error) throw error;

      setPredictions(data || []);
      
      // Calculate stats from predictions
      const validPredictions = data?.filter(p => p.real_audience !== null) || [];
      const totalPoints = validPredictions.reduce((sum, p) => sum + (p.calculated_score || 0), 0);
      const avgPrecision = validPredictions.length > 0
        ? validPredictions.reduce((sum, p) => sum + (p.calculated_accuracy || 0), 0) / validPredictions.length
        : 0;
      
      setStats({
        averagePrecision: Number(avgPrecision.toFixed(1)),
        totalPredictions: data?.length || 0,
        totalPoints: totalPoints
      });

    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchPredictions();

    // Subscribe to changes
    const subscription = supabase
      .channel('predictions_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'predictions'
      }, () => {
        fetchPredictions();
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  return (
    <div className="space-y-8">
      <h1 className="text-2xl lg:text-3xl font-bold text-gray-900 dark:text-white mb-6 lg:mb-8">Mes Pronostics</h1>
      
      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6">
        <StatCard
          icon={<Target size={24} />}
          title="Précision moyenne"
          value={`${stats.averagePrecision.toFixed(1)}%`}
        />
        <StatCard
          icon={<Clock size={24} />}
          title="Total pronostics"
          value={stats.totalPredictions.toString()}
        />
        <StatCard
          icon={<TrendingUp size={24} />}
          title="Points gagnés"
          value={stats.totalPoints.toString()}
        />
      </div>

      {/* Predictions History */}
      <div className="bg-white dark:bg-[#1B2028] rounded-lg p-4 lg:p-6 shadow-sm">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            Historique des pronostics
          </h2>
          <button 
            onClick={fetchPredictions}
            className="flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors shadow-sm"
            disabled={isRefreshing}
          >
            <RotateCw size={16} className={`${isRefreshing ? 'animate-spin' : ''}`} />
            <span>Actualiser</span>
          </button>
        </div>
        
        {loading ? (
          <div className="flex justify-center items-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
          </div>
        ) : error ? (
          <div className="text-center py-12">
            <p className="text-red-500">{error}</p>
          </div>
        ) : predictions.length === 0 ? (
          <div className="text-gray-500 dark:text-gray-400 text-center py-8">
            Aucun pronostic pour le moment
          </div>
        ) : (
          <div className="space-y-2">
            {predictions.map((prediction) => (
              <PredictionRow key={prediction.prediction_id} prediction={prediction} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default PredictionsPage;