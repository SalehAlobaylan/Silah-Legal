# Silah-Legal Design Chapter - AI Image Generation Prompts & Pseudocode

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
Create a professional system architecture diagram for Silah-Legal, a legal case management platform.

Main components to include:
1. Client Layer:
   - Web Dashboard (Next.js/React) - laptop icon
   - Mobile App (Flutter) - smartphone icon
   - Both connecting via HTTPS/REST API

2. Application Layer:
   - Backend API Server (Node.js/Fastify) - central server icon
   - Load balancer/router
   - Authentication Service (JWT)
   - Real-time WebSocket Server (Socket.IO)

3. AI/ML Layer:
   - AI Microservice (Python/FastAPI) - AI brain icon
   - BGE-M3 Embedding Model
   - Semantic Similarity Engine

4. Data Layer:
   - PostgreSQL Database - cylinder icon
   - File Storage System (documents)
   - Redis Cache (optional)

5. External Services:
   - Najiz Portal Integration (Saudi government)
   - Email/Notification Service

Style requirements:
- Clean, modern enterprise architecture style
- Color-coded layers (blue for client, green for application, purple for AI, orange for data)
- Arrows showing data flow between components
- Labels for all components and protocols
- Professional software architecture diagram style
- Include legend for component types
- Background: white or light gray

Communication patterns to show:
- REST API calls (solid arrows)
- WebSocket connections (dashed arrows)
- Database queries (cylinder connections)
```

### Textual Explanation:

**System Architecture Overview:**

Silah-Legal employs a **microservices-based layered architecture** composed of four distinct subsystems:

1. **Presentation Layer**: Web and mobile clients providing bilingual UI
2. **Application Layer**: Core API server handling business logic
3. **Intelligence Layer**: AI microservice for semantic regulation matching
4. **Data Layer**: PostgreSQL database with multi-tenant isolation

**Communication Pattern**: The system uses a **client-server architecture** with RESTful API communication between clients and the backend, augmented with WebSocket connections for real-time updates. The backend communicates with the AI service via HTTP POST requests.

**Justification**: This architecture was selected because:
- **Scalability**: Each service can be scaled independently
- **Separation of Concerns**: AI logic is isolated, enabling easy model updates
- **Technology Diversity**: Allows optimal tech stack for each component
- **Maintainability**: Clear boundaries between services

---

## 2. Database Design

### Entity-Relationship (E/R) Diagram Prompt:

```
Create a professional Entity-Relationship diagram for Silah-Legal's database schema.

Entities to include:

1. ORGANIZATIONS (Central entity)
   - Fields: id, name, email_domain, created_at
   - Relationships: One-to-many with Users, Cases, Clients

2. USERS
   - Fields: id, organization_id, email, password_hash, role, full_name
   - Roles: Admin, Senior Lawyer, Lawyer, Paralegal, Clerk
   - Relationships: Many-to-one with Organizations

3. CLIENTS
   - Fields: id, organization_id, name, email, phone, address
   - Relationships: Many-to-one with Organizations, One-to-many with Cases

4. CASES
   - Fields: id, organization_id, client_id, title, description, case_type, status
   - Case Types: Criminal, Civil, Commercial, Labor, Family, Administrative
   - Relationships: Many-to-one with Organizations and Clients, One-to-many with Documents

5. REGULATIONS
   - Fields: id, title, content, source_url, category, effective_date, hash
   - Relationships: One-to-many with RegulationVersions

6. REGULATION_VERSIONS
   - Fields: id, regulation_id, content_hash, version_number, created_at
   - Relationships: Many-to-one with Regulations

7. AI_SUGGESTIONS
   - Fields: id, case_id, regulation_id, similarity_score, created_at
   - Relationships: Many-to-one with Cases and Regulations

8. DOCUMENTS
   - Fields: id, case_id, filename, file_url, file_size, uploaded_at
   - Relationships: Many-to-one with Cases

9. NOTIFICATIONS
   - Fields: id, user_id, message, is_read, created_at
   - Relationships: Many-to-one with Users

10. USER_ACTIVITIES
    - Fields: id, user_id, action, entity_type, entity_id, timestamp
    - Relationships: Many-to-one with Users

11. ACHIEVEMENTS
    - Fields: id, user_id, badge_type, earned_at
    - Relationships: Many-to-one with Users

