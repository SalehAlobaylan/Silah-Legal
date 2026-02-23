# Silah-Legal (صلة)

An AI-powered legal case management platform designed specifically for Saudi legal practitioners. Silah (صلة) provides comprehensive tools for law firms, legal departments, solo practitioners, and consultants to manage cases, clients, and regulations with intelligent automation.

## Overview

Silah-Legal is a full-stack legal technology platform that combines:

- **AI-Powered Regulation Linking**: Automatically connects cases with relevant Saudi Arabian laws using semantic similarity matching
- **Multi-Platform Support**: Web dashboard and mobile applications
- **Bilingual Interface**: Full Arabic and English localization with RTL support
- **Real-Time Collaboration**: Live updates and notifications across team members
- **Multi-Tenant Architecture**: Serve multiple organizations with isolated data

---

## Quick Setup

```bash
# First-time setup - Initialize all submodules
git submodule update --init --recursive

# Checkout main branch for all submodules
git submodule foreach 'git checkout main'

# Every time you start work - Pull latest changes in all submodules
git submodule foreach git pull origin main

# Check submodule status
git submodule status
```

## Repository Structure

This is a meta-monorepo containing four interconnected microservices:

| Repository | Technology | Purpose |
|------------|------------|---------|
| [Legal-Case-Management-System](./Legal-Case-Management-System/) | Node.js, Fastify, PostgreSQL | Backend API Server |
| [Legal_Case_Management_Website](./Legal_Case_Management_Website/) | Next.js 14, React 19, TypeScript | Frontend Web Dashboard |
| [Legal-Case-Management-System-AI-Microservice](./Legal-Case-Management-System-AI-Microservice/) | Python, FastAPI, BGE-M3 | AI/ML Semantic Matching |
| [GP-flutter](./GP-flutter/) | Flutter, Dart | Mobile Application (In Development) |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Silah Platform                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │   Web Dashboard  │    │   Mobile App     │                   │
│  │   (Next.js)      │    │   (Flutter)      │                   │
│  └────────┬─────────┘    └────────┬─────────┘                   │
│           │                      │                              │
│           └──────────┬───────────┘                              │
│                      ▼                                          │
│           ┌─────────────────────┐                               │
│           │   Backend API       │                               │
│           │   (Fastify/Node)    │                               │
│           └──────────┬──────────┘                               │
│                      │                                          │
│           ┌──────────▼──────────┐                               │
│           │  PostgreSQL DB      │                               │
│           └─────────────────────┘                               │
│                      │                                          │
│           ┌──────────▼──────────┐                               │
│           │  AI Microservice    │                               │
│           │  (FastAPI/Python)   │                               │
│           └─────────────────────┘                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Backend API - Legal-Case-Management-System

**Purpose**: Core REST API server handling all business logic, authentication, and data management.

**Tech Stack**:
- Fastify 5.6+ (High-performance Node.js framework)
- PostgreSQL with Drizzle ORM
- JWT Authentication with role-based access control
- Socket.IO for real-time WebSocket connections
- Swagger API documentation at `/docs`

**Key Features**:
- Multi-tenant organization support
- Personal-first onboarding:
  - users can sign up without entering organization details
  - each user gets a personal workspace organization by default
- Organization lifecycle management:
  - create organization after account creation
  - join organization via invitation code
  - invite/remove members and update member roles
  - leave organization with automatic fallback to personal workspace
- Full CRUD operations for cases, clients, regulations
- Regulation subscription monitoring with a dedicated worker runtime (`worker:reg-monitor`)
- Hash-based regulation versioning with automatic version history creation
- Basic monitor observability endpoints for health and recent run stats
- Document management with file uploads (10MB limit)
- Async document extraction + case-focused AI insights pipeline (summary + related highlights)
- Insights refresh/staleness handling when case narrative changes
- User activity tracking and achievements
- Real-time notifications
- Rate limiting and security middleware

**Running the Backend**:
```bash
cd Legal-Case-Management-System
npm install
cp .env.example .env  # Configure your environment
npm run db:push       # Setup database schema
npm run dev           # Start development server
```

**API Documentation**: Visit `http://localhost:3000/docs` when running

---

### 2. Frontend Web Dashboard - Legal_Case_Management_Website

**Purpose**: Modern web interface for legal practitioners to manage cases, view AI suggestions, and collaborate with teams.

**Tech Stack**:
- Next.js 14+ with App Router and React 19
- TypeScript
- TanStack Query for server state
- Zustand for client state
- shadcn/ui + Radix UI components
- Tailwind CSS v4
- Socket.IO client for real-time updates

**Key Features**:
- Responsive dark/light theme with RTL support
- Updated auth and organization UX:
  - Personal or Create-Organization registration modes
  - Settings page supports invite by email, accept invite code, role updates, member removal, and leave-organization
- Case management with AI-powered regulation suggestions
- High-score regulation subscription suggestion flow on case AI suggestions
- Inline document insights (summary + highlights) in case details
- Regulation detail/version timeline view for tracking amendments
- Client relationship management
- Analytics dashboard
- Real-time notifications
- Bilingual Arabic/English interface

**Running the Frontend**:
```bash
cd Legal_Case_Management_Website
npm install
cp .env.example .env  # Configure API endpoint
npm run dev           # Start development server
```

**Access**: `http://localhost:3001`

---

### 3. AI Microservice - Legal-Case-Management-System-AI-Microservice

