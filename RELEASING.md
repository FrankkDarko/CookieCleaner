# Guide de release — CookieCleaner

Checklist complète pour publier une nouvelle version, de GitHub jusqu'aux stores.

## 1. Préparer la version

1. **Incrémenter la version** dans [`extension/manifest.json`](extension/manifest.json) (`"version": "1.1.0"`) — format `x.y.z`, obligatoirement croissant pour les stores.
2. **Tester** dans Chrome (extension non empaquetée) et Firefox (`about:debugging` → « Charger un module temporaire ») : nettoyage manuel, nettoyage planifié, les deux modes, changement de langue.
3. **Regénérer les visuels** si besoin : `powershell -File scripts/gen-assets.ps1`
4. **Construire les ZIP** : `powershell -File scripts/build.ps1` → produit `dist/CookieCleaner-x.y.z-chromium.zip` et `-firefox.zip`.

## 2. Obtenir le .xpi signé pour Firefox (gratuit)

Firefox n'installe que des extensions signées par Mozilla, même hors store.

1. Créer un compte développeur sur https://addons.mozilla.org (gratuit).
2. https://addons.mozilla.org/developers/ → « Soumettre un nouveau module ».
3. Choisir le mode de distribution :
   - **« Sur votre propre site »** (auto-distribution / unlisted) : Mozilla signe le fichier après validation automatique (quelques minutes) et vous récupérez un **`.xpi` signé** à distribuer vous-même → c'est ce fichier qu'on attache à la release GitHub.
   - **« Sur ce site »** (listed) : publication classique sur addons.mozilla.org avec fiche publique (voir §4).
4. Uploader `dist/CookieCleaner-x.y.z-firefox.zip`, télécharger le `.xpi` signé.

## 3. Créer la release GitHub

```bash
git tag v1.0.0
git push origin main --tags
```

Puis sur GitHub : **Releases → Draft a new release** → choisir le tag `v1.0.0` :

- **Titre** : `CookieCleaner v1.0.0`
- **Notes** : nouveautés, corrections, instructions d'installation courtes (copier depuis le README).
- **Fichiers à attacher** :
  - `CookieCleaner-1.0.0-chromium.zip` (pour Chrome/Edge/Brave/Opera en mode développeur)
  - `CookieCleaner-1.0.0-firefox.xpi` (le fichier **signé** récupéré au §2 — pas le zip brut)

Ou en une commande avec le CLI GitHub :

```bash
gh release create v1.0.0 dist/CookieCleaner-1.0.0-chromium.zip dist/CookieCleaner-1.0.0-firefox.xpi --title "CookieCleaner v1.0.0" --notes "Première version publique"
```

> Les liens `Releases` du README et du site pointent automatiquement vers la dernière release.

## 4. Publier sur les stores

### Chrome Web Store (Chrome, Brave, et Opera/Edge peuvent aussi y puiser)

1. Compte développeur : https://chrome.google.com/webstore/devconsole — **5 $ une seule fois**.
2. « Nouvel élément » → uploader `CookieCleaner-x.y.z-chromium.zip`.
3. Remplir la fiche (possible par langue : fr, en, es, de, it — textes dans `extension/_locales/*/messages.json`) :
   - Icône store : `assets/store/store-icon-128.png`
   - Tuile promo : `assets/store/promo-small-440x280.png` (et `-en` pour la fiche anglaise)
   - Marquee : `assets/store/promo-marquee-1400x560.png`
   - **Au moins 1 capture d'écran 1280×800** de l'extension en fonctionnement (options remplies + popup).
4. Onglet **Confidentialité** — crucial pour être accepté :
   - Justifier chaque permission : `cookies`/`browsingData` (fonction principale : suppression), `alarms` (planification), `storage` (préférences locales), `host_permissions` (l'utilisateur choisit librement les sites à nettoyer).
   - Déclarer : aucune collecte de données, aucune vente, aucun code distant.
5. Soumettre → validation en général sous quelques jours ouvrés.

### addons.mozilla.org (Firefox)

1. Même compte qu'au §2, mais en mode **« Sur ce site »** (listed).
2. Uploader le zip, remplir la fiche (mêmes visuels, captures d'écran libres en dimensions).
3. Validation automatique + revue humaine éventuelle. Gratuit.

### Microsoft Edge Add-ons (optionnel)

1. https://partner.microsoft.com/dashboard/microsoftedge — gratuit.
2. Même ZIP chromium, même fiche. Validation ~quelques jours.

### Opera Add-ons (optionnel)

1. https://addons.opera.com/developer/ — gratuit, accepte les extensions Chrome telles quelles.
2. À noter : Opera peut aussi installer directement depuis le Chrome Web Store.

## 5. Mises à jour suivantes

1. Bump de version dans le manifest → build → tag → release GitHub (avec nouveau `.xpi` signé).
2. Re-uploader le ZIP sur chaque store : les utilisateurs des stores sont **mis à jour automatiquement**.
3. Les utilisateurs en installation manuelle (mode développeur) doivent re-télécharger — d'où l'intérêt des stores.
