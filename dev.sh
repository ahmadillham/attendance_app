#!/bin/bash
# ─── Dev Script: Backend + ADB Reverse + Flutter ───
# Jalankan dari root project: ./dev.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN} Starting development environment...${NC}"

# 1. Setup adb reverse
echo -e "${YELLOW} Setting up adb reverse tcp:3000...${NC}"
adb reverse tcp:3000 tcp:3000 && echo -e "${GREEN} adb reverse ready${NC}" || echo -e "${YELLOW}  adb reverse failed — pastikan HP terhubung via USB${NC}"

# 2. Start backend in background
echo -e "${YELLOW}  Starting backend...${NC}"
cd backend && npm run dev &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 3

# 3. Start Flutter
echo -e "${YELLOW} Starting Flutter (${FLUTTER_MODE:---debug})...${NC}"
cd frontend && flutter run ${FLUTTER_MODE:---debug}

# Cleanup: kill backend when Flutter exits
echo -e "${YELLOW} Stopping backend...${NC}"
kill $BACKEND_PID 2>/dev/null
echo -e "${GREEN} Done${NC}"
