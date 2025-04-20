import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Moon, Sun, Tv, Award, MessageSquare, Settings, TrendingUp, LogOut, ShieldCheck, Bell, Menu, X, Check } from 'lucide-react';
import { AuthForm } from './components/auth/AuthForm';
import { supabase } from './lib/supabase';
import ProgramList from './components/programs/ProgramList';
import PredictionsPage from './components/predictions/PredictionsPage';
import RankingPage from './components/ranking/RankingPage';
import SettingsPage from './components/settings/SettingsPage';
import AdminAccess from './components/admin/AdminAccess';
import AdminPage from './components/admin/AdminPage';
import HelpPage from './components/help/HelpPage';
import UserScore from './components/UserScore';

// Components
const Navigation = ({ handleLogout, darkMode, setDarkMode }: { 
  handleLogout: () => Promise<void>;
  darkMode: boolean;
  setDarkMode: (value: boolean) => void;
}) => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  return (
    <>
      {/* Mobile Menu Button */}
      <button
        onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
        className="lg:hidden fixed top-4 left-4 z-50 p-2 rounded-lg bg-gray-100 dark:bg-gray-800"
      >
        {isMobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
      </button>

      {/* Overlay for mobile menu */}
      {isMobileMenuOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-40"
          onClick={() => setIsMobileMenuOpen(false)}
        />
      )}

      {/* Navigation Sidebar */}
      <nav className={`fixed top-0 left-0 h-screen bg-white dark:bg-[#1B2028] flex flex-col py-6 px-4 border-r border-gray-200 dark:border-gray-800 z-40 transition-transform duration-300 lg:translate-x-0 ${
        isMobileMenuOpen ? 'translate-x-0 w-64' : '-translate-x-full w-64'
      } lg:w-64`}>
        <Link to="/" className="mb-8 flex justify-center" onClick={() => setIsMobileMenuOpen(false)}>
          <img src="https://i.postimg.cc/xjHxd9KK/logo-1.png" alt="Logo" className="w-40" />
        </Link>
        <div className="flex flex-col flex-1">
          <div className="flex flex-col space-y-1">
            <NavLink to="/" label="Accueil" icon={<Tv size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
            <NavLink to="/shows" label="Mes Pronostics" icon={<TrendingUp size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
            <NavLink to="/ranking" label="Classements Joueurs" icon={<Award size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
            <NavLink to="/settings" label="Paramètres" icon={<Settings size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
            <NavLink to="/admin" label="Administration" icon={<ShieldCheck size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
          </div>        
          <div className="flex flex-col space-y-1 mt-auto">
            <hr className="w-[90%] mx-auto my-4 border-gray-200 dark:border-gray-700" />
            <NavLink to="/help" label="Aide" icon={<MessageSquare size={20} />} onClick={() => setIsMobileMenuOpen(false)} />
            <button
              onClick={handleLogout}
              className="flex items-center px-4 py-2.5 text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-[#252A34] rounded-lg transition-colors"
            >
              <div className="w-5 h-5">
                <LogOut size={20} />
              </div>
              <span className="text-sm font-medium ml-4">Se déconnecter</span>
            </button>
          </div>
        </div>
      </nav>
    </>
  );
};

const NavLink = ({ to, icon, label, onClick }: { to: string; icon: React.ReactNode; label: string; onClick?: () => void }) => (
  <Link
    to={to}
    onClick={onClick}
    className="flex items-center px-4 py-2.5 text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-[#252A34] rounded-lg transition-colors"
  >
    <div className="w-5 h-5">{icon}</div>
    <span className="text-sm font-medium ml-4">{label}</span>
  </Link>
);

const TopBar = ({ darkMode, setDarkMode, user }: {
  darkMode: boolean;
  setDarkMode: (value: boolean) => void;
  user: any;
}) => {
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const notificationRef = React.useRef<HTMLDivElement>(null);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const fetchUnreadCount = async () => {
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser) return;

      const { count } = await supabase
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', currentUser.id)
        .eq('read', false);

      setUnreadCount(count || 0);
    };

    fetchUnreadCount();

    // Subscribe to notifications changes
    const subscription = supabase
      .channel('notifications_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'notifications'
      }, () => {
        fetchUnreadCount();
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    const fetchNotifications = async () => {
      if (!showNotifications) return;
      
      setLoading(true);
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser) return;

      const { data } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', currentUser.id)
        .order('created_at', { ascending: false })
        .limit(10);

      setNotifications(data || []);
      setLoading(false);
    };

    fetchNotifications();
  }, [showNotifications]);

  // Close notifications when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (notificationRef.current && !notificationRef.current.contains(event.target as Node)) {
        setShowNotifications(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const markAsRead = async (notificationId: string) => {
    const { error } = await supabase
      .from('notifications')
      .update({ read: true })
      .eq('id', notificationId);
    
    if (!error) {
      setUnreadCount(prev => Math.max(0, prev - 1));
    }
  };

  const markAllAsRead = async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { error } = await supabase
      .from('notifications')
      .update({ read: true })
      .eq('user_id', user.id)
      .eq('read', false);

    if (!error) {
      setUnreadCount(0);
    }
  };

  const handleNotificationClick = () => {
    setShowNotifications(!showNotifications);
    if (!showNotifications) {
      markAllAsRead();
    }
  };

  return (
    <div className="fixed top-4 right-4 lg:right-8 z-50 flex items-center gap-4">
      <div className="relative" ref={notificationRef}>
        <button
          onClick={handleNotificationClick}
          className="group relative w-8 h-8 flex items-center justify-center text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white transition-colors"
          aria-label="Notifications"
        >
          <Bell size={20} />
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-xs flex items-center justify-center rounded-full">
              {unreadCount}
            </span>
          )}
        </button>

        {showNotifications && (
          <div className="absolute right-0 mt-2 w-80 bg-white dark:bg-[#1B2028] rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
            <div className="p-4 border-b border-gray-200 dark:border-gray-700">
              <h3 className="font-semibold text-gray-900 dark:text-white">Notifications</h3>
            </div>
            <div className="max-h-96 overflow-y-auto">
              {loading ? (
                <div className="flex justify-center items-center py-8">
                  <div className="animate-spin rounded-full h-6 w-6 border-2 border-purple-500 border-t-transparent"></div>
                </div>
              ) : notifications.length === 0 ? (
                <div className="p-4 text-center text-gray-500 dark:text-gray-400">
                  🔔 Rien à signaler pour l'instant.
                </div>
              ) : (
                <div>
                  {notifications.map((notification) => (
                    <div 
                      key={notification.id}
                      className={`p-4 border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors ${
                        !notification.read ? 'bg-purple-50 dark:bg-purple-900/10' : ''
                      }`}
                      onClick={() => markAsRead(notification.id)}
                    >
                      <div className="flex items-start gap-3">
                        <div className="flex-grow">
                          <p className="font-medium text-gray-900 dark:text-white">
                            {notification.title}
                          </p>
                          <p className="text-sm text-gray-600 dark:text-gray-300 mt-1">
                            {notification.message}
                          </p>
                          <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">
                            {new Date(notification.created_at).toLocaleDateString('fr-FR', {
                              hour: '2-digit',
                              minute: '2-digit'
                            })}
                          </p>
                        </div>
                        {!notification.read && (
                          <div className="text-purple-500">
                            <Check size={16} />
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
      <button
        onClick={() => setDarkMode(!darkMode)}
        className="group relative w-8 h-8 flex items-center justify-center text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white transition-colors"
        aria-label={darkMode ? "Activer le mode clair" : "Activer le mode sombre"}
      >
        {darkMode ? <Sun size={20} /> : <Moon size={20} />}
        <span className="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 dark:bg-gray-700 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
          {darkMode ? "Mode clair" : "Mode sombre"}
        </span>
      </button>
      <div
        className="group flex items-center bg-gray-800/90 backdrop-blur-md rounded-full pl-3 pr-1 py-1 hover:bg-gray-700/90 transition-all cursor-pointer"
        aria-label="Paramètres du profil"
      >
        <UserScore />
        {user?.user_metadata?.avatar_url ? (
          <img 
            src={user.user_metadata.avatar_url} 
            alt="Photo de profil"
            className="w-10 h-10 object-cover rounded-full ml-2"
          />
        ) : (
          <div className="w-10 h-10 bg-purple-600 text-white flex items-center justify-center text-lg font-medium rounded-full ml-2">
            {user?.user_metadata?.username ? user.user_metadata.username.slice(0, 2).toUpperCase() : 'NA'}
          </div>
        )}
      </div>
    </div>
  );
};

// Pages
const Home = () => {
  const [username, setUsername] = useState<string>('');

  useEffect(() => {
    const getUsername = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return setUsername('Utilisateur');
        
        // First try to get username from metadata
        if (user.user_metadata?.username) {
          return setUsername(user.user_metadata.username);
        }

        // Then try to get profile from database
        const { data: profiles } = await supabase
          .from('leaderboard_with_profiles')
          .select('username')
          .eq('user_id', user.id)
          .maybeSingle();

        if (profiles?.username) {
          return setUsername(profiles.username);
        }

        // Fallback to email prefix if no username found
        setUsername(user.email ? user.email.split('@')[0] : 'Utilisateur');
      } catch (error) {
        console.error('Error fetching username:', error);
        setUsername('Utilisateur');
      }
    };

    getUsername();
  }, []);

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
        Bienvenue {username} 👋
      </h1>
      <ProgramList />
    </div>
  );
};

const PageTransition = ({ children }: { children: React.ReactNode }) => {
  const location = useLocation();
  return (
    <div
      key={location.pathname}
      className="animate-fadeIn"
    >
      {children}
    </div>
  );
};

function App() {
  const [darkMode, setDarkMode] = React.useState(false);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  React.useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [darkMode]);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setUser(session.user);
      }
      setLoading(false);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        setUser(session.user);
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const handleLogout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
    } catch (error) {
      console.error('Erreur lors de la déconnexion:', error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-[#131720]">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
      </div>
    );
  }

  if (!user) {
    return <AuthForm />;
  }

  return (
    <Router>
      <div className="min-h-screen bg-gray-100 dark:bg-[#131720] text-gray-900 dark:text-white">
        <TopBar darkMode={darkMode} setDarkMode={setDarkMode} user={user} />
        <Navigation handleLogout={handleLogout} darkMode={darkMode} setDarkMode={setDarkMode} />
        <main className="lg:ml-64 px-4 lg:px-8 py-20 lg:py-6">
          <PageTransition>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/shows" element={<PredictionsPage />} />
              <Route path="/results" element={<div>Résultats</div>} />
              <Route path="/ranking" element={<RankingPage />} />
              <Route path="/stats" element={<div>Statistiques</div>} />
              <Route path="/profile" element={<div>Mon Profil</div>} />
              <Route path="/community" element={<div>Communauté</div>} />
              <Route path="/settings" element={<SettingsPage />} />
              <Route path="/help" element={<HelpPage />} />
              <Route path="/admin" element={<AdminAccess />} />
              <Route path="/admin/dashboard" element={<AdminPage />} />
            </Routes>
          </PageTransition>
        </main>
      </div>
    </Router>
  );
}

export default App;