Relationship cardinalities:
- One organization has many users (1:N)
- One organization has many cases (1:N)
- One client has many cases (1:N)
- One case has many documents (1:N)
- One case has many AI suggestions (1:N)
- One regulation has many versions (1:N)

Style requirements:
- Standard ERD notation (Chen's notation or Crow's foot)
- Entities as rectangles with rounded corners
- Relationships as diamond shapes
- Crow's foot notation for cardinality
- Primary keys underlined
- Foreign keys marked with (FK)
- Color-coded by entity type
- Professional database diagram style
```

### Data Dictionary Structure:

```pseudocode
STRUCTURE DataDictionary:

    ENTITY Organization:
        id: UUID (Primary Key)
        name: VARCHAR(255) - "Organization name"
        email_domain: VARCHAR(100) - "Email domain for users"
        created_at: TIMESTAMP - "Creation timestamp"

    ENTITY User:
        id: UUID (Primary Key)
        organization_id: UUID (Foreign Key → Organization.id)
        email: VARCHAR(255) UNIQUE - "User email address"
        password_hash: VARCHAR(255) - "Bcrypt hashed password"
        role: ENUM - "Admin | Senior_Lawyer | Lawyer | Paralegal | Clerk"
        full_name: VARCHAR(255) - "User full name"
        created_at: TIMESTAMP - "Account creation date"

    ENTITY Client:
        id: UUID (Primary Key)
        organization_id: UUID (Foreign Key → Organization.id)
        name: VARCHAR(255) - "Client name"
        email: VARCHAR(255) - "Client email"
        phone: VARCHAR(50) - "Contact phone number"
        address: TEXT - "Physical address"
        created_at: TIMESTAMP

    ENTITY Case:
        id: UUID (Primary Key)
        organization_id: UUID (Foreign Key → Organization.id)
        client_id: UUID (Foreign Key → Client.id)
        title: VARCHAR(255) - "Case title"
        description: TEXT - "Detailed case description"
        case_type: ENUM - "Criminal | Civil | Commercial | Labor | Family | Administrative"
        status: ENUM - "Open | In_Progress | Closed | Archived"
        created_at: TIMESTAMP

    ENTITY Regulation:
        id: UUID (Primary Key)
        title: VARCHAR(500) - "Regulation title"
        content: TEXT - "Full regulation text"
        source_url: VARCHAR(500) - "Official source URL"
        category: VARCHAR(100) - "Legal category"
        effective_date: DATE - "Effective from date"
        hash: VARCHAR(64) - "SHA-256 hash for versioning"
        created_at: TIMESTAMP

    ENTITY AI_Suggestion:
        id: UUID (Primary Key)
        case_id: UUID (Foreign Key → Case.id)
        regulation_id: UUID (Foreign Key → Regulation.id)
        similarity_score: DECIMAL(3,4) - "0.0000 to 1.0000"
        created_at: TIMESTAMP

    ENTITY Document:
        id: UUID (Primary Key)
        case_id: UUID (Foreign Key → Case.id)
        filename: VARCHAR(255) - "Original filename"
        file_url: VARCHAR(500) - "Storage path/URL"
        file_size: INTEGER - "Size in bytes"
        mime_type: VARCHAR(100) - "File MIME type"
        uploaded_at: TIMESTAMP
        uploaded_by: UUID (Foreign Key → User.id)
```

---

## 3. Modular Decomposition

### Class Diagram Prompt (Object-Oriented):

```
Create a professional UML Class Diagram for Silah-Legal's core modules.

Classes to include:

1. AUTHENTICATION MODULE:
   Class: AuthService
   + login(email: String, password: String): JWTToken
   + register(userData: UserDTO): User
   + verifyToken(token: String): Boolean
   + hashPassword(password: String): String

2. CASE MANAGEMENT MODULE:
   Class: CaseService
   + createCase(caseData: CaseDTO): Case
   + updateCase(id: UUID, data: CaseDTO): Case
   + getCaseById(id: UUID): Case
   + listCases(filters: CaseFilters): Case[]
   + deleteCase(id: UUID): Boolean

   Class: Case
   - id: UUID
   - title: String
   - description: String
   - caseType: CaseType
   - status: CaseStatus
   + addDocument(doc: Document): void
   + assignLawyer(lawyer: User): void

