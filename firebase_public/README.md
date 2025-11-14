# Firebase Public Directory

This directory contains the static files for your Firebase-hosted dashboard.

## Security Note

**⚠️ IMPORTANT:** The `index.html` file contains placeholder values for Firebase configuration. Your actual credentials are stored in `.env.firebase` (gitignored) and injected at deploy time.

## Setup

Your Firebase credentials should already be in `.env.firebase` in the project root. If not, create it with:

```bash
FIREBASE_API_KEY=your-api-key
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your-sender-id
FIREBASE_APP_ID=your-app-id
```

## Deployment

Use the deploy script which automatically injects your credentials:

```bash
# Deploy everything (hosting + database rules)
./bin/firebase_deploy.sh

# Deploy only hosting (dashboard HTML)
./bin/firebase_deploy.sh --only hosting

# Deploy only database rules
./bin/firebase_deploy.sh --only database

# Deploy with other Firebase CLI options
./bin/firebase_deploy.sh --only hosting --message "Updated dashboard design"
```

The deploy script will:
1. Load credentials from `.env.firebase`
2. Inject them into `index.html` (temporarily)
3. Deploy to Firebase with your specified options
4. Restore the placeholder version

### Common Deployment Scenarios

```bash
# Quick HTML/CSS changes (no rule changes)
./bin/firebase_deploy.sh --only hosting

# Changed security rules only
./bin/firebase_deploy.sh --only database

# Full deployment (after major changes)
./bin/firebase_deploy.sh

# Deploy and view in browser
./bin/firebase_deploy.sh --only hosting && firebase open hosting:site
```

## Editing the Dashboard

**You only need to edit `index.html`!** 

- Make your HTML/CSS/JS changes in `firebase_public/index.html`
- Keep the placeholder values as-is: `YOUR_API_KEY_HERE`, etc.
- The deploy script will inject real values automatically

## Files

- `index.html` - Template with placeholders (committed to git, edit this!)
- `index.html.bak` - Temporary backup during deployment (gitignored)
- `index.html.tmp` - Temporary file with injected values (gitignored)

## Why This Approach?

Firebase API keys are **technically safe to expose** in client-side code because:
- They identify your project, not authenticate it
- Security comes from Firebase Security Rules
- Google's official guidance says it's okay

However, it's still good practice to:
- Keep them out of public repos
- Prevent automated scrapers from finding them
- Use Firebase Security Rules to control access

## Your Firebase Security

Your database rules in `database.rules.json`:
```json
{
  "rules": {
    "dashboard": {
      ".read": true,   // Anyone can read (public dashboard)
      ".write": true   // Anyone can write (for your sync script)
    }
  }
}
```

Since your sync script is the only writer and the data is public anyway (office presence), this is acceptable. If you need more security, consider:
- Using Firebase Authentication
- Restricting writes to authenticated users
- Using Firebase Admin SDK with service account
