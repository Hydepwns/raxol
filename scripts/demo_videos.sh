#!/bin/bash

# Raxol Demo Video Scripts
# These scripts help create demo videos showcasing Raxol's features

set -e

DEMO_DIR="demos"
mkdir -p $DEMO_DIR

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Raxol Demo Video Recording Scripts${NC}"
echo "====================================="
echo ""

# Function to start recording with asciinema
start_recording() {
    local demo_name=$1
    local title=$2
    echo -e "${GREEN}Starting recording: $title${NC}"
    asciinema rec "$DEMO_DIR/${demo_name}.cast" --title "$title" --idle-time-limit 2
}

# Function to convert asciinema to gif
convert_to_gif() {
    local demo_name=$1
    if command -v agg &> /dev/null; then
        echo -e "${GREEN}Converting $demo_name to GIF...${NC}"
        agg "$DEMO_DIR/${demo_name}.cast" "$DEMO_DIR/${demo_name}.gif"
    else
        echo -e "${YELLOW}agg not found. Install with: cargo install --git https://github.com/asciinema/agg${NC}"
    fi
}

# Demo 1: Interactive Tutorial System
demo_tutorial() {
    echo -e "${BLUE}Demo 1: Interactive Tutorial System${NC}"
    echo "This demo shows the interactive tutorial system"
    echo ""
    echo "Script to run:"
    echo "  1. mix raxol.tutorial"
    echo "  2. Navigate through the 3 tutorials"
    echo "  3. Show code examples and exercises"
    echo "  4. Demonstrate real-time validation"
    echo ""
    read -p "Press enter to start recording..."
    start_recording "tutorial" "Raxol Interactive Tutorial System"
    convert_to_gif "tutorial"
}

# Demo 2: Component Playground
demo_playground() {
    echo -e "${BLUE}Demo 2: Component Playground${NC}"
    echo "This demo shows the component playground with live preview"
    echo ""
    echo "Script to run:"
    echo "  1. mix raxol.playground"
    echo "  2. Navigate through 20+ components"
    echo "  3. Show live preview updates"
    echo "  4. Demonstrate property editing"
    echo "  5. Show animation examples"
    echo ""
    read -p "Press enter to start recording..."
    start_recording "playground" "Raxol Component Playground"
    convert_to_gif "playground"
}

# Demo 3: VSCode Extension
demo_vscode() {
    echo -e "${BLUE}Demo 3: VSCode Extension${NC}"
    echo "This demo shows the VSCode extension features"
    echo ""
    echo "Script to run:"
    echo "  1. Open VSCode with Raxol project"
    echo "  2. Show IntelliSense for Raxol components"
    echo "  3. Demonstrate snippets (raxol-component, raxol-animation)"
    echo "  4. Show hover documentation"
    echo "  5. Use command palette commands"
    echo ""
    echo "Note: Use a screen recorder for VSCode demo"
    read -p "Press enter when ready to continue..."
}

# Demo 4: WASH-Style Session Continuity
demo_wash() {
    echo -e "${BLUE}Demo 4: WASH-Style Session Continuity${NC}"
    echo "This demo shows seamless terminal-web migration"
    echo ""
    echo "Script to run:"
    echo "  1. Start a terminal session: iex -S mix"
    echo "  2. Create a session: Raxol.SessionBridge.create_session()"
    echo "  3. Add some state: Raxol.SessionBridge.update_state()"
    echo "  4. Show state persistence across restarts"
    echo "  5. Demonstrate CRDT-based collaboration"
    echo ""
    read -p "Press enter to start recording..."
    start_recording "wash" "Raxol WASH-Style Session Continuity"
    convert_to_gif "wash"
}

# Demo 5: Performance Showcase
demo_performance() {
    echo -e "${BLUE}Demo 5: Performance Showcase${NC}"
    echo "This demo shows Raxol's world-class performance"
    echo ""
    echo "Script to run:"
    echo "  1. Run benchmarks: mix run bench/simple_parser_test.exs"
    echo "  2. Show memory usage: Raxol.Minimal startup"
    echo "  3. Demonstrate 3.3μs parser performance"
    echo "  4. Show animation at 60 FPS"
    echo ""
    read -p "Press enter to start recording..."
    start_recording "performance" "Raxol Performance Showcase"
    convert_to_gif "performance"
}

# Demo 6: Enterprise Features
demo_enterprise() {
    echo -e "${BLUE}Demo 6: Enterprise Features${NC}"
    echo "This demo shows enterprise-grade features"
    echo ""
    echo "Script to run:"
    echo "  1. Show audit logging: Raxol.Audit.Events examples"
    echo "  2. Demonstrate encryption: Secure storage examples"
    echo "  3. Show CQRS pattern: Command bus usage"
    echo "  4. Display compliance: SOC2/HIPAA/GDPR features"
    echo ""
    read -p "Press enter to start recording..."
    start_recording "enterprise" "Raxol Enterprise Features"
    convert_to_gif "enterprise"
}

# Main menu
main_menu() {
    echo "Select demo to record:"
    echo "1) Interactive Tutorial System"
    echo "2) Component Playground"
    echo "3) VSCode Extension"
    echo "4) WASH-Style Session Continuity"
    echo "5) Performance Showcase"
    echo "6) Enterprise Features"
    echo "7) Record All Demos"
    echo "8) Exit"
    echo ""
    read -p "Enter choice [1-8]: " choice

    case $choice in
        1) demo_tutorial ;;
        2) demo_playground ;;
        3) demo_vscode ;;
        4) demo_wash ;;
        5) demo_performance ;;
        6) demo_enterprise ;;
        7) 
            demo_tutorial
            demo_playground
            demo_vscode
            demo_wash
            demo_performance
            demo_enterprise
            ;;
        8) exit 0 ;;
        *) echo "Invalid choice"; main_menu ;;
    esac
}

# Check for required tools
check_requirements() {
    if ! command -v asciinema &> /dev/null; then
        echo -e "${YELLOW}asciinema not found. Install with: brew install asciinema${NC}"
        echo "Or visit: https://asciinema.org/docs/installation"
        exit 1
    fi
}

check_requirements
main_menu

echo -e "${GREEN}Demo recording complete!${NC}"
echo "Files saved in: $DEMO_DIR/"
echo ""
echo "To upload to asciinema.org:"
echo "  asciinema upload $DEMO_DIR/<demo>.cast"
echo ""
echo "To convert to GIF (if agg installed):"
echo "  agg $DEMO_DIR/<demo>.cast $DEMO_DIR/<demo>.gif"