import React from 'react';
import { HelpCircle } from 'lucide-react';

interface HelpSectionProps {
  title: string;
  children: React.ReactNode;
}

const HelpSection = ({ title, children }: HelpSectionProps) => (
  <div className="bg-white dark:bg-[#1B2028] rounded-lg p-6 shadow-sm mb-6">
    <div className="flex items-center gap-4 mb-4">
      <div className="text-purple-500">
        <HelpCircle size={24} />
      </div>
      <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
        {title}
      </h2>
    </div>
    <div className="text-gray-600 dark:text-gray-300">
      {children}
    </div>
  </div>
);

const HelpPage = () => {
  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
        Aide
      </h1>

      <HelpSection title="Comment fonctionne Audience Masters ?">
        Audience Masters est une plateforme dédiée aux prévisions d’audience des programmes télévisés. Comparez vos estimations, explorez          les classements et tentez de devenir le véritable "Maître des Audiences". 
      </HelpSection>

      <HelpSection title="Comment faire un pronostic ?">
        Pour pronostiquer, sélectionnez une émission dans la liste disponible sur la page d'accueil. Entrez votre estimation d'audience            (en millions de téléspectateurs) et validez. 
      </HelpSection>

      <HelpSection title="Comment consulter les classements ?">
        Vous pouvez consulter les classements en cliquant sur l'onglet "Classement Joueurs" dans la barre latérale. Vous y trouverez le            classement de tous les joueurs, basé à la fois sur les points gagnés et sur leur % de précision.
      </HelpSection>

      <HelpSection title="Contactez-nous">
        Si vous avez des questions ou des problèmes, n'hésitez pas à nous contacter par email à{' '}
        <a 
          href="mailto:support@audiencemasters.fr" 
          className="text-purple-500 hover:text-purple-600"
        >
          support@audiencemasters.fr
        </a>
      </HelpSection>
    </div>
  );
};

export default HelpPage;