3. AI INTEGRATION MODULE:
   Class: AIService
   + findRelatedRegulations(caseText: String): RegulationSuggestion[]
   + calculateSimilarity(text1: String, text2: String): Float
   + generateEmbedding(text: String): Vector

   Class: EmbeddingModel
   - modelName: String
   + encode(text: String): Float[]
   + batchEncode(texts: String[]): Float[][]

4. CLIENT MANAGEMENT MODULE:
   Class: ClientService
   + createClient(clientData: ClientDTO): Client
   + updateClient(id: UUID, data: ClientDTO): Client
   + getClientCases(id: UUID): Case[]

5. NOTIFICATION MODULE:
   Class: NotificationService
   + sendNotification(userId: UUID, message: String): void
   + broadcastToOrganization(orgId: UUID, message: String): void
   + markAsRead(notificationId: UUID): void

   Class: WebSocketGateway
   - connectedClients: Map<UUID, Socket>
   + handleConnection(socket: Socket): void
   + handleDisconnection(socket: Socket): void
   + emitEvent(userId: UUID, event: String, data: Any): void

6. DOCUMENT MANAGEMENT MODULE:
   Class: DocumentService
   + uploadFile(caseId: UUID, file: File): Document
   + deleteDocument(id: UUID): Boolean
   + downloadDocument(id: UUID): FileStream

Relationships to show:
- Composition: Case contains Documents
- Association: CaseService uses AIService
- Dependency: AuthService is used by all services
- Aggregation: Client has multiple Cases