**Purpose**: Provides semantic intelligence to automatically link legal cases with relevant Saudi regulations using multilingual embeddings.

**Tech Stack**:
- FastAPI (Python 3.12)
- BAAI/bge-m3 multilingual embedding model (Arabic/English)
- Cosine similarity scoring
- Docker containerization

**Key Features**:
- Semantic matching between case descriptions and regulations
- Multilingual support (Arabic & English)
- Confidence scoring (0.0-1.0) for relevance ranking
- Regulation extraction endpoint for monitoring workflows (`POST /regulations/extract`)
- Document extraction endpoint for case attachments (`POST /documents/extract`)
- Case-focused document insights endpoint (`POST /documents/case-insights`)
- OCR provider switching (`alAPI` primary, configurable fallback provider)
- Batch processing support
- ~200-500ms typical response time

**Running the AI Service**:
```bash
cd Legal-Case-Management-System-AI-Microservice
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn ai_service.app.main:app --reload
```

**Or with Docker**:
```bash
docker-compose up
```

**API Endpoint**: `POST /similarity/find-related`

---

### 4. Mobile Application - GP-flutter

**Purpose**: Native mobile application for on-the-go case management (currently in early development).

**Tech Stack**:
- Flutter multi-platform (Android, iOS, Web, Desktop)
- Provider for state management
- GoRouter for navigation
- GetIt for dependency injection

**Current Status**: In setup phase - architecture established, implementation pending

**Running the App**:
```bash
cd GP-flutter/gp
flutter pub get
flutter run
```

---

## Getting Started

### Prerequisites

- **Node.js** 18+ (for Backend & Frontend)
- **Python** 3.12+ (for AI Microservice)
- **PostgreSQL** 14+
- **Flutter** SDK 3.9+ (for Mobile App)
- **Git** for cloning submodules

### Clone with Submodules

```bash
git clone --recurse-submodules https://github.com/your-username/Silah-Legal.git
cd Silah-Legal
```

If already cloned without submodules:
```bash
git submodule update --init --recursive
```

### Quick Start (All Services)

1. **Start PostgreSQL** (ensure it's running on localhost:5432)

2. **Setup Backend API**:
```bash
cd Legal-Case-Management-System
npm install
cp .env.example .env
# Edit .env with your database credentials
npm run db:push
npm run dev
```

3. **Start AI Microservice** (in a new terminal):
```bash
cd Legal-Case-Management-System-AI-Microservice
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn ai_service.app.main:app --reload --port 8000
```

4. **Start Frontend** (in a new terminal):
```bash
cd Legal_Case_Management_Website
npm install
cp .env.example .env
# Edit .env to point to your backend API
npm run dev
```

5. **Access the Application**:
- Frontend: `http://localhost:3001`
- Backend API: `http://localhost:3000/docs`
- AI Service: `http://localhost:8000/docs`

---

## Environment Variables

### Backend (.env)
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/silah_legal
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d
PORT=3000
AI_SERVICE_URL=http://localhost:8000
```

### Frontend (.env)
```bash
NEXT_PUBLIC_API_URL=http://localhost:3000
```

### AI Service (.env)
```bash
APP_NAME=Silah AI Service
APP_VERSION=1.0.0
ENVIRONMENT=development
HOST=0.0.0.0
PORT=8000
EMBEDDINGS_MODEL=bge  # or 'fake' for testing
CORS_ORIGINS=http://localhost:3001
```

---

## Key Features

### AI-Powered Regulation Linking
When creating a case, lawyers can click "Generate AI Suggestions" to automatically find relevant Saudi regulations based on the case description. The system uses semantic similarity to rank regulations by relevance.

### Case Types Supported
- Criminal
- Civil
- Commercial
- Labor
- Family
- Administrative

### User Roles
- **Admin**: Full system access
- **Senior Lawyer**: Case management and team oversight
- **Lawyer**: Full case management
- **Paralegal**: Limited case access
- **Clerk**: Administrative tasks

### Security Features
- JWT-based authentication
- Role-based access control (RBAC)
- Rate limiting
- CORS protection
- Helmet security headers
- Encrypted password storage (bcrypt)

---

## Roadmap

- [ ] Complete Flutter mobile application
- [ ] Integration with Najiz portal
- [ ] Advanced analytics dashboard
- [ ] Document template system
- [ ] Calendar and hearing reminders
- [ ] Arabic OCR for document processing
- [ ] Multi-language document translation
- [ ] Cloud deployment (AWS/Azure)

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing code style
4. Add tests for new functionality
5. Submit a pull request

## License

[Specify your license here]

## Contact

For questions or support, please contact [your contact information].

---

**Silah (صلة)** - Connecting legal practitioners with intelligent case management.
Admin:      ahmed@alfaisal-law.sa  / password123
Senior Law: fatima@alfaisal-law.sa / password123
Lawyer:     omar@alfaisal-law.sa   / password123
Paralegal:  sara@alfaisal-law.sa / password123
```

### Organization 2: Riyadh Legal Consultants (EASY TO REMEMBER)
```
Admin:      admin@test.com  / test123
Lawyer:     lawyer@test.com   / test123
Paralegal:  sara@test.com    / test123
```

**Password Requirements**: Minimum 4 characters (reduced from 8 for easier testing)

**To Re-seed Database**:
```
cd Legal-Case-Management-System
npm run db:seed -- --force
```
