# Silah-Legal - Agent Documentation

This file defines specialized agents for working with the Silah-Legal project. Each agent has specific expertise and responsibilities.

---

## Available Agents

### 1. Backend Architect Agent

**Responsibilities**:
- Backend API development in `Legal-Case-Management-System/`
- Database schema design and migrations (Drizzle ORM)
- Fastify route handlers and middleware
- JWT authentication and RBAC implementation
- Socket.IO real-time features
- API documentation (Swagger)

**Tech Stack**:
- Node.js, Fastify, TypeScript
- PostgreSQL, Drizzle ORM
- JWT, Socket.IO

**When to Use**:
- Adding/modifying API endpoints
- Database schema changes
- Authentication/authorization features
- Real-time WebSocket features
- Backend business logic

---

### 2. Frontend Developer Agent

**Responsibilities**:
- Frontend development in `Legal_Case_Management_Website/`
- React 19 components with Next.js 14 App Router
- State management (TanStack Query, Zustand)
- UI components using shadcn/ui
- Bilingual (Arabic/English) interface with RTL support
- Dark/light theme implementation
- Socket.IO client integration

**Tech Stack**:
- Next.js 14, React 19, TypeScript
- TanStack Query, Zustand
- shadcn/ui, Tailwind CSS v4
- Socket.IO client

**When to Use**:
- Building/modifying UI components
- Adding new pages or routes
- State management features
- Theme/styling changes
- Real-time UI updates via Socket.IO

---

### 3. AI/ML Engineer Agent

**Responsibilities**:
- AI microservice development in `Legal-Case-Management-System-AI-Microservice/`
- BGE-M3 embedding model integration
- Semantic similarity matching algorithms
- FastAPI endpoint development
- Batch processing optimization
- Model performance tuning

**Tech Stack**:
- Python 3.12, FastAPI
- BAAI/bge-m3 embeddings
- NumPy, scikit-learn
- Docker

**When to Use**:
- Modifying AI matching algorithms
- Improving recommendation accuracy
- Adding new ML features
- Optimizing inference performance
- Testing AI endpoints

---

### 4. Mobile Developer Agent

**Responsibilities**:
- Flutter app development in `GP-flutter/`
- Multi-platform UI (Android, iOS, Web)
- Provider state management
- GoRouter navigation
- GetIt dependency injection
- API integration with backend

**Tech Stack**:
- Flutter, Dart
- Provider, GoRouter, GetIt

**When to Use**:
- Building mobile features
- Navigation setup
- Mobile-specific UI patterns
- API integration in Flutter
- Platform-specific functionality

---

### 5. Full-Stack Integration Agent

**Responsibilities**:
- Cross-service feature development
- Coordinating changes across backend, frontend, and AI services
- API contract design
- End-to-end feature testing
- Data flow architecture

**When to Use**:
- Features requiring changes in multiple services
- End-to-end feature implementation
- Cross-service debugging
- Architecture decisions

---

### 6. Database & Schema Agent

**Responsibilities**:
- Drizzle schema design
- Database migrations
- Query optimization
- Data integrity constraints
- Multi-tenant data isolation

**When to Use**:
- Adding/modifying database tables
- Writing complex queries
- Performance tuning
- Data migrations

---

### 7. Security & Auth Agent

**Responsibilities**:
- JWT authentication implementation
- Role-based access control (RBAC)
- API security (CORS, rate limiting, Helmet)
- Password hashing (bcrypt)
- File upload security
- Organization-level data isolation

**When to Use**:
- Authentication/authorization features
- Security audits
- Permission system changes
- Secure file handling

---

### 8. Localization Agent

**Responsibilities**:
- Arabic/English bilingual support
- RTL layout implementation
- Translation management
- Locale-aware formatting (dates, numbers)
- Cultural adaptation

**When to Use**:
- Adding translations
- RTL layout fixes
- Locale-specific features
- Bilingual UI components

---

### 9. Testing & QA Agent

**Responsibilities**:
- Backend API testing
- Frontend component testing
- AI service testing
- End-to-end testing
- Performance testing

**When to Use**:
- Writing tests
- Debugging test failures
- Performance optimization
- Quality assurance

---

### 10. DevOps & Deployment Agent

**Responsibilities**:
- Docker containerization
- Docker Compose orchestration
- Environment configuration
- Deployment automation
- CI/CD pipelines

**When to Use**:
- Setting up Docker containers
- Managing deployments
- Environment configuration
- Cloud deployment (AWS/Azure)

---

## Agent Selection Guide

| Task | Primary Agent | Supporting Agents |
|------|---------------|-------------------|
| Add new API endpoint | Backend Architect | Database & Schema |
| Create new UI page | Frontend Developer | Backend Architect |
| Improve AI matching | AI/ML Engineer | Backend Architect |
| Add mobile feature | Mobile Developer | Backend Architect |
| Implement full feature | Full-Stack Integration | All relevant agents |
| Database migration | Database & Schema | Backend Architect |
| Add auth logic | Security & Auth | Backend Architect |
| Fix RTL issues | Localization | Frontend Developer |
| Write tests | Testing & QA | Domain-specific agent |
| Deploy services | DevOps & Deployment | All agents |

---

## Multi-Agent Workflow Example

**Example**: Add "Case Status History" feature

1. **Database & Schema Agent**: Design the `case_status_history` table
2. **Backend Architect**: Create API endpoints for status history
3. **Frontend Developer**: Build UI component to display history
4. **Security & Auth Agent**: Ensure proper access controls
5. **Testing & QA Agent**: Write tests for the feature
6. **Full-Stack Integration Agent**: Verify end-to-end functionality

---

## Agent Collaboration Patterns

### Sequential Workflow
- Agent A completes their part
- Agent B builds on A's work
- Handoff via documentation/commits

### Parallel Workflow
- Multiple agents work independently
- Integration agent coordinates
- Merge changes when ready

### Review Workflow
- Primary agent implements
- Review agent audits
- Iteration until approved

---

## Important Reminders for All Agents

1. **Bilingual Support**: Always consider Arabic/English and RTL layouts
2. **Multi-Tenancy**: Filter all queries by organization_id
3. **Real-Time**: Consider Socket.IO for live updates
4. **Type Safety**: Use TypeScript (backend/frontend)
5. **Documentation**: Update API docs (Swagger) and CLAUDE.md
6. **Security**: Validate inputs, check permissions, sanitize data
7. **Performance**: Monitor AI service latency (~200-500ms target)
8. **Testing**: Write tests for new features
9. **Git Hygiene**: Write clear commit messages, use PRs
10. **User Experience**: Maintain consistent UI/UX patterns

---

## Agent Quick Reference

```
Backend → Legal-Case-Management-System/
Frontend → Legal_Case_Management_Website/
AI → Legal-Case-Management-System-AI-Microservice/
Mobile → GP-flutter/
DB → All services (PostgreSQL)
Auth → Backend API (JWT)
i18n → Frontend (Next.js i18n)
Deploy → Docker Compose / Cloud
```

---

For detailed technical documentation, see [CLAUDE.md](CLAUDE.md).