Style requirements:
- Standard UML class diagram notation
- Three sections per class (name, attributes, methods)
- Visibility indicators (+ public, - private, # protected)
- Proper relationship arrows
- Color-coded by module
- Clean, professional academic style
```

### Data Flow/Pipeline Model Prompt:

```
Create a Data Flow Diagram (DFD) showing the AI regulation linking pipeline.

Process flow:

INPUT: User creates/updates a case with description text

PROCESS 1: Case Data Normalization
- Extract case description
- Identify case type and keywords
- Clean and tokenize text

PROCESS 2: Embedding Generation (AI Service)
- Convert case text to vector embedding
- Load regulation embeddings from database
- Model: BGE-M3 multilingual encoder

PROCESS 3: Similarity Calculation
- Calculate cosine similarity between case vector and all regulation vectors
- Score range: 0.0 (no match) to 1.0 (perfect match)
- Sort regulations by similarity score

PROCESS 4: Filtering & Ranking
- Filter results below threshold (e.g., score < 0.5)
- Apply case type filters
- Return top N results (default: 10)

OUTPUT: Ranked list of relevant regulations with scores

Style requirements:
- Level 0 DFD (context diagram) showing main system
- Level 1 DFD showing subprocess breakdown
- Data stores: Regulations Database, Embeddings Cache
- External entities: User, Najiz Portal
- Arrows showing data flow direction
- Circle symbols for processes
- Parallel lines for data stores
- Rectangle for external entities
```

---

## 4. System Organization

### Sequence Diagram Prompt (AI Suggestion Flow):

```
Create a UML Sequence Diagram for the "Generate AI Suggestions" use case.

Actors/Objects:
1. User (Lawyer)
2. Frontend Dashboard
3. Backend API (CaseController)
4. AIService Client
5. AI Microservice (Python)
6. PostgreSQL Database

Message flow:

User → Frontend: Click "Generate AI Suggestions" button
Frontend → Backend: POST /api/cases/{id}/ai-suggestions
Backend → Database: Query case details by ID
Database → Backend: Return case data (title, description, type)

Backend → AIService: POST /similarity/find-related
Request body: { "text": "case description...", "caseType": "Criminal" }

AIService → Database: Query all regulations with embeddings
Database → AIService: Return regulations with pre-computed vectors

AIService → AI Model: Generate embedding for case text
AI Model → AIService: Return case embedding vector

[Processing Loop for each regulation]
AIService → AIService: Calculate cosine similarity
  similarity = dot(caseVector, regVector) / (norm(caseVector) * norm(regVector))
AIService → AIService: Sort by score descending
AIService → AIService: Filter scores < 0.5
[End Loop]

AIService → Backend: Return top 10 suggestions with scores
Response: [
  { regulationId, title, similarityScore: 0.87, excerpt },
  ...
]

Backend → Database: Store suggestions in ai_suggestions table
Database → Backend: Confirm storage

Backend → Frontend: Return suggestions
Frontend → User: Display ranked regulation list with match percentages

Style requirements:
- Standard UML sequence diagram notation
- Vertical lifelines for each object
- Horizontal arrows for messages (solid for synchronous, dashed for return)
- Activation bars showing processing time
- Numbered message sequence
- Loop fragment for similarity calculations
- Color-code: Blue for client, Green for backend, Purple for AI service
- Professional academic style
```

### Activity Diagram Prompt (User Registration Flow):

```
Create a UML Activity Diagram for the User Registration process.

Start → [User accesses registration page]

Decision: Is user from existing organization?
  - YES → Query organization by email domain
  - NO → Create new organization first

[Organization Check]
↓
[Validate email format]
↓
[Check if email already exists]
↓
Decision: Email exists?
  - YES → Display error "Email already registered" → End
  - NO → Continue

[Collect user information]
  - Full name
  - Email
  - Password (min 4 characters)
  - Role selection
↓
[Hash password using bcrypt]
↓
[Create user record in database]
↓
[Generate JWT token]
↓
[Send welcome email]
↓
[Create default notifications]
↓
[Log user activity]
↓
End: Redirect to dashboard

Style requirements:
- UML activity diagram notation
- Rounded rectangles for actions
- Diamonds for decisions
- Solid arrow for flow
- Fork/join for parallel processes (if any)
- Swimlanes: User, Frontend, Backend, Database
- Color-coded actions by layer
- Professional diagram style
```

### State Diagram Prompt (Case Lifecycle):

```
Create a UML State Diagram showing the states and transitions of a Case object.

States:
1. [Draft]
   - Entry: Initialize case with creation date
   - Exit: Validate required fields

2. [Open]
   - Entry: Assign case number
   - Do: Allow document uploads

3. [In Progress]
   - Entry: Assign primary lawyer
   - Do: Track billable hours

4. [Under Review]
   - Entry: Submit for senior lawyer review
   - Do: Await approval

5. [Closed]
   - Entry: Record closing date
   - Exit: Archive documents

6. [Archived]
   - Entry: Move to cold storage

Transitions:
Draft → Open: "Submit" [when all required fields complete]
Open → In Progress: "Start Work" [when lawyer assigned]
Open → Archived: "Delete" [by admin only]
In Progress → Under Review: "Request Review" [by lawyer]
Under Review → In Progress: "Reject" [feedback provided]
Under Review → Closed: "Approve" [by senior lawyer]
Closed → Open: "Reopen" [if new evidence found]

Events:
- addDocument()
- assignLawyer()
- updateStatus()
- addAISuggestions()

Style requirements:
- UML state diagram notation
- Rounded rectangles for states
- Solid arrows for transitions
- Labels with trigger events [guard conditions]
- Initial state (filled circle)
- Final state (bullseye circle)
- Internal actions (entry/do/exit)
- Color-coded by status type
```

---

## 5. Algorithms

### Algorithm 1: AI Regulation Matching (Semantic Similarity)

**Pseudocode:**

```pseudocode
// Main algorithm for finding related regulations
FUNCTION findRelatedRegulations(caseText: String, caseType: String, topN: Integer = 10)
    RETURNS Array<RegulationSuggestion>

    // Step 1: Preprocess input text
    cleanedText ← preprocessText(caseText)

    // Step 2: Generate embedding for case text using AI model
    caseEmbedding ← generateEmbedding(cleanedText)

    // Step 3: Retrieve all regulations from database
    allRegulations ← database.query("SELECT * FROM regulations")

    // Step 4: Calculate similarity for each regulation
    suggestions ← EMPTY_ARRAY

    FOR EACH regulation IN allRegulations

        // Skip if regulation embedding not available
        IF regulation.embedding IS NULL THEN
            CONTINUE
        END IF

        // Optional: Filter by case type if specified
        IF caseType IS NOT NULL AND regulation.category != caseType THEN
            CONTINUE
        END IF

        // Calculate cosine similarity
        similarityScore ← cosineSimilarity(
            caseEmbedding,
            regulation.embedding
        )

        // Add to suggestions if above threshold
        IF similarityScore >= 0.5 THEN
            suggestions.APPEND({
                regulationId: regulation.id,
                title: regulation.title,
                category: regulation.category,
                similarityScore: similarityScore,
                excerpt: extractExcerpt(regulation.content, 150)
            })
        END IF
    END FOR

    // Step 5: Sort by similarity score (descending)
    suggestions.SORT(DESCENDING BY similarityScore)

    // Step 6: Return top N results
    RETURN suggestions[0:topN]
END FUNCTION

// Helper: Cosine similarity calculation
FUNCTION cosineSimilarity(vectorA: Float[], vectorB: Float[])
    RETURNS Float

    IF LENGTH(vectorA) != LENGTH(vectorB) THEN
        THROW Error("Vector dimensions must match")
    END IF

    dotProduct ← 0.0
    normA ← 0.0
    normB ← 0.0

    FOR i FROM 0 TO LENGTH(vectorA) - 1 DO
        dotProduct ← dotProduct + (vectorA[i] * vectorB[i])
        normA ← normA + (vectorA[i] * vectorA[i])
        normB ← normB + (vectorB[i] * vectorB[i])
    END FOR

    normA ← SQRT(normA)
    normB ← SQRT(normB)

    IF normA = 0 OR normB = 0 THEN
        RETURN 0.0
    END IF

    RETURN dotProduct / (normA * normB)
END FUNCTION

// Helper: Text preprocessing
FUNCTION preprocessText(text: String)
    RETURNS String

    // Convert to lowercase
    cleaned ← text.TO_LOWERCASE()

    // Remove extra whitespace
    cleaned ← cleaned.TRIM()
    cleaned ← cleaned.REPLACE(/\s+/, " ")

    // Remove special characters (optional, depends on model)
    // cleaned ← cleaned.REPLACE(/[^\w\s\u0600-\u06FF]/, "")

    RETURN cleaned
END FUNCTION

// Helper: Extract text excerpt
FUNCTION extractExcerpt(content: String, maxLength: Integer)
    RETURNS String

    IF LENGTH(content) <= maxLength THEN
        RETURN content
    END IF

    RETURN content.SUBSTRING(0, maxLength) + "..."
END FUNCTION
```

### Algorithm 2: JWT Authentication & Authorization

**Pseudocode:**

```pseudocode
// Authentication: Login
FUNCTION authenticateUser(email: String, password: String)
    RETURNS AuthToken

    // Step 1: Validate input
    IF email IS EMPTY OR password IS EMPTY THEN
        THROW Error("Email and password required")
    END IF

    // Step 2: Find user by email
    user ← database.queryOne(
        "SELECT * FROM users WHERE email = ?",
        [email]
    )

    IF user IS NULL THEN
        THROW Error("Invalid credentials")
    END IF

    // Step 3: Verify password
    passwordMatch ← bcrypt.compare(password, user.password_hash)

    IF passwordMatch IS FALSE THEN
        THROW Error("Invalid credentials")
    END IF

    // Step 4: Check if user is active
    IF user.is_active = FALSE THEN
        THROW Error("Account is disabled")
    END IF

    // Step 5: Generate JWT token
    tokenPayload ← {
        userId: user.id,
        organizationId: user.organization_id,
        role: user.role,
        email: user.email
    }

    accessToken ← jwt.sign(tokenPayload, SECRET_KEY, {
        expiresIn: "7 days"
    })

    // Step 6: Log login activity
    logUserActivity(user.id, "LOGIN")

    RETURN {
        accessToken: accessToken,
        user: {
            id: user.id,
            name: user.full_name,
            email: user.email,
            role: user.role
        }
    }
END FUNCTION

// Authorization: Verify token and check permissions
FUNCTION authorizeUser(token: String, requiredRole: String)
    RETURNS UserContext

    // Step 1: Verify JWT token
    TRY
        decoded ← jwt.verify(token, SECRET_KEY)
    CATCH error
        THROW Error("Invalid or expired token")
    END TRY

    // Step 2: Extract user info
    userId ← decoded.userId
    userRole ← decoded.role
    organizationId ← decoded.organizationId

    // Step 3: Check role permissions
    IF hasPermission(userRole, requiredRole) IS FALSE THEN
        THROW Error("Insufficient permissions")
    END IF

    // Step 4: Return user context
    RETURN {
        userId: userId,
        role: userRole,
        organizationId: organizationId
    }
END FUNCTION

// Helper: Role-based permission check
FUNCTION hasPermission(userRole: String, requiredRole: String)
    RETURNS Boolean

    // Role hierarchy (higher number = more permissions)
    roleHierarchy ← {
        "Clerk": 1,
        "Paralegal": 2,
        "Lawyer": 3,
        "Senior_Lawyer": 4,
        "Admin": 5
    }

    userLevel ← roleHierarchy[userRole]
    requiredLevel ← roleHierarchy[requiredRole]

    RETURN userLevel >= requiredLevel
END FUNCTION

// Middleware: Protect routes
FUNCTION protectRoute(requiredRole: String = "Lawyer")
    RETURNS MiddlewareFunction

    RETURN FUNCTION(request, response, next)
        TRY
            // Extract token from Authorization header
            authHeader ← request.headers["Authorization"]

            IF authHeader IS EMPTY THEN
                THROW Error("Authorization header required")
            END IF

            token ← authHeader.REPLACE("Bearer ", "")

            // Authorize user
            userContext ← authorizeUser(token, requiredRole)

            // Attach user context to request
            request.user ← userContext

            // Continue to next handler
            next()

        CATCH error
            response.status(401).JSON({
                error: error.message
            })
        END TRY
    END FUNCTION
END FUNCTION
```

### Algorithm 3: Multi-Tenant Data Isolation

**Pseudocode:**

```pseudocode
// Ensure all queries are scoped to user's organization
FUNCTION queryWithTenantIsolation(userId: String, queryType: String, params: Object)
    RETURNS QueryResult

    // Step 1: Get user's organization
    user ← database.queryOne(
        "SELECT organization_id FROM users WHERE id = ?",
        [userId]
    )

    organizationId ← user.organization_id

    // Step 2: Inject organization filter into query
    SWITCH queryType

        CASE "GET_CASES"
            baseQuery ← "SELECT * FROM cases WHERE organization_id = ?"
            queryParams ← [organizationId]

            // Add additional filters if provided
            IF params.caseType IS NOT NULL THEN
                baseQuery ← baseQuery + " AND case_type = ?"
                queryParams.APPEND(params.caseType)
            END IF

            IF params.status IS NOT NULL THEN
                baseQuery ← baseQuery + " AND status = ?"
                queryParams.APPEND(params.status)
            END IF

            RETURN database.query(baseQuery, queryParams)

        CASE "GET_CLIENTS"
            RETURN database.query(
                "SELECT * FROM clients WHERE organization_id = ?",
                [organizationId]
            )

        CASE "GET_REGULATIONS"
            // Regulations are shared across all organizations
            RETURN database.query("SELECT * FROM regulations")

        CASE "CREATE_CASE"
            // Automatically inject organization_id
            params.organization_id ← organizationId
            RETURN database.insert("cases", params)

        DEFAULT
            THROW Error("Unknown query type")
    END SWITCH
END FUNCTION

// Middleware: Auto-inject organization filter
FUNCTION tenantIsolationMiddleware(request, response, next)

    userContext ← request.user
    organizationId ← userContext.organizationId

    // Override query methods to auto-filter
    originalQuery ← database.query

    database.query ← FUNCTION(sql, params)
        // Check if query is for a tenant-specific table
        IF sql.CONTAINS("cases") OR
           sql.CONTAINS("clients") OR
           sql.CONTAINS("users") THEN

            // Inject organization filter if not present
            IF sql.CONTAINS("organization_id") IS FALSE THEN
                sql ← sql.REPLACE("WHERE", "WHERE organization_id = ? AND")
                params.INSERT(0, organizationId)
            END IF
        END IF

        RETURN originalQuery(sql, params)
    END FUNCTION

    next()
END FUNCTION
```

### Algorithm 4: Regulation Versioning (Hash-based Change Detection)

**Pseudocode:**

```pseudocode
// Monitor regulations for changes and create versions
FUNCTION monitorRegulationChanges()

    regulations ← database.query(
        "SELECT id, content FROM regulations"
    )

    FOR EACH regulation IN regulations DO

        // Step 1: Calculate current content hash
        currentHash ← sha256Hash(regulation.content)

        // Step 2: Get last stored hash
        lastVersion ← database.queryOne(
            "SELECT content_hash FROM regulation_versions
             WHERE regulation_id = ?
             ORDER BY created_at DESC
             LIMIT 1",
            [regulation.id]
        )

        // Step 3: Compare hashes
        IF lastVersion IS NULL THEN
            // First version - create initial version record
            createRegulationVersion(
                regulation.id,
                regulation.content,
                currentHash,
                1
            )

        ELSE IF lastVersion.content_hash != currentHash THEN
            // Content changed - create new version
            versionNumber ← lastVersion.version_number + 1

            createRegulationVersion(
                regulation.id,
                regulation.content,
                currentHash,
                versionNumber
            )

            // Notify subscribed users about change
            notifyRegulationUpdate(regulation.id, versionNumber)
        END IF
    END FOR
END FUNCTION

// Helper: Create regulation version record
FUNCTION createRegulationVersion(
    regulationId: String,
    content: String,
    contentHash: String,
    versionNumber: Integer
)

    database.insert("regulation_versions", {
        regulation_id: regulationId,
        content: content,
        content_hash: contentHash,
        version_number: versionNumber,
        created_at: CURRENT_TIMESTAMP()
    })

    // Update main regulation record with new hash
    database.update(
        "regulations",
        { id: regulationId },
        { hash: contentHash }
    )
END FUNCTION

// Helper: SHA-256 hash calculation
FUNCTION sha256Hash(text: String)
    RETURNS String

    // Convert text to bytes
    bytes ← text.ENCODE("UTF-8")

    // Calculate SHA-256 hash
    hash ← crypto.sha256(bytes)

    // Convert to hexadecimal string
    RETURN hash.TO_HEX()
END FUNCTION
```

---

## 6. Alternative Designs/Methods

### Section 6.1: System Architecture Alternatives

#### Alternative 1: Monolithic Architecture (Rejected)

**Description**: Single application containing all functionality (frontend, backend, AI) in one codebase.

**Pros**:
- Simpler deployment (single artifact)
- Easier local development
- No network latency between components
- Simpler debugging

**Cons**:
- Difficult to scale individual components
- Technology locked to single stack
- AI model updates require full redeployment
- Single point of failure
- Harder to maintain as codebase grows

**Justification for Rejection**: Silah-Legal needs to support multilingual AI processing which requires Python, while the web platform uses Node.js/TypeScript. A monolith would force technology compromises.

#### Alternative 2: Serverless/Microservices with Message Queue (Considered)

**Description**: Fine-grained microservices with async messaging (RabbitMQ/Kafka) for inter-service communication.

**Pros**:
- Maximum scalability
- Independent deployment
- Natural fit for event-driven workflows
- Cost-effective with pay-per-use

**Cons**:
- Increased operational complexity
- Debugging distributed systems
- Cold start latency
- Overkill for current scale

**Justification**: Current project scale doesn't warrant the complexity. Adopted a middle ground: **coarse-grained microservices** (4 services) with synchronous HTTP communication, which can evolve to event-driven if needed.

#### Alternative 3: Service-Oriented Architecture (SOA) with ESB (Rejected)

**Description**: Enterprise Service Bus as central communication layer with services exposed via SOAP/WS-* standards.

**Pros**:
- Standardized communication
- Centralized monitoring
- Enterprise-grade features

**Cons**:
- ESB becomes bottleneck and single point of failure
- Heavyweight XML-based protocols
- Complex to implement and maintain
- Slower performance

**Justification for Rejection**: Modern REST/JSON APIs are simpler, faster, and better suited for web/mobile clients. No need for enterprise middleware at this scale.

### Section 6.2: Database Design Alternatives

#### Alternative 1: NoSQL Document Store (MongoDB) (Considered)

**Description**: Use MongoDB for flexible schema-less storage.

**Pros**:
- Flexible schema for evolving regulations
- Natural JSON document storage
- Horizontal scaling easier

**Cons**:
- No ACID guarantees across documents
- Complex transactions
- Less mature tooling for complex queries
- Weaker data integrity

**Justification for Rejection**: Legal data requires strong consistency, ACID transactions, and complex relational queries (e.g., cases with clients, documents, suggestions). PostgreSQL provides reliability needed for legal compliance.

#### Alternative 2: Multi-Database Approach (Polyglot Persistence) (Considered)

**Description**: PostgreSQL for transactional data, Elasticsearch for full-text search, Redis for caching.

**Pros**:
- Optimal database for each use case
- Fast full-text search
- Improved performance

**Cons**:
- Increased operational complexity
- Data synchronization challenges
- Multiple backup strategies
- Higher learning curve

**Justification**: For v1.0, PostgreSQL's built-in full-text search and JSONB capabilities are sufficient. Can add Elasticsearch later if search performance becomes bottleneck.

### Section 6.3: AI/ML Algorithm Alternatives

#### Alternative 1: Keyword-Based Search (Rejected)

**Description**: Traditional TF-IDF or BM25 keyword matching.

**Pros**:
- Simple to implement
- Fast execution
- Explainable results

**Cons**:
- Doesn't understand semantic meaning
- Fails with synonyms
- Poor with Arabic morphology
- No cross-language matching

**Justification for Rejection**: Legal texts require semantic understanding (e.g., "termination" ≈ "dismissal" ≈ "فصل"). Embedding models capture these semantic relationships.

#### Alternative 2: Cross-Encoders (Considered)

**Description**: BERT-based cross-encoder that processes [case, regulation] pairs together.

**Pros**:
- Higher accuracy than bi-encoders
- Better at capturing interactions

**Cons**:
- Very slow (must re-encode for each pair)
- Not suitable for large regulation databases
- Expensive at inference time

**Justification for Rejection**: With ~1000+ regulations, cross-encoder would take seconds. Bi-encoder (current approach) pre-computes regulation embeddings, enabling ~200ms response time.

#### Alternative 3: LLM-Based (RAG) (Future Consideration)

**Description**: Use GPT/Claude to analyze case and suggest regulations.

**Pros**:
- Best semantic understanding
- Can explain reasoning
- Handles complex queries

**Cons**:
- High API costs
- Rate limits
- Privacy concerns (sending legal data externally)
- Slower response time

**Justification for Current Choice**: Bi-encoder offers best balance of accuracy, speed, cost, and privacy. Can add LLM summarization layer later if needed.

### Section 6.4: Authentication Alternatives

#### Alternative 1: Session-Based Authentication (Rejected)

**Description**: Server-side sessions with session IDs stored in cookies/database.

**Pros**:
- Can invalidate sessions immediately
- More control over authentication state

**Cons**:
- Requires session store (Redis/database)
- Doesn't scale horizontally easily
- Server memory overhead
- CORS complications

**Justification for Rejection**: JWT tokens are stateless, scale horizontally naturally, and work well with microservices architecture.

#### Alternative 2: OAuth 2.0 / OpenID Connect (Future Enhancement)

**Description**: Delegate authentication to external providers (Google, Microsoft, etc.).

**Pros**:
- No password management
- Industry standard
- Single sign-on capability

**Cons**:
- External dependency
- Users may not have accounts with providers
- Privacy concerns
- More complex implementation

**Justification**: JWT with local authentication provides self-contained system. Can add OAuth later for enterprise customers.

---

## Summary of Design Choices

| Aspect | Chosen Design | Key Justification |
|--------|--------------|-------------------|
| Architecture | Coarse-grained microservices (4 services) | Technology independence + scalability balance |
| Communication | REST API + WebSocket | Standard, simple, real-time capable |
| Database | PostgreSQL (Relational) | ACID compliance for legal data integrity |
| Multi-tenancy | Shared database, organization_id isolation | Cost-effective with clear data separation |
| AI Model | BGE-M3 bi-encoder embeddings | Multilingual, fast, accurate, privacy-friendly |
| Authentication | JWT stateless tokens | Scalable, microservices-compatible |
| File Storage | Local filesystem with size limits | Simple for v1, cloud storage later |
| Deployment | Docker containers | Consistency across environments |

---

## How to Use This Document

### For Diagram Generation:
1. Copy the prompt for each diagram
2. Use AI image generation tools (Midjourney, DALL-E, Stable Diffusion) or diagram tools (Lucidchart, draw.io, Mermaid.js)
3. Adjust prompts based on output quality

### For Documentation:
1. Include pseudocode in your "Algorithms" section
2. Use textual explanations for "System Architecture" and "Design Choices"
3. Include data dictionary in "Database Design" section
4. Add alternative designs comparison table

### Recommended Tools:
- **Diagrams**: Mermaid.js, PlantUML, Lucidchart, draw.io
- **ER Diagrams**: dbdiagram.io, ERDPlus
- **UML Diagrams**: StarUML, Visual Paradigm
- **Architecture Diagrams**: C4 Model, Structurizr

---

**Project**: Silah-Legal (صلة) - AI-Powered Legal Case Management Platform
**Version**: 1.0
**Date**: 2026-02-22
