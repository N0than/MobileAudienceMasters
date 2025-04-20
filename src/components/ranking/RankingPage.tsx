import React, { useEffect, useState } from 'react';
import { Trophy, Target, Users, RotateCw, UserPlus } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface LeaderboardEntry extends RankingEntry {
  id: string;
}

interface RankingEntry {
  user_id: string;
  username: string;
  avatar_url: string | null;
  total_score: number;
  precision_score: number;
  rank: number;
  predictions_count: number;
}

interface StatCardProps {
  icon: React.ReactNode;
  title: string;
  value: string;
  subtitle?: string;
}

interface PlayerRowProps {
  rank: number;
  username: string;
  avatarUrl?: string | null;
  points: number;
  precision: string;
  predictionsCount: number;
  isOnline?: boolean;
}

const getRankColor = (rank: number) => {
  switch (rank) {
    case 1: return 'text-yellow-500';
    case 2: return 'text-gray-400';
    case 3: return 'text-amber-600';
    default: return 'text-gray-500 dark:text-gray-400';
  }
};

const getBgColor = (username: string) => {
  const colors = [
    'bg-red-500',
    'bg-purple-500',
    'bg-blue-500',
    'bg-green-500'
  ];
  const index = username.length % colors.length;
  return colors[index];
};

const StatCard = ({ icon, title, value, subtitle }: StatCardProps) => (
  <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm">
    <div className="text-purple-500 mb-4">{icon}</div>
    <div className="text-gray-500 dark:text-gray-400 text-sm">{title}</div>
    <div className="text-gray-900 dark:text-white text-3xl font-bold mb-1">{value}</div>
    {subtitle && <div className="text-gray-500 dark:text-gray-400 text-sm mt-1">{subtitle}</div>}
  </div>
);

