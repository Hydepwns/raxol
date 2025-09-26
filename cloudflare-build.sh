#!/bin/bash

# Cloudflare Pages build script - Static assets only
set -e

echo "Building Raxol Playground static assets for Cloudflare Pages..."

# Navigate to web directory
cd web

# Create output directory structure
mkdir -p priv/static/css
mkdir -p priv/static/js
mkdir -p priv/static/images
mkdir -p priv/static/assets

# Check if we have Node.js for asset building
if command -v npm > /dev/null; then
    echo "Node.js found, building assets with npm..."

    # Check if assets directory exists
    if [ -d "assets" ]; then
        cd assets

        # Install dependencies if package.json exists
        if [ -f "package.json" ]; then
            echo "Installing npm dependencies..."
            npm install

            # Try to build assets
            if npm run build 2>/dev/null; then
                echo "Assets built successfully"
            else
                echo "No build script found, copying assets directly..."
            fi
        fi

        # Copy assets to static directory
        [ -f "css/app.css" ] && cp css/app.css ../priv/static/css/
        [ -f "js/app.js" ] && cp js/app.js ../priv/static/js/

        # Copy any built assets
        [ -d "dist" ] && cp -r dist/* ../priv/static/assets/ 2>/dev/null || true

        cd ..
    fi
else
    echo "Node.js not found, copying raw assets..."

    # Copy raw assets directly
    if [ -d "assets" ]; then
        [ -f "assets/css/app.css" ] && cp assets/css/app.css priv/static/css/
        [ -f "assets/js/app.js" ] && cp assets/js/app.js priv/static/js/
    fi
fi

# Create a simple index.html if it doesn't exist
if [ ! -f "priv/static/index.html" ]; then
    echo "Creating default index.html..."
    cat > priv/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raxol Playground</title>
    <link rel="stylesheet" href="/css/app.css">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        .container {
            text-align: center;
            max-width: 600px;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.25rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }
        .links {
            display: flex;
            gap: 1rem;
            justify-content: center;
            flex-wrap: wrap;
        }
        a {
            padding: 0.75rem 1.5rem;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            transition: background 0.3s;
        }
        a:hover {
            background: rgba(255, 255, 255, 0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Raxol Playground</h1>
        <p>High-performance terminal UI framework for Elixir</p>
        <div class="links">
            <a href="https://github.com/Hydepwns/raxol">GitHub</a>
            <a href="https://hexdocs.pm/raxol">Documentation</a>
            <a href="https://hex.pm/packages/raxol">Hex Package</a>
        </div>
    </div>
    <script src="/js/app.js"></script>
</body>
</html>
EOF
fi

# Copy Cloudflare Pages configuration files
if [ -f "_headers" ]; then
    cp _headers priv/static/
    echo "Copied _headers file"
fi

if [ -f "_redirects" ]; then
    cp _redirects priv/static/
    echo "Copied _redirects file"
fi

echo "Static build completed successfully!"
echo "Output directory: web/priv/static"
ls -la priv/static/