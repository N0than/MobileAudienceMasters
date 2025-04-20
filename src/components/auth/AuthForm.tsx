import React, { useState } from 'react';
import { supabase } from '../../lib/supabase';
import AvatarSelector from './AvatarSelector';

export const AuthForm = () => {
  const [isLogin, setIsLogin] = useState(true);
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [selectedAvatar, setSelectedAvatar] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [validationErrors, setValidationErrors] = useState({
    username: '',
    email: '',
    password: ''
  });

  const validateForm = () => {
    const errors = {
      username: '',
      email: '',
      password: ''
    };

    if (!isLogin) {
      if (!username) {
        errors.username = "Le nom d'utilisateur est requis";
      } else if (username.length < 3) {
        errors.username = "Le nom d'utilisateur doit contenir au moins 3 caractères";
      } else if (!/^[a-zA-Z0-9_]+$/.test(username)) {
        errors.username = "Le nom d'utilisateur ne peut contenir que des lettres, chiffres et _";
      }
    }

    if (!email) {
      errors.email = "L'email est requis";
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      errors.email = "L'email n'est pas valide";
    }

    if (!password) {
      errors.password = "Le mot de passe est requis";
    } else if (password.length < 6) {
      errors.password = "Le mot de passe doit contenir au moins 6 caractères";
    }

    setValidationErrors(errors);
    return !Object.values(errors).some(error => error !== '');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setValidationErrors({ username: '', email: '', password: '' });

    if (!validateForm()) {
      return;
    }

    setLoading(true);

    try {
      if (isLogin) {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password
        });
        if (error) throw error;
      } else {
        // Create new user
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              username,
              avatar_url: selectedAvatar || undefined
            }
          }
        });

        if (error) throw error;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setValidationErrors({ username: '', email: '', password: '' });

    if (!email) {
      setValidationErrors(prev => ({ ...prev, email: "L'email est requis" }));
      return;
    }

    if (!/\S+@\S+\.\S+/.test(email)) {
      setValidationErrors(prev => ({ ...prev, email: "L'email n'est pas valide" }));
      return;
    }

    setLoading(true);

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      if (error) throw error;
      alert("Si un compte existe avec cette adresse email, vous recevrez un lien de réinitialisation.");
      setShowForgotPassword(false);
      setEmail('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0073e6] flex flex-col">
      <main className="flex-1 flex">
        <div className="w-full md:w-1/3 bg-white p-8 flex items-center justify-center">
          <div className="w-full max-w-md bg-white rounded-lg p-4 sm:p-6 md:p-8">
            <img
              src="https://i.postimg.cc/xjHxd9KK/logo-1.png" 
              alt="Logo" 
              className={`w-full max-w-[280px] mx-auto object-contain transition-all duration-500 ease-in-out transform ${
                showForgotPassword ? 'mb-[30px] scale-[0.85] -translate-y-12' :
                isLogin ? 'mb-6' : 'mb-[30px] scale-[0.85] -translate-y-12'
              }`}
            />
            <h1 className={`text-3xl font-normal text-gray-900 transition-all duration-300 ${
              showForgotPassword ? '-mt-20 mb-1' :
              isLogin ? 'mb-4' : '-mt-20 mb-1'
            }`}>
              {showForgotPassword ? 'Mot de passe oublié' : isLogin ? 'Connexion' : 'Créer un compte'}
            </h1>
            <p className={`text-sm text-gray-600 transition-all duration-300 ${
              showForgotPassword ? 'mb-6' : isLogin ? 'mb-6' : 'mb-4'
            }`}>
              {showForgotPassword ? (
                'Retourner à la '
              ) : isLogin ? (
                'Pas encore de compte ? '
              ) : (
                'Déjà un compte ? '
              )}
              <button
                onClick={() => {
                  setShowForgotPassword(false);
                  if (!showForgotPassword) setIsLogin(!isLogin);
                }}
                className="text-[#0073e6] hover:text-[#0066cc] font-medium transition-colors duration-300"
              >
                {showForgotPassword ? 'connexion' : isLogin ? "S'inscrire" : 'Se connecter'}
              </button>
            </p>
            <form onSubmit={showForgotPassword ? handleForgotPassword : handleSubmit} className="transition-all duration-500">
              <div className="rounded-md shadow-sm -space-y-px">
                {!isLogin && !showForgotPassword && (
                  <div className="space-y-1 mt-4 mb-2 transition-all duration-500 transform">
                    <div>
                      <AvatarSelector
                        selectedAvatar={selectedAvatar}
                        onSelect={setSelectedAvatar}
                      />
                    </div>

                    <label htmlFor="username" className="sr-only">
                      Nom d'utilisateur
                    </label>
                    <input
                      id="username"
                      name="username"
                      type="text"
                      className={`appearance-none relative block w-full px-3 py-2 border !ring-0 ${
                        validationErrors.username ? 'border-red-500' : 'border-gray-300'
                      } placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#0073e6] focus:border-[#0073e6] sm:text-sm`}
                      placeholder="Nom d'utilisateur"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                    />
                    {validationErrors.username && (
                      <p className="text-sm text-red-500 mt-1">{validationErrors.username}</p>
                    )}
                  </div>
                )}
                <div className={showForgotPassword ? 'mt-4' : ''}>
                  <label htmlFor="email-address" className="sr-only">
                    Adresse email
                  </label>
                  <input
                    id="email-address"
                    name="email"
                    type="email"
                    autoComplete="email"
                    className={`appearance-none relative block w-full px-3 py-2 border !ring-0 ${
                      validationErrors.email ? 'border-red-500' : 'border-gray-300'
                    } placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#0073e6] focus:border-[#0073e6] sm:text-sm mb-2`}
                    placeholder="Adresse email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)} 
                  />
                  {validationErrors.email && (
                    <p className="text-sm text-red-500 mt-1">{validationErrors.email}</p>
                  )}
                </div>
                {!showForgotPassword && <div>
                  <label htmlFor="password" className="sr-only">
                    Mot de passe
                  </label>
                  <input
                    id="password"
                    name="password"
                    type="password"
                    autoComplete="current-password"
                    className={`appearance-none relative block w-full px-3 py-2 border !ring-0 ${
                      validationErrors.password ? 'border-red-500' : 'border-gray-300'
                    } placeholder-gray-500 text-gray-900 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#0073e6] focus:border-[#0073e6] sm:text-sm`}
                    placeholder="Mot de passe"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                  {validationErrors.password && (
                    <p className="text-sm text-red-500 mt-1">{validationErrors.password}</p>
                  )}
                </div>}
              </div>

              {error && (
                <div className="text-red-500 text-sm text-center">{error}</div>
              )}

              <div>
                <button
                  type="submit"
                  disabled={loading}
                  className={`w-full bg-[#0073e6] text-white py-3 rounded font-medium hover:bg-[#0066cc] transition-all duration-300 mt-4 flex items-center justify-center ${loading ? 'opacity-75 cursor-not-allowed' : ''}`}
                >
                  {loading ? (
                    <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                  ) : (
                    <>
                      <span>{showForgotPassword ? 'Réinitialiser le mot de passe' :
                      isLogin ? 'Se connecter' : 'Créer un compte'}</span>
                    </>
                  )}
                </button>
                {isLogin && !showForgotPassword && (
                  <button
                    type="button"
                    onClick={async () => {
                      try {
                        setLoading(true);
                        const { error } = await supabase.auth.signInWithOAuth({
                          provider: 'google',
                          options: {
                            queryParams: {
                              access_type: 'offline',
                              prompt: 'consent'
                            }
                          }
                        });
                        if (error) throw error;
                      } catch (err) {
                        setError(err instanceof Error ? err.message : 'Une erreur est survenue');
                      } finally {
                        setLoading(false);
                      }
                    }}
                    disabled={loading}
                    className="w-full flex items-center justify-center gap-2 bg-white text-gray-700 py-3 rounded font-medium hover:bg-gray-50 transition-all duration-300 mt-4 border border-gray-300"
                  >
                    <img 
                      src="https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png" 
                      alt="Google"
                      className="w-5 h-5"
                    />
                    <span>Se connecter avec Google</span>
                  </button>
                )}
                {isLogin && !showForgotPassword && (
                  <button
                    type="button"
                    onClick={() => setShowForgotPassword(true)}
                    className="w-full text-sm text-[#0073e6] hover:text-[#0066cc] font-medium transition-colors mt-4"
                  >
                    Mot de passe oublié ?
                  </button>
                )}
              </div>
            </form>
          </div>
        </div>
        <div className="hidden md:block w-2/3 relative overflow-hidden">
          <video autoPlay loop muted playsInline className="absolute inset-0 min-h-full min-w-full w-auto h-auto object-cover">
            <source src="https://static.vecteezy.com/system/resources/previews/001/803/236/mp4/no-signal-bad-tv-free-video.mp4" type="video/mp4" />
          </video>
        </div>
      </main>
    </div>
  );
};