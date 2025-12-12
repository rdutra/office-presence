# Firebase Deployment Guide

This project uses a **single source of truth** approach for the dashboard HTML. The `dashboard_modern.erb` template is the canonical template, and the Firebase static HTML is generated from it during deployment.

## How It Works

1. **Source Template**: [`views/dashboard_modern.erb`](views/dashboard_modern.erb) is the main template
2. **Generation Script**: [`bin/generate_firebase_html.rb`](bin/generate_firebase_html.rb) renders the ERB template to static HTML
3. **Firebase HTML**: Generated file at `firebase_public/index.html` (git-ignored, generated on-demand)
4. **Deploy Script**: [`bin/firebase_deploy.sh`](bin/firebase_deploy.sh) handles the full deployment workflow

## Deployment Workflow

When you run the Firebase deploy script, it:

1. **Generates** `firebase_public/index.html` from `dashboard_modern.erb`
2. **Injects** Firebase configuration from `.env.firebase`
3. **Deploys** to Firebase
4. **Restores** placeholder values in the HTML (for security)

## Making Changes

### To update the dashboard:

1. Edit [`views/dashboard_modern.erb`](views/dashboard_modern.erb) - this is your single source of truth
2. Test locally if needed
3. Run deployment: `./bin/firebase_deploy.sh`

The modern template automatically adapts for Firebase deployment:
- Hides the registration button
- Removes registration modal
- Adds mobile scrolling CSS (the key difference from the local version)
- Replaces local JavaScript with Firebase real-time data loading

### Firebase-Specific Adaptations

The generator script ([`bin/generate_firebase_html.rb`](bin/generate_firebase_html.rb)) automatically:

- **Adds scrolling support** for mobile devices:
  ```css
  body { overflow-y: auto; }
  .container { height: auto; min-height: calc(100vh - 2rem); }
  ```

- **Hides registration features**:
  - Removes registration modal
  - Hides register button
  - Removes registration JavaScript

- **Injects Firebase JavaScript** ([`bin/firebase_dashboard_script.js`](bin/firebase_dashboard_script.js)):
  - Loads data from Firebase Realtime Database
  - Dynamically updates all dashboard sections
  - Handles loading states and errors

## Commands

```bash
# Deploy everything to Firebase
./bin/firebase_deploy.sh

# Deploy only hosting (HTML/CSS/JS)
./bin/firebase_deploy.sh --only hosting

# Deploy only database rules
./bin/firebase_deploy.sh --only database

# Generate Firebase HTML without deploying (for testing)
bundle exec ruby bin/generate_firebase_html.rb
```

## File Structure

```
office-presence/
├── views/
│   └── dashboard_modern.erb          # 📝 EDIT THIS - Single source of truth
├── bin/
│   ├── generate_firebase_html.rb     # Generates static HTML from ERB
│   ├── firebase_dashboard_script.js  # Firebase data loading script
│   └── firebase_deploy.sh            # Main deployment script
├── firebase_public/
│   ├── index.html                    # Generated (git-ignored)
│   └── css/                          # Static assets
└── .env.firebase                     # Firebase credentials
```

## Benefits of This Approach

1. **Single Source of Truth**: Only edit `dashboard_modern.erb`
2. **No Duplication**: Firebase HTML is generated, not manually maintained
3. **Consistent Features**: Changes to the modern template automatically flow to Firebase
4. **Mobile Scrolling Preserved**: Firebase version retains scrolling capability
5. **Automatic Adaptation**: Registration features automatically removed for Firebase

## Requirements

- Ruby 3.3.1 (specified in `.ruby-version` and `Gemfile`)
- Bundler with all gems installed (`bundle install`)

## Troubleshooting

### "Template not found" error
Make sure you're running the script from the project root directory.

### "Ruby version not installed" error
If you're using RVM, you can run the generator with a specific Ruby version:
```bash
~/.rvm/bin/rvm 3.3.1 do bundle exec ruby bin/generate_firebase_html.rb
```

Or install Ruby 3.3.1:
```bash
rvm install 3.3.1
```

### "Ruby version mismatch" error
Make sure you're using Ruby 3.3.1 as specified in the `.ruby-version` file. Use `bundle exec` to run the generator:
```bash
bundle exec ruby bin/generate_firebase_html.rb
```

### Firebase configuration errors
Check that `.env.firebase` has all required variables:
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_DATABASE_URL`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`

## Migration Notes

**Old approach** (deprecated):
- Maintained two separate files: `dashboard_modern.erb` and `firebase_public/index.html`
- Had to manually replicate changes between them

**New approach** (current):
- Single template: `dashboard_modern.erb`
- Firebase HTML generated automatically during deployment
- Changes only need to be made once
