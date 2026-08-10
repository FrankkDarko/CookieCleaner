# CookieCleaner — Proposition de projet

> Outil gratuit et open-source pour limiter l'impact du vol de cookies (session hijacking) en nettoyant automatiquement les cookies et données de session de sites sensibles.

## 1. Contexte : comprendre la menace

Tu as bien compris le principe. Les *infostealers* (RedLine, Lumma, Raccoon, etc.) fonctionnent ainsi :

1. La victime exécute un malware (faux crack, faux jeu, pièce jointe...).
2. Le malware copie les fichiers de cookies des navigateurs (Chrome, Firefox, Edge...) et les déchiffre avec les clés locales de la machine.
3. L'attaquant **injecte ces cookies dans son propre navigateur** et se retrouve connecté à ta place — sans mot de passe, et souvent **en contournant la 2FA** (la session est déjà authentifiée).

Cas particulier de Discord : le compte n'est pas volé via un cookie mais via le **token** stocké dans le `localStorage` / LevelDB de l'application. Un outil qui ne nettoie que les cookies ne protège donc pas Discord — il faut aussi nettoyer le stockage local.

### Ce que le nettoyage périodique apporte (et n'apporte pas)

**Ce que ça apporte :** un cookie volé n'est utile que tant que la session est valide côté serveur. Si les cookies sont purgés régulièrement (et que la déconnexion invalide la session serveur), la **fenêtre d'exploitation** d'un vol passe de plusieurs semaines à quelques heures.

**Ce que ça n'apporte pas :** ça ne prévient pas le vol lui-même. Si le malware est actif sur la machine, il peut re-voler les cookies dès la prochaine connexion. Il faut être honnête dans le README : c'est de la **réduction de surface**, pas une protection absolue. C'est un complément à un antivirus et à de bonnes pratiques, pas un remplacement.

**Le compromis UX :** purger les cookies = être déconnecté. L'utilisateur devra se reconnecter aux sites nettoyés. D'où l'importance de laisser le choix des sites et de la fréquence.

## 2. Choix d'architecture : extension navigateur (recommandé)

Deux approches possibles, avec une recommandation claire.

### Option A — Extension navigateur (Manifest V3) ✅ recommandée

C'est l'approche que je recommande fortement, pour des raisons techniques :

- **Un programme externe ne peut pas nettoyer proprement les cookies pendant que le navigateur tourne** : la base SQLite des cookies est verrouillée par Chrome/Edge.
- Depuis Chrome 127, l'**App-Bound Encryption** rend l'accès externe aux cookies encore plus difficile — c'est fait exprès contre les stealers, mais ça bloque aussi un outil de nettoyage externe.
- L'API `chrome.cookies` permet de supprimer les cookies **par domaine, proprement, à chaud**.
- L'API `chrome.browsingData` permet aussi de purger le `localStorage` par origine → **couvre le cas Discord (version web)**.
- L'API `chrome.alarms` gère nativement le « toutes les X minutes/heures », même quand le service worker de l'extension est endormi.
- Compatible Chrome, Edge, Brave, Opera (et portage Firefox facile avec `browser.*`).
- Distribution simple et gratuite (Chrome Web Store ~5$ de frais uniques, ou installation en mode développeur).

### Option B — Application de bureau (tray)

