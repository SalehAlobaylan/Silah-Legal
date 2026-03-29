# Silah-Legal Design Chapter — AI Image Generation Prompts & Pseudocode

## Table of Contents
1. [System Architecture](#1-system-architecture)
2. [Database Design](#2-database-design)
3. [Modular Decomposition](#3-modular-decomposition)
4. [System Organization](#4-system-organization)
5. [Algorithms](#5-algorithms)
6. [Alternative Designs](#6-alternative-designs)

---

## 1. System Architecture

### Diagram Prompt for AI Image Generation:

```
Create a professional system architecture diagram for Silah-Legal, an AI-powered legal
case management platform for Saudi legal practitioners.

Main components to include:

1. Client Layer:
   - Web Dashboard (Next.js 14 / React 19) — laptop icon, port 3001
   - Mobile App (Flutter — Android, iOS, Web) — smartphone icon
   - Both connect via HTTPS/REST and WebSocket (Socket.IO)

2. Application Layer (Node.js / Fastify 5, port 3000):
   - Auth Service — JWT + Google OAuth 2.0
   - Case Management Controller
   - Regulation Controller (with monitor scheduler)
   - Document Controller (upload, extraction, insights)
   - AI-Links Controller
   - Dashboard & Notification Services
   - Billing & Subscription Controller
   - WebSocket Gateway (Socket.IO) — org and user rooms
   - Swagger API Docs at /docs

3. AI Microservice Layer (Python / FastAPI, port 8000):
   - /similarity/find-related — case-to-regulation ranking
   - /regulations/* — extract, summary-analysis, amendment-impact
   - /documents/* — extract, case-insights
   - /chat, /analyze-case, /summarize-document — AI assistant
   - Core engines: EmbeddingService (BGE-M3), SimilarityService,
     RerankerService (BGE-Reranker-v2-m3), LLMVerifier (Gemini),
     HyDEExpander, AgenticRetriever, ColBERTRetriever

4. Data Layer:
   - PostgreSQL (Drizzle ORM) with pgvector extension
     * regulation_chunks — 1024-dim embeddings
     * document_chunks — 1024-dim embeddings
   - Local File Storage — documents (10 MB limit)

5. External Services:
   - Ministry of Justice (Najiz / MOJ) — regulation source sync
   - Google OAuth 2.0 — SSO login
   - Google Gemini API — LLM verification layer
   - Email / Notification delivery

Style requirements:
- Clean enterprise architecture style, dark-mode preferred
- Color-coded layers:
    Blue   → Client
    Green  → Application (Fastify)
    Purple → AI Microservice (FastAPI)
    Orange → Data (PostgreSQL + pgvector)
    Gray   → External services
- Solid arrows for REST/HTTP calls
- Dashed arrows for WebSocket (Socket.IO) connections
- Cylinder for database, hexagon for ML models
- Label all ports, protocols, and major data flows
- Include a legend
```

### Textual Explanation:

**System Architecture Overview:**

Silah-Legal uses a **coarse-grained microservices architecture** organized into five layers:

1. **Presentation Layer**: A Next.js 14 web dashboard (RTL-capable, bilingual Arabic/English) and a Flutter mobile application serve as the dual client surfaces.
2. **Application Layer**: A Node.js/Fastify 5 API server orchestrates all business logic — authentication, case and client management, regulation monitoring, document processing, billing, and real-time notifications via Socket.IO. Organization-scoped rooms (`org:{orgId}`) and user-scoped rooms (`user:{userId}`) are maintained for targeted event delivery.
3. **Intelligence Layer**: A Python/FastAPI microservice provides a staged AI pipeline. Its `/similarity/find-related` endpoint combines dense vector retrieval (BGE-M3 embeddings), lexical matching (Jaccard), category priors, optional HyDE query expansion, optional ColBERT late-interaction scoring, cross-encoder reranking (BGE-Reranker-v2-m3), and optional Gemini-backed LLM verification. Feature toggles are stored per-organization in `ai_settings` and passed at request time.
4. **Data Layer**: PostgreSQL with the pgvector extension stores all relational data and 1024-dimensional embeddings for both regulation chunks and document chunks. Drizzle ORM provides type-safe schema definitions and migrations.
5. **External Integrations**: The Ministry of Justice (MOJ/Najiz) is the canonical source for Saudi regulations. Google OAuth 2.0 enables SSO. Gemini API provides LLM-based suggestion verification.

**Justification:**
- **Scalability**: The AI microservice can scale independently from the API server, which is important given that embedding and reranking operations are CPU/GPU-intensive.
- **Technology fit**: Python is required for transformer-based ML libraries (sentence-transformers, cross-encoders). Node.js/Fastify serves high-concurrency REST and WebSocket workloads.
- **Maintainability**: Clear service boundaries allow model upgrades (e.g., swapping reranker) without touching API business logic.
- **Progressive enhancement**: Feature flags in `ai_settings` allow per-organization control of advanced AI stages (HyDE, ColBERT, Gemini), so organizations can opt into more expensive features selectively.

---

## 2. Database Design

### Entity-Relationship (E/R) Diagram Prompt:

```
Create a professional Entity-Relationship diagram for Silah-Legal's PostgreSQL schema.
Use Crow's Foot notation. Primary keys underlined. Foreign keys marked (FK).
Color-code entity groups.

CORE ENTITIES (blue):

1. ORGANIZATIONS
   Fields: id (PK), name, country, subscription_tier, license_number,
           contact_info (jsonb), is_personal, personal_owner_user_id (FK→users),
           created_at, updated_at

2. USERS
   Fields: id (PK), organization_id (FK→organizations), email, password_hash,
           full_name, phone, location, bio, specialization, avatar_url,
           role [Admin|Senior_Lawyer|Lawyer|Paralegal|Clerk],
           google_id, is_oauth_user, created_at, updated_at, last_login

3. CASES
   Fields: id (PK), organization_id (FK), case_number, title, description,
           case_type [Criminal|Civil|Commercial|Labor|Family|Administrative],
           status [Draft|Open|In_Progress|Under_Review|Closed|Archived],
           client_info (jsonb), assigned_lawyer_id (FK→users),
           court_jurisdiction, filing_date, next_hearing, created_at, updated_at

4. CLIENTS
   Fields: id (PK), organization_id (FK), name, type [Individual|Company],
           email, phone, address, notes, status, created_at, updated_at

REGULATION ENTITIES (green):

5. REGULATIONS
   Fields: id (PK), title, regulation_number, source_url, source_provider,
           source_serial, source_listing_url, source_metadata (jsonb),
           source_metadata_hash, summary, category, jurisdiction, status,
           effective_date, created_at, updated_at

6. REGULATION_VERSIONS
   Fields: id (PK), regulation_id (FK), version_number, content, content_hash,
           raw_html, artifact_uri, source_metadata (jsonb), extraction_metadata (jsonb),
           changes_summary, fetched_at, created_by

7. REGULATION_CHUNKS
   Fields: id (PK), regulation_id (FK), regulation_version_id (FK),
           chunk_index, content, line_start, line_end, article_ref,
           token_count, embedding (vector 1024), metadata (jsonb),
           created_at, updated_at

8. REGULATION_INSIGHTS
   Fields: id (PK), regulation_id (FK), regulation_version_id (FK),
           language_code, status, summary, obligations_json, risk_flags_json,
           key_dates_json, citations_json, source_text_hash, method,
           attempt_count, created_at, updated_at

9. REGULATION_AMENDMENT_IMPACTS
   Fields: id (PK), regulation_id (FK), from_version_id (FK), to_version_id (FK),
           language_code, status, what_changed_json, legal_impact_json,
           affected_parties_json, citations_json, diff_fingerprint_hash,
           method, attempt_count, created_at, updated_at

10. REGULATION_SUBSCRIPTIONS
    Fields: id (PK), user_id (FK), organization_id (FK), regulation_id (FK),
            source_url, check_interval_hours, is_active,
            last_checked_at, last_content_hash, next_check_at, created_at, updated_at

11. REGULATION_MONITOR_RUNS
    Fields: id (PK), started_at, finished_at, status, trigger_source,
            triggered_by_user_id (FK), dry_run, scanned, changed,
            versions_created, failed, error_message, created_at

AI/LINK ENTITIES (purple):

12. CASE_REGULATION_LINKS
    Fields: id (PK), case_id (FK), regulation_id (FK),
            matched_regulation_version_id (FK→regulation_versions),
            similarity_score, method, verified, verified_by (FK→users),
            verified_at, evidence_sources, match_explanation (jsonb),
            matched_with_documents, created_at

13. AI_SETTINGS
    Fields: id (PK), organization_id (FK UNIQUE),
            llm_verification_enabled, cross_encoder_enabled, hyde_enabled,
            colbert_enabled, agentic_retrieval_enabled,
            semantic_weight, support_weight, lexical_weight, category_weight,
            min_final_score, min_pair_score, gemini_model,
            cross_encoder_top_n, colbert_top_n, gemini_top_n_candidates,
            agentic_max_rounds, created_at, updated_at

DOCUMENT ENTITIES (yellow):

14. DOCUMENTS
    Fields: id (PK), case_id (FK), file_name, original_name, file_path,
            file_size, mime_type, uploaded_by (FK→users), created_at

15. DOCUMENT_CHUNKS
    Fields: id (PK), organization_id (FK), document_id (FK),
            chunk_index, content, content_lang, token_count,
            embedding (vector 1024), metadata (jsonb), created_at, updated_at

16. DOCUMENT_EXTRACTIONS
    Fields: id (PK), document_id (FK), case_id (FK), organization_id (FK),
            file_hash, status, extracted_text, normalized_text_hash,
            extraction_method, ocr_provider_used,
            insights_status, insights_summary, insights_highlights_json,
            insights_citations_json, attempt_count, created_at, updated_at

USER/SYSTEM ENTITIES (gray):

17. NOTIFICATIONS
    Fields: id (PK), user_id (FK), organization_id (FK), type, title, message,
            related_case_id, related_regulation_id, read, read_at, created_at

18. NOTIFICATION_PREFERENCES
    Fields: id (PK), user_id (FK), email_alerts, push_notifications,
            ai_suggestions, regulation_updates, case_updates, system_alerts,
            quiet_hours_enabled, quiet_hours_start, quiet_hours_end,
            digest_enabled, digest_frequency, created_at, updated_at

19. USER_ACTIVITIES
    Fields: id (PK), user_id (FK), type, action, title, reference_id, created_at

20. USER_ACHIEVEMENTS
    Fields: id (PK), user_id (FK), title, description, icon, awarded_at

21. ORGANIZATION_INVITATIONS
    Fields: id (PK), organization_id (FK), email, role, code_hash, status,
            expires_at, invited_by_user_id (FK), accepted_by_user_id (FK),
            accepted_at, created_at, updated_at

22. LOGIN_ACTIVITY
    Fields: id (PK), user_id (FK), device, browser, ip, location, login_at

BILLING ENTITIES (orange):

23. BILLING_PLANS
    Fields: id (PK), name, tier, price_monthly, price_yearly,
            currency, features (jsonb), is_active, created_at, updated_at

24. SUBSCRIPTIONS
    Fields: id (PK), organization_id (FK), plan_id (FK),
            status, billing_cycle, start_date, end_date,
            cancel_at_period_end, created_at, updated_at

25. INVOICES
    Fields: id (PK), invoice_number, organization_id (FK), subscription_id (FK),
            amount, currency, status, issue_date, due_date, paid_date,
            pdf_path, metadata, created_at, updated_at

26. PAYMENTS
    Fields: id (PK), invoice_id (FK), amount, currency, method,
            status, provider, provider_transaction_id, metadata,
            created_at, updated_at

Key cardinalities:
- 1 Organization → N Users, Cases, Clients, Subscriptions, AI_Settings (1:1)
- 1 Case → N Documents, Case_Regulation_Links
- 1 Regulation → N Versions, Chunks, Insights, Subscriptions, Amendment_Impacts
- 1 Document → N Chunks, 1 Extraction
- 1 User → N Notifications, Activities, Achievements, Login_Activity
```

### Data Dictionary (Key Entities):

```pseudocode
STRUCTURE DataDictionary:

    ENTITY Organization:
        id: UUID (Primary Key, auto-generated)
        name: VARCHAR(255) — "Organization / law firm name"
        country: VARCHAR(100) — "ISO country code (default SA)"
        subscription_tier: ENUM — "free | professional | enterprise"
        license_number: VARCHAR(100) — "Official law firm license"
        contact_info: JSONB — "{ phone, address, ... }"
        is_personal: BOOLEAN — "Single-user personal org flag"
        personal_owner_user_id: UUID (FK → users.id) — "Owner for personal orgs"
        created_at, updated_at: TIMESTAMP

    ENTITY User:
        id: UUID (Primary Key)
        organization_id: UUID (FK → organizations.id)
        email: VARCHAR(255) UNIQUE
        password_hash: VARCHAR(255) — "bcrypt (nullable for OAuth users)"
        full_name: VARCHAR(255)
        phone: VARCHAR(50)
        location: VARCHAR(255)
        bio: TEXT
        specialization: VARCHAR(255) — "e.g., Criminal Law, Family Law"
        avatar_url: VARCHAR(500) — "Profile photo path"
        role: ENUM — "Admin | Senior_Lawyer | Lawyer | Paralegal | Clerk"
        google_id: VARCHAR(255) — "Google OAuth subject ID"
        is_oauth_user: BOOLEAN
        last_login: TIMESTAMP
        created_at, updated_at: TIMESTAMP

    ENTITY Case:
        id: UUID (Primary Key)
        organization_id: UUID (FK → organizations.id)
        case_number: VARCHAR(100) UNIQUE — "Human-readable case ref"
        title: VARCHAR(500)
        description: TEXT
        case_type: ENUM — "Criminal | Civil | Commercial | Labor | Family | Administrative"
        status: ENUM — "Draft | Open | In_Progress | Under_Review | Closed | Archived"
        client_info: JSONB — "Snapshot of client at link time"
        assigned_lawyer_id: UUID (FK → users.id)
        court_jurisdiction: VARCHAR(255)
        filing_date: DATE
        next_hearing: TIMESTAMP
        created_at, updated_at: TIMESTAMP

    ENTITY Regulation:
        id: UUID (Primary Key)
        title: VARCHAR(500)
        regulation_number: VARCHAR(100) — "Official MOJ regulation number"
        source_url: VARCHAR(500) — "Canonical URL at MOJ"
        source_provider: VARCHAR(100) — "moj | manual"
        source_metadata: JSONB — "Raw metadata from source scrape"
        source_metadata_hash: VARCHAR(64) — "SHA-256 for change detection"
        summary: TEXT — "AI-generated summary"
        category: VARCHAR(100)
        jurisdiction: VARCHAR(100)
        status: ENUM — "Active | Amended | Repealed"
        effective_date: DATE
        created_at, updated_at: TIMESTAMP

    ENTITY Regulation_Chunk:
        id: UUID (Primary Key)
        regulation_id: UUID (FK → regulations.id)
        regulation_version_id: UUID (FK → regulation_versions.id)
        chunk_index: INTEGER
        content: TEXT — "Chunked article text"
        line_start, line_end: INTEGER — "Source line range"
        article_ref: VARCHAR(100) — "e.g., Article 12"
        token_count: INTEGER
        embedding: VECTOR(1024) — "BGE-M3 embedding (pgvector)"
        metadata: JSONB
        created_at, updated_at: TIMESTAMP

    ENTITY Case_Regulation_Link:
        id: UUID (Primary Key)
        case_id: UUID (FK → cases.id)
        regulation_id: UUID (FK → regulations.id)
        matched_regulation_version_id: UUID (FK → regulation_versions.id)
        similarity_score: DECIMAL(5,4) — "0.0000 – 1.0000"
        method: VARCHAR(100) — "Pipeline variant used (e.g., bge+reranker+gemini)"
        verified: BOOLEAN — "Lawyer-confirmed link"
        verified_by: UUID (FK → users.id)
        verified_at: TIMESTAMP
        evidence_sources: TEXT[] — "Chunk refs or doc refs supporting match"
        match_explanation: JSONB — "Score breakdown by stage"
        matched_with_documents: BOOLEAN — "Whether doc embeddings influenced match"
        created_at: TIMESTAMP

    ENTITY AI_Settings:
        id: UUID (Primary Key)
        organization_id: UUID (FK UNIQUE → organizations.id)
        llm_verification_enabled: BOOLEAN — "Enable Gemini verification stage"
        cross_encoder_enabled: BOOLEAN — "Enable cross-encoder reranking"
        hyde_enabled: BOOLEAN — "Enable HyDE query expansion"
        colbert_enabled: BOOLEAN — "Enable ColBERT late-interaction scoring"
        agentic_retrieval_enabled: BOOLEAN — "Enable agentic multi-round retrieval"
        semantic_weight: DECIMAL — "Weight for cosine similarity score"
        lexical_weight: DECIMAL — "Weight for Jaccard lexical overlap"
        support_weight: DECIMAL — "Weight for supporting evidence score"
        category_weight: DECIMAL — "Weight for case-type / category prior"
        min_final_score: DECIMAL — "Minimum composite score to surface a link"
        min_pair_score: DECIMAL — "Minimum score per (case, regulation) pair"
        cross_encoder_top_n: INTEGER — "Candidates sent to cross-encoder"
        colbert_top_n: INTEGER
        gemini_top_n_candidates: INTEGER
        agentic_max_rounds: INTEGER
        gemini_model: VARCHAR(100) — "e.g., gemini-2.0-flash"
        created_at, updated_at: TIMESTAMP
```

---

## 3. Modular Decomposition

### Class Diagram Prompt (UML):

```
Create a professional UML Class Diagram for Silah-Legal's core modules.
Use standard UML notation: three-section boxes, visibility prefixes (+ - #).
Color-code by module group.

MODULE 1 — Authentication & Identity (blue):
  Class: AuthService
  + login(email: String, password: String): AuthToken
  + register(userData: RegisterDTO): User
  + verifyJWT(token: String): UserContext
  + hashPassword(password: String): String
  + googleOAuthCallback(code: String): AuthToken
  + refreshUserContext(userId: UUID): UserContext

  Class: AuthToken
  + accessToken: String
  + user: UserSummary
  + expiresIn: Integer

MODULE 2 — Case Management (green):
  Class: CaseService
  + createCase(orgId: UUID, data: CaseDTO): Case
  + updateCase(id: UUID, data: CaseDTO): Case
  + getCaseById(id: UUID, orgId: UUID): Case
  + listCases(orgId: UUID, filters: CaseFilters): PaginatedCases
  + deleteCase(id: UUID): Boolean
  + assignLawyer(caseId: UUID, lawyerId: UUID): Case

  Class: Case
  - id: UUID
  - caseNumber: String
  - title: String
  - description: String
  - caseType: CaseType
  - status: CaseStatus
  - clientInfo: JSONB
  - assignedLawyerId: UUID
  - nextHearing: DateTime
  + addDocument(doc: Document): void
  + generateLinks(): CaseRegulationLink[]

MODULE 3 — AI Regulation Linking (purple):
  Class: AILinksService
  + generateLinks(caseId: UUID, options: LinkOptions): CaseRegulationLink[]
  + verifyLink(linkId: UUID, userId: UUID): CaseRegulationLink
  + dismissLink(linkId: UUID): void
  + refreshLinks(caseId: UUID): CaseRegulationLink[]

  Class: AIClientService   [Backend → AI Microservice client]
  + findRelated(payload: FindRelatedRequest): RegulationMatch[]
  + analyzeCase(caseId: UUID, text: String): AnalysisResult
  + summarizeDocument(docId: UUID, text: String): String

  Class: EmbeddingService  [AI Microservice — Python]
  - provider: String   // "bge" | "fake"
  - model: SentenceTransformer
  + embed(texts: List[String]): List[Vector]
  + embedSingle(text: String): Vector

  Class: SimilarityService  [AI Microservice — Python]
  + rank(query: String, corpus: List[String], topK: Integer): List[RankedItem]
  - cosineSimilarity(a: Vector, b: Vector): Float

  Class: RerankerService  [AI Microservice — Python]
  - model: CrossEncoder  // BAAI/bge-reranker-v2-m3
  + rerank(query: String, candidates: List[String], topN: Integer): List[ScoredCandidate]

  Class: LLMVerifier  [AI Microservice — Python]
  - geminiClient: GeminiAPI
  + verify(caseText: String, regulationText: String): VerificationResult

  Class: HyDEExpander  [AI Microservice — Python]
  + expand(query: String): List[String]  // hypothetical document embeddings

  Class: AgenticRetriever  [AI Microservice — Python]
  + retrieve(query: String, maxRounds: Integer): List[RegulationChunk]

MODULE 4 — Regulation Management (green):
  Class: RegulationService
  + createRegulation(data: RegulationDTO): Regulation
  + updateRegulation(id: UUID, data: RegulationDTO): Regulation
  + listRegulations(filters: RegFilters): PaginatedRegulations
  + getVersions(id: UUID): RegulationVersion[]
  + compareVersions(id: UUID, v1: Int, v2: Int): DiffResult

  Class: RegulationMonitorService
  + runMonitor(dryRun: Boolean): MonitorRunResult
  + syncMOJSource(): SyncResult
  + checkSubscriptions(): void

  Class: RegulationInsightsService
  + generateInsights(regulationId: UUID, lang: String): RegulationInsights
  + refreshInsights(regulationId: UUID): void

  Class: RegulationAmendmentImpactService
  + computeImpact(regId: UUID, fromV: Int, toV: Int): AmendmentImpact
  + refreshImpact(regId: UUID): void

MODULE 5 — Document Management (yellow):
  Class: DocumentService
  + uploadDocument(caseId: UUID, file: MultipartFile): Document
  + downloadDocument(id: UUID): FileStream
  + deleteDocument(id: UUID): Boolean
  + getExtractionStatus(id: UUID): ExtractionStatus

  Class: DocumentExtractionService
  + extract(documentId: UUID): ExtractionResult
  + refreshExtraction(documentId: UUID): void

  Class: DocumentRAGService
  + generateInsights(docId: UUID, caseContext: String): DocumentInsights
  + chunkAndEmbed(docId: UUID, text: String): DocumentChunk[]

MODULE 6 — Notification & Real-Time (orange):
  Class: NotificationService
  + createNotification(userId: UUID, payload: NotifPayload): Notification
  + markRead(notifId: UUID): void
  + markAllRead(userId: UUID): void
  + getUnreadCount(userId: UUID): Integer

  Class: NotificationDeliveryService
  + deliver(userId: UUID, event: String, data: Object): void
  + broadcastToOrg(orgId: UUID, event: String, data: Object): void

  Class: WebSocketGateway  [Socket.IO]
  - rooms: Map<String, Set<Socket>>  // "org:{id}", "user:{id}"
  + handleConnect(socket: Socket): void
  + handleDisconnect(socket: Socket): void
  + emitToUser(userId: UUID, event: String, payload: Any): void
  + broadcastToOrg(orgId: UUID, event: String, payload: Any): void

MODULE 7 — Organization & Team (gray):
  Class: OrganizationService
  + createOrganization(data: OrgDTO): Organization
  + getOrganization(id: UUID): Organization
  + updateOrganization(id: UUID, data: OrgDTO): Organization

  Class: TeamService
  + inviteMember(orgId: UUID, email: String, role: Role): Invitation
  + acceptInvitation(code: String, userId: UUID): void
  + updateMemberRole(memberId: UUID, role: Role): void
  + removeMember(memberId: UUID): void

Relationships:
- AILinksService depends on AIClientService (HTTP to AI microservice)
- CaseService uses AILinksService, DocumentService, NotificationDeliveryService
- RegulationMonitorService uses RegulationInsightsService, RegulationAmendmentImpactService
- DocumentRAGService uses EmbeddingService (remote call)
- WebSocketGateway is used by NotificationDeliveryService
- All services depend on AuthService for user context
```

### Data Flow Diagram Prompt (AI Regulation Pipeline):

```
Create a Data Flow Diagram (DFD Level 1) for the AI Regulation Linking pipeline in Silah-Legal.

External Entities:
- Lawyer (User)
- Ministry of Justice (MOJ) — external regulation source

Data Stores:
- D1: Cases (PostgreSQL)
- D2: Regulations + Chunks (PostgreSQL + pgvector)
- D3: Documents + Chunks (PostgreSQL + pgvector)
- D4: Case_Regulation_Links (PostgreSQL)
- D5: AI_Settings (PostgreSQL)

Processes:

P1 — Case Text Assembly
  Input: case title + description from D1
         document extracted text from D3 (if matched_with_documents = true)
  Output: assembled case text payload

P2 — HyDE Query Expansion (optional, flag from D5)
  Input: assembled case text
  Output: hypothetical regulation passages (expanded queries)

P3 — Dense Vector Retrieval
  Input: query text (P1 or P2 output)
  Model: BGE-M3 (BAAI/bge-m3, 1024-dim)
  Index: regulation_chunks.embedding in pgvector (D2)
  Output: top-K regulation chunks with cosine scores

P4 — Composite Scoring
  Input: retrieval results from P3
  Components:
    - Semantic score: cosine similarity (weight from D5)
    - Lexical score: Jaccard token overlap (weight from D5)
    - Category prior: case_type ↔ regulation.category match (weight from D5)
    - Support score: corroborating chunk count (weight from D5)
  Output: composite-scored candidate list

P5 — ColBERT Late Interaction (optional, flag from D5)
  Input: query embedding + candidate chunk token embeddings
  Output: re-scored candidates (MaxSim aggregation)

P6 — Cross-Encoder Reranking (optional, flag from D5)
  Model: BAAI/bge-reranker-v2-m3
  Input: top-N (case, regulation excerpt) pairs
  Output: refined similarity scores

P7 — LLM Verification (optional, flag from D5)
  Model: Gemini (configurable model per org)
  Input: top-M candidates after cross-encoder
  Output: verification scores, legal reasoning explanation

P8 — Score Fusion & Threshold Filter
  Input: scores from P4 / P5 / P6 / P7
  Config: min_final_score, min_pair_score from D5
  Output: filtered and ranked CaseRegulationLink objects

P9 — Persist & Notify
  Input: ranked links from P8
  Output → D4: stored case_regulation_links
  Output → Lawyer: Socket.IO event "ai-links.generated"

MOJ Sync (separate flow):
  MOJ → Regulation Monitor → D2 (new regulation_versions + re-embed chunks)

Style:
- Circles for processes (P1–P9)
- Parallel lines for data stores (D1–D5)
- Rectangles for external entities
- Arrows with data labels
- Shade optional stages (P2, P5, P6, P7) differently
```

---

## 4. System Organization

### Sequence Diagram Prompt (Generate AI Links Flow):

```
Create a UML Sequence Diagram for the "Generate AI Regulation Links" use case.

Participants (left to right):
1. Lawyer (User)
2. Frontend Dashboard (Next.js)
3. Backend API (Fastify — AILinksController)
4. AIClientService (Backend service)
5. AI Microservice (FastAPI — /similarity/find-related)
6. PostgreSQL DB

Sequence:

Lawyer → Frontend: Click "Generate Links" on case page
Frontend → Backend: POST /api/ai-links/{caseId}/generate
  (Authorization: Bearer <JWT>)

Backend → DB: SELECT case WHERE id = caseId AND organization_id = orgId
DB → Backend: case { title, description, case_type }

Backend → DB: SELECT document extracted texts WHERE case_id = caseId
DB → Backend: document texts (if any)

Backend → DB: SELECT ai_settings WHERE organization_id = orgId
DB → Backend: ai_settings { hyde_enabled, cross_encoder_enabled, ... weights }

Backend → AIClientService: buildFindRelatedPayload(case, docs, aiSettings)

AIClientService → AI Microservice: POST /similarity/find-related
  Body: {
    case_text: "...",
    case_type: "Criminal",
    options: {
      hyde_enabled: true,
      cross_encoder_enabled: true,
      llm_verification_enabled: false,
      semantic_weight: 0.6,
      lexical_weight: 0.2,
      category_weight: 0.1,
      support_weight: 0.1,
      top_k: 20,
      top_n_rerank: 10,
      min_score: 0.45
    }
  }

[AI Microservice internal — shown as activation bars]
AI Microservice → AI Microservice: HyDE expand query (if enabled)
AI Microservice → DB: pgvector ANN search on regulation_chunks.embedding
DB → AI Microservice: top-K chunks with cosine scores
AI Microservice → AI Microservice: composite score (cosine + Jaccard + category + support)
AI Microservice → AI Microservice: cross-encoder rerank top-20 (if enabled)
AI Microservice → AI Microservice: filter by min_score, deduplicate per regulation

AI Microservice → AIClientService: RegulationMatch[] {
  regulation_id, title, similarity_score, method,
  evidence_sources, match_explanation, excerpt
}

Backend → DB: INSERT INTO case_regulation_links (bulk upsert)
DB → Backend: confirmed link IDs

Backend → DB: INSERT INTO notifications (user_id, type: "ai_suggestions")
DB → Backend: notification created

Backend → Frontend: 200 OK { links: [...], count: 8 }

Backend → Frontend: Socket.IO emit "ai-links.generated"
  (to room "user:{lawyerId}")

Frontend → Lawyer: Display ranked regulation links with score breakdown

Style:
- Color lifelines: blue=client, green=backend, purple=AI microservice, orange=DB
- Solid arrows for synchronous calls, dashed for returns
- Activation bars on all participants
- Box fragment [AI Pipeline] around internal AI processing steps
- Numbered messages
- Show alt fragment: [if no regulations found] → return empty links
```

### Activity Diagram Prompt (User Registration & Org Onboarding):

```
Create a UML Activity Diagram for the User Registration flow in Silah-Legal.
Use swimlanes: [User], [Frontend], [Backend API], [Database]

Swimlane: User
  Start → Choose: "Join existing org" or "Create new org"

Swimlane: Frontend
  → Collect: email, full_name, password, role, [org_name if new]
  → Submit: POST /api/auth/register
  → On success: store JWT, redirect to /dashboard

Swimlane: Backend API
  Receive registration request
  → Validate input (email format, password length ≥ 4)
  → Check email uniqueness in DB
    Decision: Email exists?
      YES → Return 409 "Email already in use"
      NO → Continue
  → Decision: existing org?
      YES → Look up org by email domain
      NO → INSERT new organization
  → Hash password with bcrypt
  → INSERT user record (with organization_id, role)
  → Sign JWT { userId, organizationId, role, email }
  → INSERT default notification_preferences for user
  → INSERT user_activity { type: "REGISTER" }
  → Return { accessToken, user }

Swimlane: Database
  → SELECT users WHERE email = ?
  → INSERT organizations (if new)
  → INSERT users
  → INSERT notification_preferences
  → INSERT user_activities

End: User lands on /dashboard

Also show alternative OAuth flow:
User → Click "Continue with Google"
Frontend → GET /api/auth/google → Redirect to Google
Google → Callback /api/auth/google/callback
Backend → Upsert user (google_id, is_oauth_user=true)
Backend → Return JWT

Style:
- Rounded rectangles for actions
- Diamonds for decisions
- Swimlane borders clearly separate User / Frontend / Backend / DB
- Parallel bars for fork/join where async happens
- Color-code by swimlane
```

### State Diagram Prompt (Case Lifecycle):

```
Create a UML State Diagram for the lifecycle of a Case in Silah-Legal.

States:
1. [Draft]
   Entry: Initialize with creation timestamp, auto-generate case_number
   Do: Validate required fields

2. [Open]
   Entry: Notify assigned_lawyer_id if set
   Do: Accept document uploads, allow AI link generation

3. [In_Progress]
   Entry: Record start date, notify team
   Do: Track document additions, regulation links, hearing dates

4. [Under_Review]
   Entry: Notify senior lawyers in organization
   Do: Await approval; lawyer can still add documents

5. [Closed]
   Entry: Record close date, archive documents, final AI link snapshot
   Do: Read-only state

6. [Archived]
   Entry: Move to cold storage partition

Transitions:
Draft → Open: "Submit" [all required fields present AND client_info set]
Open → In_Progress: "Start Work" [assigned_lawyer_id not null]
Open → Archived: "Delete" [by Admin only]
In_Progress → Under_Review: "Request Review" [by assigned Lawyer]
In_Progress → Open: "Pause" [by Lawyer or Senior Lawyer]
Under_Review → In_Progress: "Reject" [by Senior Lawyer — feedback required]
Under_Review → Closed: "Approve" [by Senior Lawyer]
Closed → Open: "Reopen" [by Senior Lawyer or Admin]
Closed → Archived: "Archive" [after retention period or manual by Admin]

Internal Events (can occur in Open / In_Progress / Under_Review):
- uploadDocument() → triggers extraction pipeline
- generateLinks() → triggers AI regulation linking
- verifyLink() → lawyer confirms a link
- setNextHearing(date) → hearing reminder scheduled

Style:
- Rounded rectangles for states
- Solid arrows for transitions with [guard] labels
- Filled circle for initial state, bullseye for final
- Entry/Do/Exit annotations inside state boxes
- Color-code by phase: gray=Draft, blue=Open, yellow=In_Progress,
  orange=Under_Review, green=Closed, dark=Archived
```

### WebSocket Event Map Prompt:

```
Create a diagram showing the real-time Socket.IO event flow in Silah-Legal.

Server Rooms:
- "org:{orgId}" — all users in an organization
- "user:{userId}" — individual user

Events emitted by Backend → Frontend:

| Event Name              | Room Target       | Trigger                                  |
|-------------------------|-------------------|------------------------------------------|
| connected               | user:{userId}     | Successful WebSocket handshake           |
| ai-links.generated      | user:{userId}     | AI link generation job completed         |
| ai-links.verified       | org:{orgId}       | A link is verified by a lawyer           |
| ai-links.dismissed      | user:{userId}     | A link is dismissed                      |
| notification            | user:{userId}     | Any new system notification              |
| regulation_updated      | org:{orgId}       | Monitor detects a regulation change      |
| case-links-refreshed    | user:{userId}     | Case regulation links refreshed          |
| link-updated            | org:{orgId}       | Individual link status changed           |
| document-uploaded       | org:{orgId}       | Document successfully uploaded           |
| document-deleted        | org:{orgId}       | Document deleted                         |
| case-updated            | org:{orgId}       | Case fields updated                      |

Frontend listeners (use-websocket.ts):
- On "ai-links.generated" → invalidate useAILinks query
- On "regulation_updated" → invalidate useRegulations query, show toast
- On "notification" → increment unread count in Zustand alerts-store
- On "case-updated" → invalidate useCases / useCaseById queries
- On "document-uploaded/deleted" → invalidate useDocuments query

Style:
- Left column: Backend (green box) emitting arrows
- Right column: Frontend (blue box) receiving and reacting
- Annotate each arrow with the event name and triggering action
- Show Zustand store updates as side effects on the right
```

---

## 5. Algorithms

### Algorithm 1: Multi-Stage AI Regulation Linking

**Pseudocode:**

```pseudocode
// Primary endpoint: POST /similarity/find-related
FUNCTION findRelatedRegulations(
    caseText: String,
    caseType: String,
    options: PipelineOptions
)   RETURNS Array<RegulationMatch>

    // ── Stage 0: Text preprocessing ──
    normalizedText ← preprocessText(caseText)

    // ── Stage 1: Optional HyDE query expansion ──
    IF options.hyde_enabled THEN
        hypotheticalDocs ← hydeExpander.expand(normalizedText)
        queries ← [normalizedText] + hypotheticalDocs
    ELSE
        queries ← [normalizedText]
    END IF

    // ── Stage 2: Dense retrieval via pgvector ──
    candidateChunks ← []
    FOR EACH query IN queries DO
        queryEmbedding ← embeddingService.embed(query)
        chunks ← database.vectorSearch(
            table: "regulation_chunks",
            queryVector: queryEmbedding,
            topK: options.top_k,
            filter: caseType != NULL ? {category: caseType} : NULL
        )
        candidateChunks.MERGE(chunks)
    END FOR
    candidateChunks ← DEDUPLICATE(candidateChunks, by: regulation_id)

    // ── Stage 3: Composite scoring ──
    scoredCandidates ← []
    FOR EACH chunk IN candidateChunks DO
        semanticScore ← chunk.cosineScore
        lexicalScore ← jaccardOverlap(normalizedText, chunk.content)
        categoryScore ← (chunk.regulationCategory == caseType) ? 1.0 : 0.0
        supportScore ← countSupportingChunks(chunk.regulation_id, queries) / MAX_CHUNKS

        compositeScore ←
            (options.semantic_weight × semanticScore) +
            (options.lexical_weight  × lexicalScore)  +
            (options.category_weight × categoryScore) +
            (options.support_weight  × supportScore)

        IF compositeScore >= options.min_pair_score THEN
            scoredCandidates.APPEND({
                regulation_id: chunk.regulation_id,
                score: compositeScore,
                evidence: chunk.id,
                semanticScore, lexicalScore, categoryScore, supportScore
            })
        END IF
    END FOR

    scoredCandidates ← DEDUP_AND_MAX(scoredCandidates, by: regulation_id)
    scoredCandidates.SORT(DESCENDING BY score)

    // ── Stage 4: Optional ColBERT late interaction ──
    IF options.colbert_enabled THEN
        topCandidates ← scoredCandidates[0 : options.colbert_top_n]
        colbertScores ← colbertRetriever.score(queryEmbedding, topCandidates)
        scoredCandidates ← MERGE_SCORES(scoredCandidates, colbertScores, weight: 0.3)
        scoredCandidates.SORT(DESCENDING BY score)
    END IF

    // ── Stage 5: Optional cross-encoder reranking ──
    IF options.cross_encoder_enabled THEN
        rerankerInput ← scoredCandidates[0 : options.cross_encoder_top_n]
        rerankerInput ← buildPairs(normalizedText, rerankerInput)
        rerankerScores ← rerankerService.rerank(rerankerInput)
        scoredCandidates ← BLEND_SCORES(scoredCandidates, rerankerScores, alpha: 0.5)
        scoredCandidates.SORT(DESCENDING BY score)
    END IF

    // ── Stage 6: Optional LLM verification ──
    IF options.llm_verification_enabled THEN
        geminiInput ← scoredCandidates[0 : options.gemini_top_n_candidates]
        verifiedResults ← llmVerifier.verify(normalizedText, geminiInput)
        scoredCandidates ← APPLY_VERIFICATION(scoredCandidates, verifiedResults)
        scoredCandidates.SORT(DESCENDING BY score)
    END IF

    // ── Stage 7: Final threshold filter + return ──
    finalResults ← scoredCandidates
        .FILTER(item → item.score >= options.min_final_score)
        .TAKE(options.top_k_final)

    RETURN finalResults.MAP(item → {
        regulation_id: item.regulation_id,
        title: item.regulation.title,
        similarity_score: item.score,
        method: buildMethodString(options),
        evidence_sources: item.evidence,
        match_explanation: {
            semantic: item.semanticScore,
            lexical: item.lexicalScore,
            category: item.categoryScore,
            support: item.supportScore
        },
        excerpt: extractExcerpt(item.regulation.content, 250)
    })
END FUNCTION

// ── Helpers ──

FUNCTION jaccardOverlap(textA: String, textB: String) RETURNS Float
    tokensA ← tokenize(textA)
    tokensB ← tokenize(textB)
    intersection ← |tokensA ∩ tokensB|
    union ← |tokensA ∪ tokensB|
    IF union = 0 THEN RETURN 0.0
    RETURN intersection / union
END FUNCTION

FUNCTION cosineSimilarity(vecA: Float[], vecB: Float[]) RETURNS Float
    dot ← SUM(vecA[i] × vecB[i] for i in range(len))
    normA ← SQRT(SUM(vecA[i]² for i))
    normB ← SQRT(SUM(vecB[i]² for i))
    IF normA = 0 OR normB = 0 THEN RETURN 0.0
    RETURN dot / (normA × normB)
END FUNCTION

FUNCTION preprocessText(text: String) RETURNS String
    // Normalize Unicode (NFC for Arabic)
    text ← text.NORMALIZE("NFC")
    // Collapse whitespace
    text ← text.REPLACE(/\s+/, " ").TRIM()
    // Truncate to model max tokens (~8192 chars for BGE-M3)
    IF LENGTH(text) > 8192 THEN text ← text[0:8192]
    RETURN text
END FUNCTION
```

---

### Algorithm 2: JWT Authentication & Role-Based Authorization

**Pseudocode:**

```pseudocode
// POST /api/auth/login
FUNCTION authenticateUser(email: String, password: String) RETURNS AuthToken

    // Input validation
    IF email IS EMPTY OR password IS EMPTY THEN
        THROW HTTPError(400, "Email and password are required")
    END IF

    // Lookup user
    user ← DB.queryOne("SELECT * FROM users WHERE email = ?", [email])
    IF user IS NULL THEN
        THROW HTTPError(401, "Invalid credentials")  // Do not reveal which field is wrong
    END IF

    // Verify password (bcrypt, null for OAuth-only accounts)
    IF user.password_hash IS NULL THEN
        THROW HTTPError(401, "Please sign in with Google")
    END IF

    match ← bcrypt.compare(password, user.password_hash)
    IF match IS FALSE THEN
        THROW HTTPError(401, "Invalid credentials")
    END IF

    // Build JWT payload
    payload ← {
        userId: user.id,
        organizationId: user.organization_id,
        role: user.role,
        email: user.email
    }

    token ← jwt.sign(payload, env.JWT_SECRET, { expiresIn: "7d" })

    // Audit trail
    DB.insert("user_activities", {
        user_id: user.id,
        type: "AUTH",
        action: "LOGIN",
        title: "User logged in"
    })
    DB.update("users SET last_login = NOW() WHERE id = ?", [user.id])

    RETURN { accessToken: token, user: { id, full_name, email, role } }
END FUNCTION

// Fastify onRequest hook — protects routes
FUNCTION authenticate(request, reply) RETURNS Void

    TRY
        authHeader ← request.headers["authorization"]
        IF authHeader IS NULL OR NOT authHeader.STARTS_WITH("Bearer ") THEN
            THROW Error("Missing token")
        END IF

        token ← authHeader.REPLACE("Bearer ", "").TRIM()
        decoded ← jwt.verify(token, env.JWT_SECRET)

        request.user ← {
            userId: decoded.userId,
            organizationId: decoded.organizationId,
            role: decoded.role,
            email: decoded.email
        }
    CATCH error
        reply.status(401).send({ error: "Unauthorized" })
        RETURN
    END TRY
END FUNCTION

// Role permission check
FUNCTION hasPermission(userRole: String, requiredRole: String) RETURNS Boolean

    roleHierarchy ← {
        "Clerk":         1,
        "Paralegal":     2,
        "Lawyer":        3,
        "Senior_Lawyer": 4,
        "Admin":         5
    }

    RETURN roleHierarchy[userRole] >= roleHierarchy[requiredRole]
END FUNCTION

// Google OAuth callback
FUNCTION handleGoogleCallback(code: String) RETURNS AuthToken

    googleProfile ← googleOAuth.exchangeCode(code)
    // google_id is the stable subject identifier

    user ← DB.queryOne(
        "SELECT * FROM users WHERE google_id = ? OR email = ?",
        [googleProfile.sub, googleProfile.email]
    )

    IF user IS NULL THEN
        // Auto-register: try to find org by email domain
        domain ← googleProfile.email.SPLIT("@")[1]
        org ← DB.queryOne("SELECT * FROM organizations WHERE email_domain = ?", [domain])
        IF org IS NULL THEN
            org ← DB.insert("organizations", { name: googleProfile.name, ... })
        END IF

        user ← DB.insert("users", {
            organization_id: org.id,
            email: googleProfile.email,
            full_name: googleProfile.name,
            google_id: googleProfile.sub,
            is_oauth_user: TRUE,
            role: "Lawyer"
        })
    ELSE IF user.google_id IS NULL THEN
        // Link existing account to Google
        DB.update("users SET google_id = ?, is_oauth_user = TRUE WHERE id = ?",
                  [googleProfile.sub, user.id])
    END IF

    token ← jwt.sign({ userId: user.id, organizationId: user.organization_id,
                        role: user.role, email: user.email },
                       env.JWT_SECRET, { expiresIn: "7d" })

    RETURN { accessToken: token, user: { id, full_name, email, role } }
END FUNCTION
```

---

### Algorithm 3: Regulation Monitor & Version Change Detection

**Pseudocode:**

```pseudocode
// POST /api/regulations/monitor/run  (also runs on schedule)
FUNCTION runRegulationMonitor(dryRun: Boolean, triggeredBy: UUID) RETURNS MonitorRunResult

    runRecord ← DB.insert("regulation_monitor_runs", {
        started_at: NOW(),
        status: "running",
        trigger_source: triggeredBy IS NULL ? "scheduler" : "manual",
        triggered_by_user_id: triggeredBy,
        dry_run: dryRun
    })

    subscriptions ← DB.query(
        "SELECT DISTINCT regulation_id, source_url FROM regulation_subscriptions
         WHERE is_active = TRUE AND next_check_at <= NOW()"
    )

    scanned ← 0
    changed ← 0
    failed ← 0

    FOR EACH sub IN subscriptions DO
        TRY
            scanned ← scanned + 1

            // Step 1: Fetch remote content with conditional GET
            httpResponse ← http.get(sub.source_url, headers: {
                "If-None-Match": sub.last_etag,
                "If-Modified-Since": sub.last_modified
            })

            IF httpResponse.status = 304 THEN
                // Not modified — update next check, skip
                updateNextCheck(sub)
                CONTINUE
            END IF

            rawHtml ← httpResponse.body
            currentHash ← sha256(rawHtml)

            // Step 2: Compare content hash
            IF currentHash = sub.last_content_hash THEN
                updateNextCheck(sub)
                CONTINUE
            END IF

            changed ← changed + 1

            IF NOT dryRun THEN
                // Step 3: Create new regulation version
                lastVersion ← DB.queryOne(
                    "SELECT MAX(version_number) FROM regulation_versions
                     WHERE regulation_id = ?", [sub.regulation_id]
                )
                nextVersion ← (lastVersion?.version_number ?? 0) + 1

                extractedContent ← aiClient.extractRegulation(rawHtml)

                newVersionId ← DB.insert("regulation_versions", {
                    regulation_id: sub.regulation_id,
                    version_number: nextVersion,
                    content: extractedContent.text,
                    content_hash: sha256(extractedContent.text),
                    raw_html: rawHtml,
                    source_metadata: httpResponse.metadata,
                    fetched_at: NOW()
                })

                // Step 4: Re-chunk and re-embed
                chunks ← chunkText(extractedContent.text, chunkSize: 512, overlap: 64)
                FOR EACH chunk IN chunks DO
                    embedding ← embeddingService.embed(chunk.content)
                    DB.upsert("regulation_chunks", {
                        regulation_id: sub.regulation_id,
                        regulation_version_id: newVersionId,
                        chunk_index: chunk.index,
                        content: chunk.content,
                        line_start: chunk.lineStart,
                        line_end: chunk.lineEnd,
                        token_count: chunk.tokenCount,
                        embedding: embedding
                    })
                END FOR

                // Step 5: Trigger insights and amendment impact async
                queueJob("regulation:insights", { regulation_id: sub.regulation_id, version_id: newVersionId })
                IF nextVersion > 1 THEN
                    queueJob("regulation:amendment-impact", {
                        regulation_id: sub.regulation_id,
                        from_version: nextVersion - 1,
                        to_version: nextVersion
                    })
                END IF

                // Step 6: Notify subscribed users
                subscribedUsers ← DB.query(
                    "SELECT DISTINCT user_id FROM regulation_subscriptions
                     WHERE regulation_id = ? AND is_active = TRUE",
                    [sub.regulation_id]
                )
                FOR EACH subscriber IN subscribedUsers DO
                    notificationService.create(subscriber.user_id, {
                        type: "regulation_update",
                        title: "Regulation Updated",
                        message: "A regulation you follow has been updated",
                        related_regulation_id: sub.regulation_id
                    })
                    websocket.emitToUser(subscriber.user_id, "regulation_updated", {
                        regulation_id: sub.regulation_id,
                        version_number: nextVersion
                    })
                END FOR

                // Step 7: Update subscription state
                DB.update("regulation_subscriptions", {
                    last_content_hash: currentHash,
                    last_etag: httpResponse.headers.etag,
                    last_modified: httpResponse.headers["last-modified"],
                    last_checked_at: NOW()
                }, WHERE: { id: sub.id })
            END IF

            updateNextCheck(sub)

        CATCH error
            failed ← failed + 1
            LOG.error("Monitor failed for", sub.regulation_id, error)
        END TRY
    END FOR

    DB.update("regulation_monitor_runs", {
        finished_at: NOW(),
        status: "completed",
        scanned, changed, failed
    }, WHERE: { id: runRecord.id })

    RETURN { scanned, changed, failed, dry_run: dryRun }
END FUNCTION

FUNCTION updateNextCheck(subscription)
    DB.update("regulation_subscriptions SET next_check_at = NOW() + INTERVAL ? hours",
              [subscription.check_interval_hours], WHERE: { id: subscription.id })
END FUNCTION
```

---

### Algorithm 4: Document RAG — Case Insights Generation

**Pseudocode:**

```pseudocode
// POST /api/documents/{docId}/insights/refresh
FUNCTION generateDocumentCaseInsights(documentId: UUID, caseId: UUID) RETURNS DocumentInsights

    // Step 1: Load document extraction
    extraction ← DB.queryOne(
        "SELECT * FROM document_extractions WHERE document_id = ?",
        [documentId]
    )

    IF extraction IS NULL OR extraction.status != "completed" THEN
        THROW Error("Document text not extracted yet")
    END IF

    IF extraction.insights_status = "processing" THEN
        RETURN { status: "processing" }   // Idempotency guard
    END IF

    // Mark as processing
    DB.update("document_extractions SET insights_status = 'processing' WHERE id = ?",
              [extraction.id])

    // Step 2: Load case context
    caseRecord ← DB.queryOne("SELECT title, description, case_type FROM cases WHERE id = ?",
                              [caseId])

    caseContext ← formatContext(caseRecord)

    // Step 3: Check cache (hash of text + case context)
    cacheHash ← sha256(extraction.normalized_text_hash + sha256(caseContext))
    IF extraction.insights_case_context_hash = cacheHash THEN
        RETURN buildInsightsFromCache(extraction)
    END IF

    // Step 4: Chunk and embed document (if not already done)
    existingChunks ← DB.query(
        "SELECT COUNT(*) FROM document_chunks WHERE document_id = ?", [documentId]
    )

    IF existingChunks.count = 0 THEN
        chunks ← chunkText(extraction.extracted_text, chunkSize: 512, overlap: 64)
        FOR EACH chunk IN chunks DO
            embedding ← embeddingService.embed(chunk.content)
            DB.insert("document_chunks", {
                document_id: documentId,
                organization_id: caseRecord.organization_id,
                chunk_index: chunk.index,
                content: chunk.content,
                token_count: chunk.tokenCount,
                embedding: embedding
            })
        END FOR
    END IF

    // Step 5: Retrieve most relevant document chunks via pgvector
    caseEmbedding ← embeddingService.embed(caseContext)
    relevantChunks ← DB.vectorSearch(
        table: "document_chunks",
        queryVector: caseEmbedding,
        filter: { document_id: documentId },
        topK: 10
    )

    // Step 6: Call AI Microservice for insights
    insightsPayload ← {
        case_context: caseContext,
        document_chunks: relevantChunks.MAP(c → c.content),
        case_type: caseRecord.case_type
    }

    aiResponse ← aiClient.post("/documents/case-insights", insightsPayload)
    // Returns: { summary, highlights, citations }

    // Step 7: Persist insights
    DB.update("document_extractions", {
        insights_status: "completed",
        insights_summary: aiResponse.summary,
        insights_highlights_json: aiResponse.highlights,
        insights_citations_json: aiResponse.citations,
        insights_case_context_hash: cacheHash,
        insights_updated_at: NOW()
    }, WHERE: { id: extraction.id })

    RETURN {
        status: "completed",
        summary: aiResponse.summary,
        highlights: aiResponse.highlights,
        citations: aiResponse.citations
    }
END FUNCTION
```

---

### Algorithm 5: Multi-Tenant Data Isolation

**Pseudocode:**

```pseudocode
// All Fastify route handlers enforce this pattern

FUNCTION getCases(request, reply)

    // User context is injected by authenticate() hook
    userId ← request.user.userId
    organizationId ← request.user.organizationId
    role ← request.user.role

    // Parse query filters (all optional)
    filters ← {
        case_type: request.query.case_type,
        status: request.query.status,
        assigned_lawyer_id: request.query.assigned_to,
        search: request.query.search,
        page: request.query.page ?? 1,
        page_size: request.query.page_size ?? 20
    }

    // Build scoped query — organization_id is ALWAYS injected
    query ← "SELECT * FROM cases WHERE organization_id = ?"
    params ← [organizationId]

    // Role-based visibility refinement
    IF role = "Lawyer" OR role = "Paralegal" THEN
        // Non-senior staff only see cases assigned to them
        query ← query + " AND assigned_lawyer_id = ?"
        params.APPEND(userId)
    END IF
    // Senior_Lawyer and Admin see all org cases (no additional filter)

    // Apply optional filters
    IF filters.case_type IS NOT NULL THEN
        query ← query + " AND case_type = ?"
        params.APPEND(filters.case_type)
    END IF

    IF filters.status IS NOT NULL THEN
        query ← query + " AND status = ?"
        params.APPEND(filters.status)
    END IF

    IF filters.search IS NOT NULL THEN
        query ← query + " AND (title ILIKE ? OR description ILIKE ?)"
        pattern ← "%" + filters.search + "%"
        params.APPEND(pattern, pattern)
    END IF

    // Pagination
    offset ← (filters.page - 1) × filters.page_size
    query ← query + " ORDER BY created_at DESC LIMIT ? OFFSET ?"
    params.APPEND(filters.page_size, offset)

    cases ← DB.query(query, params)
    total ← DB.queryOne("SELECT COUNT(*) FROM cases WHERE organization_id = ?",
                         [organizationId]).count

    reply.send({
        data: cases,
        pagination: {
            page: filters.page,
            page_size: filters.page_size,
            total: total,
            total_pages: CEIL(total / filters.page_size)
        }
    })
END FUNCTION

// The same pattern is applied for: clients, documents, notifications,
// user_activities, ai_settings, regulation_subscriptions, invoices, etc.
// Regulations are global (shared across all organizations).
```

---

## 6. Alternative Designs

### Section 6.1: System Architecture Alternatives

#### Alternative 1: Monolithic Architecture (Rejected)

**Description**: Single Node.js application bundling frontend (SSR), backend API, and AI logic in one codebase.

**Pros**:
- Single deployment artifact
- No inter-service network latency
- Simpler local development setup

**Cons**:
- Python ML libraries (sentence-transformers, cross-encoders) cannot coexist natively with Node.js — requires subprocess bridging which adds complexity and fragility
- AI model upgrades (e.g., swapping BGE-M3 for a newer model) require full application redeployment
- Cannot scale AI compute independently of API throughput
- Single point of failure: a crash in the embedding loop takes down the API

**Justification for Rejection**: The AI pipeline is the most compute-intensive component and requires Python. A monolith would force Python-in-Node bridging (e.g., child_process or gRPC to Python) which gives none of the simplicity benefits of a true monolith.

---

#### Alternative 2: Full Microservices with Async Message Queue (Considered)

**Description**: Fine-grained microservices (separate services for auth, cases, regulations, notifications, AI, billing) communicating asynchronously via RabbitMQ or Kafka.

**Pros**:
- Each service is independently deployable and scalable
- Natural fit for event-driven workflows (regulation monitor → notification → re-embedding)
- Resilient to individual service failures (queue buffers requests)

**Cons**:
- Significant operational complexity for a 5-person graduation project
- Distributed tracing and debugging requires additional tooling (Jaeger, Zipkin)
- Event schema versioning and dead-letter queue management add overhead
- Cold-start latency for AI service calls is acceptable; async queuing adds unneeded response delay for user-facing suggestion generation

**Justification**: The current 4-service architecture (Backend API, AI Microservice, Frontend, DB) captures the main scalability benefit (AI vs API scaling) without queue complexity. Internal async operations (regulation monitoring, chunk re-embedding) are implemented as background jobs within the backend service. Message queues can be introduced when the user base demands it.

---

#### Alternative 3: Server-Side Rendering only (No Separate Backend) (Rejected)

**Description**: Use Next.js API routes and Server Actions as the sole backend, eliminating the Fastify service.

**Pros**:
- Reduced infrastructure (one Node.js process)
- Type-sharing between frontend and "backend" trivially
- Vercel deployment is straightforward

**Cons**:
- Socket.IO does not work well in Next.js serverless/edge runtime
- Cannot share Fastify's plugin ecosystem (JWT, multipart, rate-limit, Swagger)
- Database connection pooling is problematic in serverless functions
- Cannot support Flutter mobile app without a dedicated REST API
- API documentation (Swagger at /docs) would be unavailable

**Justification for Rejection**: The platform must serve both a web frontend and a Flutter mobile app via the same REST API. The Socket.IO real-time requirement and multi-client nature make a dedicated Fastify backend necessary.

---

### Section 6.2: Database Design Alternatives

#### Alternative 1: MongoDB Document Store (Rejected)

**Description**: Use MongoDB as the primary database, storing cases, regulations, and users as BSON documents.

**Pros**:
- Flexible schema allows evolving regulation structures
- Natural JSON storage for `client_info` and `source_metadata` fields
- Horizontal sharding is more mature

**Cons**:
- Cannot run pgvector-style ANN (Approximate Nearest Neighbor) queries natively; would require a separate vector DB (Qdrant, Pinecone)
- Weaker ACID guarantees across documents (multi-document transactions possible but more complex)
- Complex multi-collection JOIN equivalents (aggregation pipelines)
- Legal data requires strong consistency and auditable transactions

**Justification for Rejection**: The regulation chunk embedding search (pgvector) is central to the AI pipeline. PostgreSQL with pgvector provides relational integrity and vector search in a single engine. MongoDB would require an additional vector database, adding operational overhead.

---

#### Alternative 2: Separate Vector Database (Qdrant / Pinecone) (Considered)

**Description**: Keep PostgreSQL for relational data, but store embeddings in a dedicated vector database like Qdrant or Pinecone for ANN search.

**Pros**:
- Dedicated vector DBs offer HNSW indexing with faster ANN queries at scale
- Qdrant supports filtering on payload attributes (category, jurisdiction)
- Pinecone is fully managed (no infrastructure)

**Cons**:
- Additional infrastructure to maintain and keep synchronized with PostgreSQL
- Data consistency challenges: if a regulation chunk is deleted in PG but not Qdrant, stale matches appear
- Adds network hop for every embedding query
- pgvector with `ivfflat` or `hnsw` index is sufficient for the expected regulation corpus size (~10,000 chunks)

**Justification**: For the current scale, pgvector with HNSW index is sufficient and eliminates the synchronization problem. Qdrant can be introduced if the corpus grows beyond 100k chunks or query latency becomes a bottleneck.

---

#### Alternative 3: Redis as Primary Notification Store (Rejected)

**Description**: Use Redis Pub/Sub and Redis Streams to deliver notifications instead of PostgreSQL + Socket.IO.

**Pros**:
- Very low latency for real-time notification delivery
- Built-in Pub/Sub semantics
- Can serve as a session store simultaneously

**Cons**:
- Redis is volatile; unread notifications are lost on restart unless persisted (AOF/RDB), adding configuration complexity
- Notification history and unread count queries become harder than simple SQL
- PostgreSQL already stores notifications persistently; Socket.IO handles delivery; the combination is sufficient

**Justification for Rejection**: The current pattern (PostgreSQL for persistence + Socket.IO for delivery) requires no extra infrastructure and handles both real-time delivery and historical queries in one database.

---

### Section 6.3: AI Algorithm Alternatives

#### Alternative 1: Keyword / BM25 Search (Rejected)

**Description**: Use TF-IDF or BM25 ranking on a PostgreSQL full-text search index (`tsvector`) to match case text against regulations.

**Pros**:
- Extremely fast (< 10ms for 10k regulations)
- No GPU/CPU-intensive model loading
- Fully transparent and explainable

**Cons**:
- Fails on synonyms and paraphrases: "dismissal" ≠ "termination" in BM25
- Poor Arabic morphology handling (Arabic has complex root-based inflection)
- No cross-language matching (Arabic case → Arabic/English regulation)
- Legal language is dense with formal terminology that differs from colloquial usage

**Justification for Rejection**: Semantic embedding models capture legal synonym relationships that are critical for accurate regulation matching. BM25 alone would produce too many false negatives.

---

#### Alternative 2: Pure Cross-Encoder Ranking (Rejected)

**Description**: For each case, run a BERT-based cross-encoder on every `(case, regulation)` pair to score relevance.

**Pros**:
- Higher accuracy than bi-encoder retrieval alone
- Full attention between case and regulation text

**Cons**:
- O(N) cross-encoder inferences per case query; with 1,000 regulations × 10 chunks = 10,000 inferences
- At ~50ms per pair on CPU, that is 500 seconds per query — completely unusable
- Even with GPU, cross-encoder-only is prohibitive without a retrieval stage first

**Justification**: Cross-encoders are used as a **reranking stage** on the top-N results from the dense retrieval stage — this is the current design. Running cross-encoders from scratch on the full corpus is infeasible.

---

#### Alternative 3: Pure LLM / RAG (GPT-4 / Claude) (Future Consideration)

**Description**: Send case text to a frontier LLM with regulation excerpts as context (RAG), and ask it to identify relevant regulations and explain why.

**Pros**:
- Best reasoning quality — can handle complex multi-hop legal logic
- Produces human-readable explanations ("Article 12 applies because...")
- Can handle ambiguous or incomplete case descriptions

**Cons**:
- Sending case descriptions to external APIs (OpenAI, Anthropic) raises data privacy and Saudi data sovereignty concerns
- High cost at scale: ~$0.03/1k tokens × 5,000 tokens per query = $0.15 per case analysis
- Rate limits affect throughput for busy law firms
- Response latency: 3–10 seconds per query

**Current Approach**: The Gemini verification stage (Stage 6) is an optional LLM step applied only to the top few candidates after bi-encoder + cross-encoder narrowing. This limits token usage and latency while still adding LLM reasoning for high-value candidates. Full RAG can be introduced as a premium tier feature.

---

#### Alternative 4: Agentic Retrieval vs Single-Pass (Design Decision)

**Description**: Instead of a single-pass retrieval, use an agent that iteratively reformulates queries and retrieves additional context until confident.

**Pros**:
- Can recover from initially poor query formulations
- Better for ambiguous or short case descriptions

**Cons**:
- Non-deterministic number of LLM/embedding calls → variable latency
- Harder to debug and explain to end users
- Can loop if termination condition is misconfigured

**Current Status**: Agentic retrieval (`agentic_retrieval_enabled`) is implemented as an optional feature flag in `ai_settings` and in `agentic_retriever.py`. It is disabled by default. Organizations can enable it for cases where single-pass retrieval returns low-confidence results (configurable via `min_final_score` threshold).

---

### Section 6.4: Authentication Alternatives

#### Alternative 1: Session-Based Authentication (Rejected)

**Description**: Server-side sessions stored in PostgreSQL or Redis, session ID passed as a cookie.

**Pros**:
- Immediate session revocation (delete from store)
- No token expiry management on the client

**Cons**:
- Requires a session store; adds infrastructure dependency (Redis) or DB load
- CORS complications for cross-origin mobile app requests (Flutter)
- Does not scale horizontally without sticky sessions or shared store

**Justification for Rejection**: JWT tokens are stateless and work seamlessly with the Flutter mobile client and WebSocket authentication (token passed in `handshake.query.token`). A separate session store adds complexity without clear benefit at current scale.

---

#### Alternative 2: OAuth Only (No Local Passwords) (Considered)

**Description**: Remove local email/password authentication entirely; require Google OAuth for all users.

**Pros**:
- Eliminates password management complexity
- Delegates security hardening to Google
- Forces 2FA if the user's Google account has it

**Cons**:
- Saudi law firms may be prohibited from or reluctant to use Google accounts for confidential legal work
- Users without a Google account cannot access the system
- Organization IT policies may block Google SSO

**Justification**: Both local email/password and Google OAuth are supported. OAuth is available as a convenience option; local credentials remain the default for compliance-sensitive organizations.

---

### Section 6.5: Frontend Architecture Alternatives

#### Alternative 1: Single Page Application (CRA/Vite + REST) (Rejected)

**Description**: Pure client-side React app without Next.js, served from a CDN.

**Pros**:
- Simpler build pipeline
- No server required for frontend

**Cons**:
- No server-side rendering (SEO not relevant, but initial load is slower)
- App Router pattern provides a clean layout hierarchy for the multi-level dashboard (dashboard → cases → case detail)
- Next.js 14 image optimization and built-in i18n routing simplify bilingual (AR/EN) support

**Justification for Rejection**: Next.js App Router provides superior layout nesting (shared sidebars, headers) and built-in tooling for the bilingual dashboard.

---

#### Alternative 2: Flutter for Web as Primary Frontend (Rejected)

**Description**: Use the Flutter web target as the web dashboard instead of Next.js.

**Pros**:
- Single codebase for mobile and web
- Consistent UI across platforms

**Cons**:
- Flutter web produces large JS bundles (multi-MB)
- Worse SEO and accessibility than HTML-rendered React
- RTL (Arabic) support in Flutter is more limited than CSS-native RTL in Next.js
- Slower initial load; browser support for certain Flutter web features varies

**Justification for Rejection**: The web dashboard serves power users (lawyers, paralegals) who need a rich, responsive data interface. Next.js with shadcn/ui and Tailwind CSS provides better RTL support, faster load times, and a more familiar web experience.

---

## Summary of Design Choices

| Aspect | Chosen Design | Key Justification |
|--------|--------------|-------------------|
| Architecture | 4-service coarse microservices | Technology independence (Python AI, Node.js API) + independent scaling |
| API communication | REST + Socket.IO WebSocket | Standard REST for CRUD; WebSocket for real-time events |
| Database | PostgreSQL + pgvector | ACID compliance + native vector ANN search in one engine |
| Multi-tenancy | Shared DB, `organization_id` scoped queries + role-based visibility | Cost-effective; clear data isolation; no complex schema partitioning |
| Vector embeddings | BAAI/bge-m3 (1024-dim, multilingual) | State-of-the-art Arabic+English retrieval; local inference (no API cost/privacy risk) |
| Reranking | BAAI/bge-reranker-v2-m3 (cross-encoder) | Higher precision than bi-encoder alone; applied to top-N only (performance safe) |
| LLM verification | Google Gemini (optional, per-org toggle) | Adds reasoning layer; opt-in limits cost and latency impact |
| AI feature flags | `ai_settings` table per org | Per-organization control without code changes; progressive capability rollout |
| Authentication | JWT + Google OAuth 2.0 | Stateless tokens for mobile + web; OAuth for user convenience |
| Real-time | Socket.IO (org and user rooms) | Bidirectional; works through NAT/proxies; room-based targeting |
| File storage | Local filesystem, 10MB limit | Simple for v1; path designed for S3 migration (file_path column is URL-compatible) |
| Regulation sourcing | MOJ/Najiz sync + hash-based versioning | Canonical government source; SHA-256 content hash prevents duplicate versions |
| Billing | Internal subscription model | Custom tiers (free / professional / enterprise); Stripe-compatible schema |
| Deployment | Docker containers (per service) | Environment consistency; independent restarts; ready for Kubernetes migration |

---

## How to Use This Document

### For Diagram Generation:
1. Copy the prompt for each diagram section
2. Use diagram tools: **Lucidchart**, **draw.io**, **Mermaid.js** (for code-based diagrams), **PlantUML**
3. For ER diagrams: **dbdiagram.io** or **dbml**
4. For sequence/activity/state diagrams: **PlantUML** or **StarUML**
5. Adjust prompts as needed based on output quality

### For Academic Documentation:
1. Section 1 → "System Architecture" chapter
2. Section 2 → "Database Design" chapter (ER diagram + data dictionary)
3. Section 3 → "Modular Decomposition / Class Diagram" chapter
4. Section 4 → "System Organization / Interaction Diagrams" chapter
5. Section 5 → "Algorithms" chapter (pseudocode)
6. Section 6 → "Alternative Designs & Justifications" chapter

### Recommended Diagram Tools:

| Diagram Type | Tool |
|-------------|------|
| Architecture overview | draw.io, Lucidchart, C4 Model (Structurizr) |
| ER / Database | dbdiagram.io, ERDPlus, Mermaid `erDiagram` |
| Class diagram (UML) | StarUML, Visual Paradigm, PlantUML |
| Sequence diagram | PlantUML, Mermaid `sequenceDiagram` |
| Activity diagram | draw.io, PlantUML |
| State diagram | PlantUML, Mermaid `stateDiagram-v2` |
| DFD | draw.io, Lucidchart |

---

**Project**: Silah (صلة) — AI-Powered Legal Case Management Platform for Saudi Legal Practitioners
**Version**: 2.0
**Date**: 2026-03-28
**Status**: Reflects current codebase (Backend v5.6+, AI Microservice with multi-stage pipeline, Next.js 14 frontend)