const PlayerRow = ({ rank, username, avatarUrl, points, precision, predictionsCount }: PlayerRowProps) => {
  const getInitials = (username: string) => {
    return username.slice(0, 2).toUpperCase();
  };

  const truncateUsername = (username: string) => {
    return username.length > 12 ? username.substring(0, 12) + '...' : username;
  };

  return (
    <div className="flex items-center justify-between py-4 border-b border-gray-100 dark:border-gray-800">
      <div className="flex items-center space-x-4">
        <span className={`w-8 text-lg font-semibold ${getRankColor(rank)}`}>#{rank}</span>
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt={`Avatar de ${username}`}
            className="w-10 h-10 rounded-full object-cover"
          />
        ) : (
          <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white ${getBgColor(username)}`}>
            {getInitials(username)}
          </div>
        )}
        <div className="flex items-center gap-2">
          <span className="font-medium text-gray-900 dark:text-white" title={username}>{truncateUsername(username)}</span>
        </div>
      </div>
      <div className="flex items-center space-x-8">
        <div className="w-20 text-right">
          <div className="font-medium text-gray-900 dark:text-white">{points}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400">points</div>
        </div>
        <div className="w-20 text-right">
          <div className="font-medium text-gray-900 dark:text-white">{precision}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400">précision</div>
        </div>
        <div className="w-20 text-right">
          <div className="font-medium text-gray-900 dark:text-white">{predictionsCount}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400">pronostics</div>
        </div>
      </div>
    </div>
  );
};

const RankingPage = () => {
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [weeklyLeaderboard, setWeeklyLeaderboard] = useState<RankingEntry[]>([]);
  const [monthlyLeaderboard, setMonthlyLeaderboard] = useState<RankingEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingWeekly, setLoadingWeekly] = useState(true);
  const [loadingMonthly, setLoadingMonthly] = useState(true);
  const [topUser, setTopUser] = useState<{ username: string; score: number } | null>(null);
  const [topPrecisionUser, setTopPrecisionUser] = useState<{ username: string; precision: number } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [errorWeekly, setErrorWeekly] = useState<string | null>(null);
  const [errorMonthly, setErrorMonthly] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [stats, setStats] = useState({
    topScore: 0,
    topPrecision: 0,
    activePlayers: 0,
    registeredUsers: 0
  });

  const truncateUsername = (username: string) => {
    return username.length > 12 ? username.substring(0, 12) + '...' : username;
  };

  const fetchLeaderboard = async () => {
    try {
      setLoading(true);
      const { data: predictions, error: predictionsError } = await supabase
        .from('predictions_with_accuracy')
        .select('user_id, calculated_score, calculated_accuracy')
        .not('real_audience', 'is', null);

      if (predictionsError) throw predictionsError;

      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, username, avatar_url');

      if (profilesError) throw profilesError;

      const userScores = predictions?.reduce((acc, pred) => {
        const userId = pred.user_id;
        if (!acc[userId]) {
          acc[userId] = {
            total_score: 0,
            predictions: 0,
            total_accuracy: 0
          };
        }
        acc[userId].total_score += pred.calculated_score || 0;
        acc[userId].predictions += 1;
        acc[userId].total_accuracy += pred.calculated_accuracy || 0;
        return acc;
      }, {} as Record<string, { total_score: number; predictions: number; total_accuracy: number }>);

      const leaderboard = profiles?.map(profile => {
        const scores = userScores?.[profile.id] || { total_score: 0, predictions: 0, total_accuracy: 0 };
        return {
          id: profile.id,
          user_id: profile.id,
          username: profile.username,
          avatar_url: profile.avatar_url,
          total_score: scores.total_score,
          predictions_count: scores.predictions,
          precision_score: scores.predictions > 0 
            ? Number((scores.total_accuracy / scores.predictions).toFixed(1))
            : 0
        };
      }).sort((a, b) => b.total_score - a.total_score || b.precision_score - a.precision_score);

      const rankedLeaderboard = leaderboard?.map((entry, index) => ({
        ...entry,
        rank: index + 1
      }));

      setLeaderboard(rankedLeaderboard || []);

      // Calculate stats
      if (rankedLeaderboard && rankedLeaderboard.length > 0) {
        setStats({
          topScore: Math.max(...rankedLeaderboard.map(e => e.total_score || 0)),
          topPrecision: Math.max(...rankedLeaderboard.map(e => e.precision_score || 0)),
          activePlayers: rankedLeaderboard.filter(e => e.total_score > 0).length,
          registeredUsers: 0
        });
        
        // Find user with top score
        const topScorer = rankedLeaderboard.reduce((prev, current) => 
          (prev.total_score || 0) > (current.total_score || 0) ? prev : current
        );
        setTopUser({
          username: topScorer.username,
          score: topScorer.total_score || 0
        });

        // Find user with top precision
        const topPrecisionScorer = rankedLeaderboard.reduce((prev, current) => 
          (prev.precision_score || 0) > (current.precision_score || 0) ? prev : current
        );
        setTopPrecisionUser({
          username: topPrecisionScorer.username,
          precision: topPrecisionScorer.precision_score || 0
        });
      }

      // Get total registered users count
      const { data: registeredUsersData } = await supabase
        .from('registered_users_count')
        .select('count')
        .single();

      if (registeredUsersData) {
        setStats(prev => ({
          ...prev,
          registeredUsers: registeredUsersData.count
        }));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  };

  const fetchWeeklyLeaderboard = async () => {
    try {
      setLoadingWeekly(true);
      const { data, error } = await supabase.from('weekly_user_rankings').select('*');

      if (error) throw error;
      setWeeklyLeaderboard(data || []);
    } catch (err) {
      setErrorWeekly(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoadingWeekly(false);
    }
  };

  const fetchMonthlyLeaderboard = async () => {
    try {
      setLoadingMonthly(true);
      const { data, error } = await supabase.from('classement_mois_en_cours').select('*');

      if (error) throw error;
      setMonthlyLeaderboard(data || []);
    } catch (err) {
      setErrorMonthly(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoadingMonthly(false);
    }
  };

  useEffect(() => {
    fetchLeaderboard();
    fetchWeeklyLeaderboard();
    fetchMonthlyLeaderboard();

    // Subscribe to changes
    const predictionSubscription = supabase
      .channel('predictions_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'predictions_with_accuracy'
      }, () => {
        fetchLeaderboard();
        fetchWeeklyLeaderboard();
        fetchMonthlyLeaderboard();
      })
      .subscribe();

    return () => {
      predictionSubscription.unsubscribe();
    };
  }, []);

  return (
    <div className="space-y-8">
      <h1 className="text-2xl lg:text-3xl font-bold text-gray-900 dark:text-white mb-6 lg:mb-8">
        Classements des joueurs
      </h1>
      
      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6">
        <StatCard
          icon={<Trophy size={24} />}
          title="Score le plus élevé"
          value={`${stats.topScore}`}
          subtitle={topUser?.username}
        />
        <StatCard
          icon={<Target size={24} />}
          title="Meilleure précision"
          value={`${stats.topPrecision.toFixed(1)}%`}
          subtitle={topPrecisionUser?.username}
        />
        <StatCard
          icon={<UserPlus size={24} />}
          title="Joueurs inscrits"
          value={stats.registeredUsers.toString()}
          subtitle="Participants"
        />
      </div>

      {/* Players Ranking */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        <div className="bg-white dark:bg-[#1B2028] rounded-lg p-4 lg:p-6 shadow-sm xl:col-span-1">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
              Classement Général
            </h2>
            <button 
              onClick={fetchLeaderboard}
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
          ) : leaderboard.length === 0 ? (
            <div className="text-center py-12 text-gray-500 dark:text-gray-400">
              Aucun classement disponible pour le moment
            </div>
          ) : (
            <div className="space-y-2">
              {leaderboard.map((entry) => (
                <div key={entry.id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 py-4 border-b border-gray-100 dark:border-gray-800">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-4">
                      <span className={`w-8 text-lg font-semibold ${getRankColor(entry.rank)}`}>#{entry.rank}</span>
                      {entry.avatar_url ? (
                        <img
                          src={entry.avatar_url}
                          alt={`Avatar de ${entry.username}`}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                      ) : (
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white ${getBgColor(entry.username)}`}>
                          {entry.username.slice(0, 2).toUpperCase()}
                        </div>
                      )}
                      <span className="font-medium text-gray-900 dark:text-white" title={entry.username}>{truncateUsername(entry.username)}</span>
                    </div>
                  </div>
                  <div className="flex justify-between sm:justify-end items-center gap-4 sm:gap-8 mt-2 sm:mt-0 w-full sm:w-auto">
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.total_score}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">points</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.precision_score.toFixed(1)}%</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">précision</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.predictions_count || 0}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">pronostics</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-white dark:bg-[#1B2028] rounded-lg p-4 lg:p-6 shadow-sm xl:col-span-1">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
              Classement du Mois
            </h2>
            <button 
              onClick={fetchMonthlyLeaderboard}
              className="flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors shadow-sm"
              disabled={isRefreshing}
            >
              <RotateCw size={16} className={`${isRefreshing ? 'animate-spin' : ''}`} />
              <span>Actualiser</span>
            </button>
          </div>
          
          {loadingMonthly ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
            </div>
          ) : errorMonthly ? (
            <div className="text-center py-12">
              <p className="text-red-500">{errorMonthly}</p>
            </div>
          ) : monthlyLeaderboard.length === 0 ? (
            <div className="text-gray-500 dark:text-gray-400 text-center py-8">
              Aucun classement disponible pour le moment
            </div>
          ) : (
            <div className="space-y-2">
              {monthlyLeaderboard.map((entry) => (
                <div key={entry.user_id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 py-4 border-b border-gray-100 dark:border-gray-800">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-4">
                      <span className={`w-8 text-lg font-semibold ${getRankColor(entry.rank)}`}>#{entry.rank}</span>
                      {entry.avatar_url ? (
                        <img
                          src={entry.avatar_url}
                          alt={`Avatar de ${entry.username}`}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                      ) : (
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white ${getBgColor(entry.username)}`}>
                          {entry.username.slice(0, 2).toUpperCase()}
                        </div>
                      )}
                      <span className="font-medium text-gray-900 dark:text-white" title={entry.username}>{truncateUsername(entry.username)}</span>
                    </div>
                  </div>
                  <div className="flex justify-between sm:justify-end items-center gap-4 sm:gap-8 mt-2 sm:mt-0 w-full sm:w-auto">
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.total_score}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">points</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.precision_score.toFixed(1)}%</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">précision</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.predictions_count || 0}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">pronostics</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-white dark:bg-[#1B2028] rounded-lg p-4 lg:p-6 shadow-sm xl:col-span-1">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
              Classement de la Semaine
            </h2>
            <button 
              onClick={fetchWeeklyLeaderboard}
              className="flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors shadow-sm"
              disabled={isRefreshing}
            >
              <RotateCw size={16} className={`${isRefreshing ? 'animate-spin' : ''}`} />
              <span>Actualiser</span>
            </button>
          </div>
          
          {loadingWeekly ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
            </div>
          ) : errorWeekly ? (
            <div className="text-center py-12">
              <p className="text-red-500">{errorWeekly}</p>
            </div>
          ) : weeklyLeaderboard.length === 0 ? (
            <div className="text-gray-500 dark:text-gray-400 text-center py-8">
              Aucun classement disponible pour le moment
            </div>
          ) : (
            <div className="space-y-2">
              {weeklyLeaderboard.map((entry) => (
                <div key={entry.user_id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 py-4 border-b border-gray-100 dark:border-gray-800">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-4">
                      <span className={`w-8 text-lg font-semibold ${getRankColor(entry.rank)}`}>#{entry.rank}</span>
                      {entry.avatar_url ? (
                        <img
                          src={entry.avatar_url}
                          alt={`Avatar de ${entry.username}`}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                      ) : (
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white ${getBgColor(entry.username)}`}>
                          {entry.username.slice(0, 2).toUpperCase()}
                        </div>
                      )}
                      <span className="font-medium text-gray-900 dark:text-white" title={entry.username}>{truncateUsername(entry.username)}</span>
                    </div>
                  </div>
                  <div className="flex justify-between sm:justify-end items-center gap-4 sm:gap-8 mt-2 sm:mt-0 w-full sm:w-auto">
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.total_score}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">points</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.precision_score.toFixed(1)}%</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">précision</div>
                    </div>
                    <div className="w-16 text-right">
                      <div className="font-medium text-gray-900 dark:text-white">{entry.predictions_count || 0}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">pronostics</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default RankingPage;