Un petit programme dans la barre des tâches (C# ou Tauri/Rust) qui nettoie les fichiers de cookies. Problèmes : ne fonctionne fiablement que **navigateur fermé**, doit suivre les changements de format/chiffrement de chaque navigateur, demande des droits plus élevés (et un outil qui lit les cookies ressemble... à un stealer, donc faux positifs antivirus garantis). À garder éventuellement pour une v2 (nettoyage au démarrage de la machine, avant ouverture du navigateur).

## 3. Fonctionnalités

### MVP (v1.0)

| Fonctionnalité | Détail |
|---|---|
| Liste de sites à nettoyer | L'utilisateur ajoute des domaines (ex. `discord.com`, `gmail.com`) ; sous-domaines inclus |
| Mode « tout nettoyer » | Purge tous les cookies sauf une **liste blanche** (sites de confiance à ne jamais déconnecter) |
| Intervalle configurable | Toutes les X heures / une fois par jour / au démarrage du navigateur |
| Nettoyage à la demande | Bouton « Nettoyer maintenant » dans le popup |
| Purge du stockage local | Cookies + `localStorage` + IndexedDB par site (nécessaire pour les tokens type Discord) |
| Presets de sites sensibles | Un clic pour ajouter Discord, Google, Steam, PayPal, réseaux sociaux... |
| Journal | Historique des nettoyages (quoi, quand, combien de cookies) |

### v1.1 — Vérification de fuites d'adresses e-mail

Ton idée de recherche de leaks est bonne, avec une contrainte : l'API de **Have I Been Pwned** pour chercher un e-mail est payante (~4 $/mois pour le développeur). Pour rester 100 % gratuit, trois pistes :

1. **Lien direct** : un champ e-mail dans l'extension qui ouvre `haveibeenpwned.com` pré-rempli — gratuit, zéro maintenance, mais pas automatique.
2. **Clé API fournie par l'utilisateur** : ceux qui veulent la surveillance automatique mettent leur propre clé HIBP dans les options. L'outil reste gratuit, la fonctionnalité avancée est opt-in.
3. **Vérification de mots de passe** (bonus) : l'API *Pwned Passwords* de HIBP est **gratuite et anonyme** (k-anonymity : on n'envoie que les 5 premiers caractères du hash SHA-1, jamais le mot de passe). On peut proposer « vérifie si ce mot de passe apparaît dans des fuites » sans aucun coût.

Je recommande de faire les trois : 1 et 3 par défaut, 2 pour les utilisateurs avancés.

### Idées v2 (backlog)

- **Nettoyage à la fermeture du navigateur** (event `onSuspend` / alarme au prochain démarrage).
- **Score d'hygiène** : nombre de cookies tiers, sites avec sessions anciennes, etc.
- **Notification discrète** après chaque nettoyage (désactivable).
- **Export/import de la configuration** (JSON).
- **Portage Firefox** (API quasi identique).
- **Page "Que faire si je suis infecté ?"** : guide de remédiation (changer les mots de passe, révoquer les sessions depuis les paramètres des comptes, scanner la machine) — pédagogique et très utile.

## 4. Architecture technique (extension MV3)

```
cookiecleaner/
├── manifest.json          # MV3, permissions: cookies, browsingData, alarms, storage
├── background.js          # Service worker : alarmes, logique de nettoyage
├── popup/                 # Popup : état, bouton "Nettoyer maintenant"
│   ├── popup.html
│   └── popup.js
├── options/               # Page d'options : sites, intervalle, liste blanche, leaks
│   ├── options.html
│   └── options.js
└── _locales/              # fr + en
```

- **Permissions** : `cookies`, `browsingData`, `alarms`, `storage` + `host_permissions` limitées si possible. Aucune permission réseau vers un serveur à nous : **tout reste local**, argument de confiance majeur pour un outil de ce genre.
- **Stack** : JavaScript vanilla, zéro dépendance, zéro build. Facile à auditer — crucial pour la confiance (un outil anti-vol de cookies doit être irréprochable et lisible).
- **Licence** : MIT (déjà dans le repo).

## 5. Feuille de route

1. **Semaine 1 — MVP** : manifest, nettoyage par domaine via `chrome.cookies`, alarme périodique, popup minimal.
2. **Semaine 2 — Options** : page de configuration complète, presets, liste blanche, mode « tout sauf... », journal.
3. **Semaine 3 — Leaks** : lien HIBP, vérif de mots de passe (k-anonymity), champ clé API optionnel.
4. **Semaine 4 — Finitions** : i18n fr/en, icônes, README honnête sur les limites, publication Chrome Web Store.

## 6. Points de vigilance

- **Transparence absolue** : open-source, pas de télémétrie, pas de serveur. C'est LE critère de confiance pour ce type d'outil.
- **Ne jamais promettre l'invulnérabilité** : le README doit expliquer que l'outil réduit la fenêtre d'attaque mais ne remplace ni antivirus, ni 2FA, ni prudence.
- **Déconnexion serveur** : supprimer le cookie localement ne tue pas toujours la session côté serveur. Pour les sites critiques, recommander aussi la révocation des sessions dans les paramètres du compte (on peut lier directement les pages « appareils connectés » de Google/Discord/Steam dans les presets).
