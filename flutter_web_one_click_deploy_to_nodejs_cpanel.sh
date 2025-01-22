#!/bin/bash

# Configuration
REMOTE_PROJECT_DIR=$(basename "$PWD")
CPANEL_HOST="$LOVERSEE_CPANEL_HOST"
CPANEL_USERNAME="$LOVERSEE_CPANEL_USERNAME"
CPANEL_PASSWORD="$LOVERSEE_CPANEL_PASSWORD"
REMOTE_PATH="/home/$CPANEL_USERNAME/$REMOTE_PROJECT_DIR"
REMOTE_WEB_PATH="$REMOTE_PATH/web"
LOCAL_WEB_PATH="./build/web"
LOCAL_ENV_FILE="./.env"

# Flags
UPLOAD_WEB=true
UPLOAD_ENV=false
CREATE_MAIN_JS=false
CREATE_PACKAGE_JSON=false

# Set locale to UTF-8
export LANGUAGE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="UTF-8"
export LANG="en_US.UTF-8"

# Stop execution on any error
set -e

# Ensure required commands are available
for cmd in flutter scp sshpass rsync; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd is not installed or not in PATH. Aborting."
    exit 1
  fi
done

# Build the project
echo "🚀 Building $REMOTE_PROJECT_DIR..."
if ! flutter build web; then
  echo "❌ Build failed! Aborting deployment."
  exit 1
fi
echo "✅ Build complete!"

# Check if required files exist
for path in "$LOCAL_WEB_PATH" "$LOCAL_ENV_FILE"; do
  if [ ! -e "$path" ]; then
    echo "❌ Error: '$path' does not exist. Aborting deployment."
    exit 1
  fi
done

# Kill the running web server process
echo "🔪 Killing any running remote web server process..."
sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "pkill -f node"
echo "✅ Web server remote process killed!"

# Check and create remote directories if needed
for dir in "$REMOTE_PATH" "$REMOTE_WEB_PATH"; do
  echo "🔍 Checking directory $dir..."
  sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "
    if [ -e '$dir' ] && [ ! -d '$dir' ]; then
      echo '❌ $dir exists but is not a directory. Aborting.'
      exit 1
    fi
    if [ ! -d '$dir' ]; then
      echo '❌ $dir does not exist, creating now...'
      mkdir -p '$dir' && echo '✅ Directory $dir created.' || { echo '❌ Failed to create $dir.'; exit 1; }
    else
      echo '✅ $dir already exists.'
    fi
  "
done

# Sync web directory
if [ "$UPLOAD_WEB" = true ]; then
  echo "🔄 Syncing 'web' directory to remote server..."
  sshpass -p "$CPANEL_PASSWORD" rsync -avz --progress --delete \
    "$LOCAL_WEB_PATH/" "$CPANEL_USERNAME@$CPANEL_HOST:$REMOTE_WEB_PATH"
  echo "✅ Sync complete!"
fi

# Upload .env
if [ "$UPLOAD_ENV" = true ]; then
  echo "📁 Uploading .env..."
  sshpass -p "$CPANEL_PASSWORD" scp "$LOCAL_ENV_FILE" "$CPANEL_USERNAME@$CPANEL_HOST:$REMOTE_PATH"
  echo "✅ .env uploaded successfully!"
fi

# Create package.json file on the remote server
if [ "$CREATE_PACKAGE_JSON" = true ]; then
  echo "📝 Creating package.json file on the remote server..."
  sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "cat > $REMOTE_PATH/package.json << 'EOF'
{
  \"name\": \"$REMOTE_PROJECT_DIR\",
  \"version\": \"1.0.0\",
  \"main\": \"main.js\",
  \"scripts\": {
    \"start\": \"node main.js\"
  },
  \"dependencies\": {
    \"express\": \"^4.17.1\"
  }
}
EOF"
  echo "✅ package.json file created!"

  # Install npm packages on the remote server
  echo "⚙️ Installing npm packages on the remote server..."
  sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "cd $REMOTE_PATH && npm install"
  echo "✅ npm packages installed!"
fi

# Create main.js file on the remote server
if [ "$CREATE_MAIN_JS" = true ]; then
  echo "📝 Creating main.js file on the remote server..."
  sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "cat > $REMOTE_PATH/main.js << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 8000;
const WEB_DIR = path.join(__dirname, 'web');

app.use(express.static(WEB_DIR));

app.get('*', (req, res) => {
  res.sendFile(path.join(WEB_DIR, 'index.html'));
});

app.listen(PORT, () => {
  console.log(\`Server is running on http://localhost:\${PORT}\`);
});
EOF"
  echo "✅ main.js file created!"
fi

# Restart the server
echo "🔄 Restarting the server..."
sshpass -p "$CPANEL_PASSWORD" ssh "$CPANEL_USERNAME@$CPANEL_HOST" "cd $REMOTE_PATH && nohup node main.js &"
echo "🎉 Deployment complete! Your project is now live at: $REMOTE_PATH"
