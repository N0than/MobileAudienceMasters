import React, { useState } from 'react';
import { User, Pencil, RefreshCw, Medal } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { Database } from '../../lib/database.types';
import AvatarSelector from '../auth/AvatarSelector';

type Profile = Database['public']['Tables']['profiles']['Row'];

interface ProfileFieldProps {
  label: string;
  value: string;
  onSave: (value: string) => Promise<void>;
  type?: string;
  editable?: boolean;
}

interface Badge {
  id: string;
  name: string;
  description: string;
  category: string;
  icon_url: string | null;
  earned_at: string | null;
  progress: number;
  is_earned: boolean;
}

const ProfileField = ({ label, value, onSave, type = 'text', editable = true }: ProfileFieldProps) => {
  const [isEditing, setIsEditing] = React.useState(false);
  const [tempValue, setTempValue] = React.useState(value);
  const [error, setError] = React.useState('');
  const [loading, setLoading] = React.useState(false);

  const handleSave = async () => {
    if (tempValue === value) {
      setIsEditing(false);
      return;
    }

    setLoading(true);
    setError('');

    try {
      await onSave(tempValue);
      setIsEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mb-6">
      <label className="block text-gray-500 dark:text-gray-400 text-sm mb-2">
        {label}
      </label>
      <div className="relative">
        <input
          type={type}
          value={isEditing ? tempValue : value}
          readOnly={!isEditing}
          onChange={(e) => setTempValue(e.target.value)}
          className={`w-full bg-gray-100 dark:bg-[#252A34] text-gray-900 dark:text-white rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-purple-500 ${!isEditing ? 'cursor-default' : ''}`}
        />
        {editable && !isEditing && (
          <button 
            type="button"
            className="absolute right-4 top-1/2 -translate-y-1/2 text-purple-500 hover:text-purple-600"
            onClick={() => setIsEditing(true)}
          >
            <Pencil size={16} />
          </button>
        )}
        {isEditing && (
          <div className="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-2">
            <button
              type="button"
              className="px-3 py-1 text-sm bg-purple-600 text-white rounded-md hover:bg-purple-700 disabled:opacity-50"
              onClick={handleSave}
              disabled={loading}
            >
              {loading ? 'Enregistrement...' : 'Valider'}
            </button>
            <button
              type="button"
              className="px-3 py-1 text-sm bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600"
              onClick={() => {
                setTempValue(value);
                setIsEditing(false);
                setError('');
              }}
              disabled={loading}
            >
              Annuler
            </button>
          </div>
        )}
      </div>
      {error && (
        <p className="mt-2 text-sm text-red-500">{error}</p>
      )}
    </div>
  );
};

const SettingsPage = () => {
  const [user, setUser] = useState<any>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [username, setUsername] = useState('');
  const [badges, setBadges] = useState<Badge[]>([]);
  const [isEditingPhoto, setIsEditingPhoto] = useState(false);
  const [tempPhotoURL, setTempPhotoURL] = useState('');
  const [photoError, setPhotoError] = useState('');
  const [showDicebear, setShowDicebear] = useState(false);
  const [loading, setLoading] = useState(false);
  const [loadingBadges, setLoadingBadges] = useState(true);

  // Get user metadata including avatar_url
  React.useEffect(() => {
    // Fetch user profile
    const getUserAndProfile = async () => {
      try {
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError) throw authError;
        
        setUser(user);
        
        if (user) {
          // Set initial photo URL from user metadata
          if (user.user_metadata?.avatar_url) {
            setTempPhotoURL(user.user_metadata.avatar_url);
          }
          // Set initial username from metadata
          if (user.user_metadata?.username) {
            setUsername(user.user_metadata.username);
          }

          const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id);
          
          if (profileError) throw profileError;
          
          if (profiles && profiles.length > 0) {
            setProfile(profiles[0]);
          }
        }
      } catch (error) {
        console.error('Error fetching user and profile:', error);
      }
    };
    getUserAndProfile();
  }, []);

  React.useEffect(() => {
    // Fetch user badges
    const fetchBadges = async () => {
      setLoadingBadges(true);
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        // First get all badges
        const { data: allBadges, error: badgesError } = await supabase
          .from('badges')
          .select('*')
          .order('category', { ascending: true });

        if (badgesError) throw badgesError;

        // Then get user's badge progress
        const { data: userProgress, error: progressError } = await supabase
          .from('user_badges')
          .select('*')
          .eq('user_id', user.id);

        if (progressError) throw progressError;

        // Combine badges with user progress
        const badgesWithProgress = allBadges?.map(badge => {
          const progress = userProgress?.find(p => p.badge_id === badge.id);
          return {
            badge_id: badge.id,
            name: badge.name,
            description: badge.description,
            category: badge.category,
            icon_url: badge.icon_url,
            earned_at: progress?.earned_at || null,
            progress: progress?.progress || 0,
            is_earned: progress?.earned_at !== null
          };
        }) || [];

        setBadges(badgesWithProgress);
      } catch (error) {
        console.error('Error fetching badges:', error);
      } finally {
        setLoadingBadges(false);
      }
    };

    fetchBadges();
  }, []);

  const getInitials = (name: string) => {
    return (profile?.username || '').slice(0, 2).toUpperCase();
  };

  const handleUpdateUsername = async (newUsername: string) => {
    if (!user) return;
    
    if (newUsername.length < 3) {
      throw new Error("Le nom d'utilisateur doit contenir au moins 3 caractères");
    }

    try {
      // Check if username is available
      const { data: existingUser } = await supabase
        .from('profiles')
        .select('username')
        .eq('username', newUsername)
        .neq('id', user.id)
        .single();

      if (existingUser) {
        throw new Error("Ce nom d'utilisateur est déjà pris");
      }

      // Update profile
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ 
          username: newUsername, 
          updated_at: new Date().toISOString() 
        })
        .eq('id', user.id);

      if (updateError) throw updateError;

      // Update auth metadata
      const { error: authError } = await supabase.auth.updateUser({
        data: { username: newUsername }
      });

      if (authError) {
        throw authError;
      }

      // Update local state
      setProfile(prev => prev ? { ...prev, username: newUsername } : null);
      setUsername(newUsername);
    } catch (error) {
      throw error instanceof Error 
        ? error 
        : new Error("Une erreur est survenue lors de la mise à jour du nom d'utilisateur");
    }
  };

  const handleUpdateEmail = async (newEmail: string) => {
    if (!user) return;
    const { error } = await supabase.auth.updateUser({ email: newEmail });
    if (error) throw error;
  };

  const handleUpdatePassword = async (newPassword: string) => {
    if (!user) return;
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
  };

  const handleUpdatePhoto = async () => {
    if (!user) return;
    setLoading(true);
    setPhotoError('');

    try {
      // Update auth metadata first
      const { error: authError } = await supabase.auth.updateUser({
        data: { avatar_url: tempPhotoURL }
      });
      if (authError) throw authError;

      // Then update profile
      const { error } = await supabase.from('profiles').update({
        avatar_url: tempPhotoURL,
        updated_at: new Date().toISOString()
      }).eq('id', user.id);
      if (error) throw error;

      setProfile(prev => prev ? { ...prev, avatar_url: tempPhotoURL } : null);
      setIsEditingPhoto(false);
    } catch (err) {
      setPhotoError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
        Paramètres
      </h1>

      <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm">
        <div className="flex items-center gap-4 mb-6">
          <div className="text-purple-500 mb-2">
            <User size={24} />
          </div>
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            Profil
          </h2>
        </div>

        <div className="mb-8">
          <label className="block text-gray-500 dark:text-gray-400 text-sm mb-2">
            Photo de profil
          </label>
          <div className="space-y-4">
            <div className="flex items-center gap-4">
              {user?.user_metadata?.avatar_url ? (
                <img
                  src={user.user_metadata.avatar_url}
                  alt="Photo de profil"
                  className="w-20 h-20 rounded-full object-cover"
                />
              ) : (
                <div className="w-20 h-20 bg-purple-500 rounded-full flex items-center justify-center text-white text-2xl font-semibold">
                  {getInitials(profile?.username || '')}
                </div>
              )}
              <button 
                type="button"
                className="text-purple-500 hover:text-purple-600"
                onClick={() => setIsEditingPhoto(true)}
              >
                <Pencil size={16} />
              </button>
            </div>
            
            {isEditingPhoto && (
              <div className="space-y-6">
                <div className="flex gap-4">
                  <button
                    type="button"
                    onClick={() => setShowDicebear(false)}
                    className={`flex-1 px-4 py-2 rounded-lg transition-colors ${
                      !showDicebear 
                        ? 'bg-purple-600 text-white' 
                        : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
                    }`}
                  >
                    URL personnalisée
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowDicebear(true)}
                    className={`flex-1 px-4 py-2 rounded-lg transition-colors ${
                      showDicebear 
                        ? 'bg-purple-600 text-white' 
                        : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
                    }`}
                  >
                    Avatar généré
                  </button>
                </div>

                {showDicebear ? (
                  <div className="space-y-4">
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      Choisissez un avatar généré par DiceBear Pixel Art
                    </p>
                    <AvatarSelector
                      selectedAvatar={tempPhotoURL}
                      onSelect={setTempPhotoURL}
                    />
                  </div>
                ) : (
                  <input
                    type="url"
                    value={tempPhotoURL}
                    onChange={(e) => setTempPhotoURL(e.target.value)}
                    placeholder="URL de votre photo de profil"
                    className="w-full bg-gray-100 dark:bg-[#252A34] text-gray-900 dark:text-white rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-purple-500"
                  />
                )}

                <div className="flex gap-2">
                  <button
                    type="button"
                    className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50"
                    onClick={handleUpdatePhoto}
                    disabled={loading || !tempPhotoURL}
                  >
                    {loading ? 'Enregistrement...' : 'Valider'}
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2 bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-300 dark:hover:bg-gray-600"
                    onClick={() => {
                      setTempPhotoURL('');
                      setIsEditingPhoto(false);
                      setPhotoError('');
                    }}
                    disabled={loading}
                  >
                    Annuler
                  </button>
                </div>
                {photoError && (
                  <p className="text-sm text-red-500">{photoError}</p>
                )}
              </div>
            )}
          </div>
        </div>


        <ProfileField
          label="Nom d'utilisateur"
          value={username || ''}
          onSave={handleUpdateUsername}
        />
        
        <ProfileField
          label="Email"
          value={user?.email || ''}
          onSave={handleUpdateEmail}
          type="email"
        />

        <ProfileField
          label="Mot de passe"
          value="••••••••••••"
          onSave={handleUpdatePassword}
          type="password"
        />
      </div>

      <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm mt-8">
        <div className="flex items-center gap-4 mb-6">
          <div className="text-purple-500">
            <Medal size={24} />
          </div>
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            Mes badges
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {loadingBadges ? (
            <div className="col-span-full flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
            </div>
          ) : badges.length === 0 ? (
            <div className="col-span-full text-center py-12 text-gray-500 dark:text-gray-400">
              Aucun badge disponible pour le moment
            </div>
          ) : (
            badges.map((badge) => (
              <div
                key={badge.badge_id}
                className={`relative bg-white dark:bg-[#252A34] rounded-xl p-6 border-2 dark:border-0 border-gray-200 transition-all ${
                  badge.is_earned
                    ? 'border-purple-500/50 dark:border-0'
                    : 'border-gray-200 dark:border-0'
                }`}
              >
                <div className="flex items-start gap-4">
                  <div className="relative">
                    <div className={`w-16 h-16 rounded-xl overflow-hidden ${
                      badge.progress < 100 && 'grayscale opacity-50'
                    }`}>
                      <img
                        src={badge.icon_url || 'https://i.postimg.cc/G90gpf2D/Chat-GPT-Image-14-avr-2025-01-10-15-1-min.png'}
                        alt={badge.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                    {badge.progress >= 100 && (
                      <div className="absolute -top-2 -right-2 bg-green-500 text-white rounded-full p-1">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                      </div>
                    )}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold text-gray-900 dark:text-white mb-1">
                      {badge.name}
                    </h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-3">
                      {badge.description}
                    </p>
                    <div className="relative w-full h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                      <div
                        className="absolute left-0 top-0 h-full bg-purple-500 transition-all duration-500"
                        style={{ width: `${badge.progress}%` }}
                      />
                    </div>
                    <div className="mt-1 text-xs text-right text-gray-500 dark:text-gray-400">
                      {Math.round(badge.progress)}%
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default SettingsPage;