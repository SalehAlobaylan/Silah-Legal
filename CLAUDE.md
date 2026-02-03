# Silah-Legal - AI Context Documentation

## Project Overview

**Silah (صلة)** is an AI-powered legal case management platform for Saudi legal practitioners. This meta-monorepo contains four interconnected microservices providing comprehensive tools for law firms, legal departments, and consultants.

---

## Repository Structure

```
Silah-Legal/
├── Legal-Case-Management-System/          # Backend API (Node.js, Fastify, PostgreSQL)
├── Legal_Case_Management_Website/         # Frontend Dashboard (Next.js 14, React 19)
├── Legal-Case-Management-System-AI-Microservice/  # AI Service (Python, FastAPI, BGE-M3)
├── GP-flutter/                            # Mobile App (Flutter, Dart)
├── CLAUDE.md                              # This file
└── AGENTS.md                              # Agent documentation
```

---

## Technology Stack

### Backend API (`Legal-Case-Management-System/`)
- **Framework**: Fastify 5.6+ (high-performance Node.js framework)
- **Database**: PostgreSQL with Drizzle ORM
- **Auth**: JWT with role-based access control (RBAC)
- **Real-time**: Socket.IO for WebSocket connections
- **Docs**: Swagger at `/docs`
- **Port**: 3000

### Frontend Dashboard (`Legal_Case_Management_Website/`)
- **Framework**: Next.js 14+ with App Router, React 19
- **Language**: TypeScript
- **State**: TanStack Query (server), Zustand (client)
- **UI**: shadcn/ui + Radix UI components
- **Styling**: Tailwind CSS v4
- **Real-time**: Socket.IO client
- **Port**: 3001

### AI Microservice (`Legal-Case-Management-System-AI-Microservice/`)
- **Framework**: FastAPI (Python 3.12)
- **ML Model**: BAAI/bge-m3 multilingual embeddings (Arabic/English)
- **Algorithm**: Cosine similarity matching
- **Port**: 8000

### Mobile App (`GP-flutter/`)
- **Framework**: Flutter (multi-platform: Android, iOS, Web, Desktop)
- **State**: Provider
- **Navigation**: GoRouter
- **DI**: GetIt
- **Status**: Early development

---

## Key Features

### Core Capabilities
1. **AI-Powered Regulation Linking** - Semantic matching between cases and Saudi laws
2. **Multi-Platform** - Web dashboard + mobile app
3. **Bilingual** - Full Arabic/English with RTL support
4. **Real-Time** - Live updates and notifications
5. **Multi-Tenant** - Organization-based data isolation

### Case Types
- Criminal, Civil, Commercial, Labor, Family, Administrative

### User Roles
- **Admin**: Full system access
- **Senior Lawyer**: Case management + team oversight
- **Lawyer**: Full case management
- **Paralegal**: Limited case access
- **Clerk**: Administrative tasks

---

## Development Workflow

### Running All Services

1. **Backend API** (port 3000):
```bash
cd Legal-Case-Management-System
npm install
cp .env.example .env
npm run db:push
npm run dev
```

2. **AI Microservice** (port 8000):
```bash
cd Legal-Case-Management-System-AI-Microservice
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn ai_service.app.main:app --reload
```

3. **Frontend Dashboard** (port 3001):
```bash
cd Legal_Case_Management_Website
npm install
cp .env.example .env
npm run dev
```

4. **Mobile App**:
```bash
cd GP-flutter/gp
flutter pub get
flutter run
```

### Environment Variables

**Backend** (`Legal-Case-Management-System/.env`):
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/silah_legal
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d
PORT=3000
AI_SERVICE_URL=http://localhost:8000
```

**Frontend** (`Legal_Case_Management_Website/.env`):
```bash
NEXT_PUBLIC_API_URL=http://localhost:3000
```

**AI Service** (`Legal-Case-Management-System-AI-Microservice/.env`):
```bash
APP_NAME=Silah AI Service
ENVIRONMENT=development
HOST=0.0.0.0
PORT=8000
EMBEDDINGS_MODEL=bge  # or 'fake' for testing
CORS_ORIGINS=http://localhost:3001
```

---

## Code Patterns & Conventions

### Backend (Node.js/Fastify)
- Route handlers in `src/routes/`
- Services in `src/services/`
- Database schema in `src/db/schema/`
- Middleware for auth, rate limiting, CORS
- Swagger decorators for API docs

### Frontend (Next.js/React)
- App Router structure in `app/`
- Components in `components/`
- Server actions in `app/actions/`
- API calls via TanStack Query hooks
- shadcn/ui for consistent UI components
- Dark/light theme with RTL support

### AI Service (Python/FastAPI)
- FastAPI routers in `ai_service/app/routers/`
- Model loading in `ai_service/app/core/`
- Semantic similarity matching
- Batch processing support

---

## API Endpoints

### Backend API (http://localhost:3000)
- Authentication: `/auth/login`, `/auth/register`
- Cases: `/cases` (CRUD)
- Clients: `/clients` (CRUD)
- Regulations: `/regulations` (CRUD)
- AI Suggestions: `/ai-suggestions`
- Documents: `/documents` (file upload, 10MB limit)
- Users: `/users`
- Socket.IO: Real-time notifications

### AI Service (http://localhost:8000)
- `POST /similarity/find-related` - Find related regulations for a case

---

## Database Schema

Key entities:
- **organizations** - Multi-tenant support
- **users** - User accounts with roles
- **cases** - Legal cases (linked to org/client)
- **clients** - Client information
- **regulations** - Saudi laws and regulations
- **documents** - File attachments
- **ai_suggestions** - Cached AI recommendations
- **notifications** - User notifications
- **user_activities** - Activity tracking
- **achievements** - Gamification badges

---

## Security Considerations

- JWT-based authentication
- Role-based access control (RBAC)
- Rate limiting on endpoints
- CORS protection
- Helmet security headers
- Bcrypt password hashing
- File upload size limits (10MB)
- Organization-level data isolation

---

## Important Notes for AI Agents

### When Working on This Project:

1. **Multi-Service Coordination**: Changes often require updates across 2-3 services (e.g., adding a field requires backend API, frontend UI, and database changes)

2. **Bilingual Support**: Always consider Arabic/English localization. Use RTL-aware components. Text must support both languages.

3. **Real-Time Features**: Socket.IO is used for live updates. New features may need WebSocket event handlers.

4. **File Uploads**: Documents have 10MB size limit. Validate file types and sizes.

5. **AI Integration**: The AI microservice provides regulation suggestions. Backend calls AI service, frontend displays results.

6. **Multi-Tenancy**: All data queries must filter by organization_id. Users only see their org's data.

7. **Role Permissions**: Check user roles before allowing actions. Admin/Senior Lawyer have more privileges.

8. **API Documentation**: Backend uses Swagger. Keep decorators updated for `/docs` endpoint.

9. **TypeScript**: Both backend and frontend use TypeScript. Maintain type safety.

10. **Database Migrations**: Use Drizzle migrations. Run `npm run db:push` for schema changes.

---

## Roadmap Features (Planned)

- Complete Flutter mobile application
- Integration with Najiz portal
- Advanced analytics dashboard
- Document template system
- Calendar and hearing reminders
- Arabic OCR for document processing
- Multi-language document translation
- Cloud deployment (AWS/Azure)

---

## Access Points

- **Frontend**: http://localhost:3001
- **Backend API Docs**: http://localhost:3000/docs
- **AI Service Docs**: http://localhost:8000/docs
- **Database**: PostgreSQL on localhost:5432

---

## Contact & Support

For questions about this project, refer to the main [README.md](README.md) or contact the development team.
