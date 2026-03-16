# ARCHITECTURE.md

**System:** Customer Risk API  
**Version:** 1.0  
**Classification:** Training Demo System  
**Status:** Pre-implementation — architecture decisions locked, pending Phase 2

---

## 1. Problem Framing

### What This System Solves

Internal operations staff currently query a Postgres database directly using ad-hoc SQL to retrieve customer risk tier information. This creates three compounding problems: direct database access bypasses access controls; queries are inconsistent and error-prone; and there is no auditable, structured interface for downstream tools to consume risk data reliably.

This system solves that by placing a thin, authenticated API service in front of the database. Operations staff query by customer ID through a browser UI or programmatic HTTP call and receive a structured response containing the customer's risk tier and the factors that drove the assessment. The database becomes an implementation detail rather than the interface.

### What This System Does Not Solve

- **Risk computation.** The system does not calculate or update risk assessments. It reads pre-populated values. Any business logic that determines a customer's tier lives entirely outside this system.
- **Data freshness.** There is no mechanism within this system for updating risk profiles. How assessed values enter or change in the database is out of scope.
- **User identity.** Authentication is API key-based with a single shared key. The system cannot identify which individual made a given request.
- **Production hardening.** TLS, rate limiting, secrets management at scale, and high-availability concerns are explicitly out of scope.
- **Write operations.** There are no endpoints that create, update, or delete records.

---

## 2. Five Key Design Decisions

---

### Decision 1: Single FastAPI container serves both the API and the UI

**What was decided**  
The FastAPI application is responsible for two things: handling API requests at `/api/...` routes and serving the HTML/JS UI as a static file at `/`. Both responsibilities live in the same Python process inside the same Docker container.

**Rationale**  
The system is small, read-only, and internally scoped. Combining the UI and API in one service eliminates inter-container networking, removes CORS configuration requirements, and ensures a single `docker compose up` produces a fully working system with no additional coordination. The operational surface area is minimised.

**Alternatives considered**  
- A three-container split: Postgres, FastAPI API, and an Nginx static file server for the UI.
- A two-container split with FastAPI serving the API and a separate lightweight server for the UI.

**Why those alternatives were rejected**  
Both alternatives introduce a third or second application container that needs to be networked, configured, and kept in sync with the API. They also surface the API key problem: the UI would need to call the API from the browser, meaning the key would have to live in client-side JavaScript — either hardcoded in source or entered manually each session. Neither is acceptable for a production-adjacent demo system. The single-container approach avoids this entirely because the UI and API share the same origin.

---

### Decision 2: API key authentication via a single shared key in the request header

**What was decided**  
All API endpoints require a valid API key passed as a request header (`X-API-Key`). The key is defined in the `.env` file and loaded by the FastAPI service at startup. There is one key for the system. Requests without a valid key receive a `401 Unauthorized` response.

**Rationale**  
The requirements mandate authentication on all endpoints. A single shared key is the simplest mechanism that satisfies this constraint given that user identity management is explicitly out of scope. It also allows the UI to use the key without the user being prompted to enter credentials on every session, since the key can be injected into the served HTML at render time rather than exposed in static source files.

**Alternatives considered**  
- Per-user API keys issued to each member of operations staff.
- HTTP Basic Auth with a shared username and password.
- No authentication (relying on network-level access controls alone).

**Why those alternatives were rejected**  
Per-user keys require user management infrastructure, which is explicitly out of scope. HTTP Basic Auth is semantically equivalent to a shared key for this use case but is less idiomatic for API authentication and less straightforward to handle in JavaScript fetch calls. No authentication was rejected because it directly violates a stated functional requirement and undermines the stated purpose of replacing uncontrolled database access.

---

### Decision 3: psycopg2 for database access with no ORM

**What was decided**  
All database queries are written as explicit SQL strings executed via psycopg2. No ORM (SQLAlchemy, Tortoise, etc.) is used at any layer of the application.

**Rationale**  
This is a fixed constraint in the requirements brief. Beyond compliance, it is appropriate for this system: the data model is simple, the system is read-only, and there are a small number of queries. Raw SQL is readable, explicit, and introduces no abstraction overhead for a system of this size. It also keeps the dependency surface minimal.

**Alternatives considered**  
- SQLAlchemy Core (expression layer without ORM).
- SQLAlchemy ORM.
- An async database library (databases, asyncpg).

**Why those alternatives were rejected**  
SQLAlchemy in any form is excluded by the stated constraint. Async database libraries were considered briefly given FastAPI's async capabilities, but psycopg2 is synchronous and the requirement is explicit. Introducing async database access would require a different driver and is not warranted given the expected query volume and the system's read-only nature.

---

### Decision 4: Database seeded via Postgres init scripts at container startup

**What was decided**  
The Postgres container is initialised with a SQL script that creates the schema and inserts representative seed records covering all three risk tiers (LOW, MEDIUM, HIGH). This script runs automatically on first container start via Postgres's `/docker-entrypoint-initdb.d/` mechanism. No manual setup step is required.

**Rationale**  
The requirement states that the system must start from `docker compose up` with no manual steps beyond providing the `.env` file. Embedding the seed script in the container image and relying on Postgres's built-in init hook is the most direct way to satisfy this. It also keeps the seed data in version control alongside the application code.

**Alternatives considered**  
- A separate database migration tool (Flyway, Alembic).
- A startup script in the FastAPI container that seeds the database on first run.
- Manual database setup documented in a README.

**Why those alternatives were rejected**  
Migration tools add dependencies and configuration that are not warranted for a single-version demo system with a static schema. Seeding from the FastAPI container introduces a startup race condition: the API service must wait for Postgres to be ready before seeding, which requires retry logic or `depends_on` health checks. The Postgres init hook handles this cleanly and keeps the seeding responsibility with the database layer where it belongs. Manual setup was rejected as a direct violation of the stated constraint.

---

### Decision 5: UI served as a static HTML file by FastAPI with the API key injected at render time

**What was decided**  
The HTML/JS UI is a single file served by FastAPI at the root route (`/`). When FastAPI serves this file, it injects the configured API key into the page so that the JavaScript can include it in fetch requests to the API without requiring the user to enter it. The UI makes calls to the same service's `/api/...` routes.

**Rationale**  
The UI needs to authenticate with the API. If the key is hardcoded in the static HTML file, it is visible in source control. If it is entered by the user at runtime, it degrades the user experience and requires every operations staff member to know and manage the key. Server-side injection at render time keeps the key out of source files while making the experience seamless. Because the UI and API are the same service and origin, fetch calls require no CORS configuration.

**Alternatives considered**  
- Hardcoding the API key directly in the HTML/JS source file.
- Requiring users to enter the API key in the UI before making requests.
- Serving the UI via a separate Nginx container.

**Why those alternatives were rejected**  
Hardcoding the key in source is a security hygiene failure — it would be committed to version control and visible to anyone with repository access. Requiring user entry is a usability failure that also implies the key is being distributed to individuals, which creates a management problem. A separate Nginx container reintroduces the networking and key-exposure problems that the single-container approach resolves.

---

## 3. Challenge My Decisions

---

### Challenge 1: Combining the UI and API in one container couples unrelated responsibilities

**Strongest argument against**  
A FastAPI service is designed to be a backend API. Serving HTML from it conflates two concerns: business logic and UI delivery. If the UI ever needs to be changed — or if a second consumer of the API emerges — the coupling becomes a constraint. More practically, any UI change requires redeploying the API service, which is a poor operational boundary.

**Evaluation: Partially valid, rejected for this context**  
The argument is structurally sound in general software design terms. However, it assumes a growth trajectory that is explicitly out of scope for this system. The brief identifies this as a training demo system with no write operations and no user management. There is no second consumer on the horizon, and no deployment pipeline where redeploying a combined service is a meaningful cost. The argument would become valid if this system were to evolve into a shared service with multiple UIs or consumers — at which point the architecture should be revisited. It is not a valid objection to the current design.

---

### Challenge 2: A single shared API key does not meaningfully enforce access control

**Strongest argument against**  
The stated motivation for building this system is to replace uncontrolled database access with something that has proper access controls. A single shared key that every operations staff member uses does not achieve that. If the key leaks — through a shared document, a Slack message, or a browser's saved state — there is no way to know or respond. Rotating the key breaks all users simultaneously with no warning. The system may appear to have authentication without delivering the audit and revocation capabilities that give authentication its value.

**Evaluation: Valid, accepted as a known limitation**  
This challenge is correct and was identified during problem exploration. The decision to use a single shared key is not a claim that it is an ideal authentication model — it is a deliberate scoping choice consistent with the explicit constraint that user management is out of scope. The risk is real and is documented in Section 4. If the client intends to rely on this system for genuine access control over time, the authentication model should be the first thing revisited after the initial delivery.

---

### Challenge 3: psycopg2 is synchronous in an async FastAPI application

**Strongest argument against**  
FastAPI is built around Python's asyncio model. Using synchronous psycopg2 calls inside async route handlers blocks the event loop for the duration of each database query. Under concurrent load, this means requests queue behind each other rather than being handled concurrently. For a system designed to be queried by operations staff, this may be acceptable — but it introduces a subtle performance anti-pattern that could be misleading in a training demo context.

**Evaluation: Valid in principle, rejected for this scope**  
The concern is technically accurate. A production FastAPI application with database access should use an async-compatible driver (asyncpg) or run synchronous calls in a thread pool via `run_in_executor`. However, the requirement explicitly mandates psycopg2 with no ORM, and the system's expected concurrency is low. The correct mitigation — which should be noted in the implementation — is to run psycopg2 queries using FastAPI's `run_in_executor` pattern or to accept the blocking behaviour as a known characteristic of a low-volume internal tool. This should be documented as a deliberate trade-off in the code, not silently ignored.

---

### Challenge 4: Postgres init scripts are fragile under repeated `docker compose up` cycles

**Strongest argument against**  
Postgres only runs `/docker-entrypoint-initdb.d/` scripts when the data directory is empty — i.e. on first initialisation. If the Postgres volume persists across `docker compose down` and `docker compose up` cycles, the seed data is not re-applied. If a developer wipes the volume and restarts, they get a fresh seed. If they don't wipe the volume but have changed the seed script, the new script never runs. This creates a class of environment inconsistency that is hard to debug.

**Evaluation: Valid, mitigated by documentation**  
The challenge identifies a real behaviour of the Postgres init mechanism. The mitigation is not architectural — it is operational: the README must clearly document that `docker compose down -v` is required to reset the database to a clean seed state, and that changes to the seed script require a volume wipe to take effect. This is a known and accepted characteristic of this approach, not a reason to change it. An alternative would be to seed from the FastAPI container on every startup using an idempotent script, but that reintroduces the startup race condition problem noted in Decision 4.

---

### Challenge 5: Injecting the API key into the HTML at render time is not a robust security pattern

**Strongest argument against**  
Injecting the API key into a server-rendered HTML page means the key is transmitted to every browser that loads the UI — appearing in the page source, in browser history, and potentially in any caching layer. Anyone who opens browser DevTools and inspects the page source has the key. This is meaningfully different from the key being in a `.env` file or a server-side secret store. The injection approach feels more secure than a hardcoded static file but the practical difference is small: the key is still client-visible.

**Evaluation: Valid, accepted as the least-bad option within constraints**  
The challenge is correct. Server-side injection does not prevent a determined user from finding the key in the page source. The genuine security improvement over a hardcoded static file is limited — the key is not in version control, which matters for repository hygiene, but is still client-visible at runtime. The right solution for a system with real security requirements would be session-based authentication where the browser never holds a raw API key. That requires user management infrastructure, which is out of scope. Given the constraints, injection is the least-bad option. This should be documented clearly so the client understands the boundary of what authentication provides here.

---

## 4. Key Risks

**R1 — Data staleness undermines trust**  
The system is entirely read-only. There is no defined mechanism for updating risk profiles when assessments change. If the database diverges from the risk team's current view of customers, operations staff will encounter incorrect tier information. Over time, this erodes trust in the tool and may drive users back to ad-hoc queries — recreating the original problem. *Mitigation: the client must define and operate a data refresh process outside this system before going live.*

**R2 — The shared API key provides weak access control in practice**  
As discussed in Challenge 2, a single shared key cannot support meaningful audit, targeted revocation, or individual accountability. Once distributed, it is effectively a permanent credential. *Mitigation: treat key rotation as an operational procedure with a defined schedule; accept that individual-level audit is not achievable without extending the authentication model.*

**R3 — The system has no observability**  
There is no logging, metrics, or alerting built into the architecture. If the service fails silently — bad database connection, malformed query result, startup failure — there is no signal. Operations staff may experience unexplained errors with no recourse. *Mitigation: at minimum, structured request logging should be added to the FastAPI application before any internal deployment.*

**R4 — Single point of failure with no recovery path**  
There is one API container, one database container, and no failover. If either container crashes, the system is unavailable until manually restarted. For an internal demo system this is acceptable; for a system that operations staff depend on for time-sensitive queries, it is a gap. *Mitigation: document the restart procedure and set restart policies in Docker Compose (`restart: unless-stopped`).*

**R5 — psycopg2 blocking behaviour under concurrent load**  
As noted in Challenge 3, synchronous psycopg2 calls in async route handlers will block the event loop under concurrent requests. For very low usage this is benign. If query volume increases, response times will degrade non-linearly. *Mitigation: document the behaviour, and if concurrency becomes a concern, move psycopg2 calls to a thread pool or migrate to an async driver.*

---

## 5. Key Assumptions

**A1 — Users arrive with a customer ID**  
The system provides no search, listing, or lookup capability. It assumes operations staff already know the customer ID they want to query. If the ID must itself be looked up from another system, the workflow is incomplete.

**A2 — The seed data is representative but not real**  
The database will be seeded with fictional customer records. It is assumed that real customer PII will never be used in the seed data and that the system will not be connected to a live database without a separate design review.

**A3 — Usage volume is low**  
The system is designed for internal operations staff at a single client. Query volume is assumed to be low enough that a single FastAPI container with synchronous database access is not a bottleneck.

**A4 — The environment has Docker and Docker Compose available**  
No fallback deployment path is defined. It is assumed that the target environment can run Docker Compose and that network access to the container ports is available to operations staff.

**A5 — The `.env` file is managed securely by the operator**  
The API key and database credentials live in a `.env` file. It is assumed that the operator understands this file must not be committed to version control and is responsible for its distribution and storage.

**A6 — Risk factors are stored as structured data**  
The system is designed to return a list of risk factors alongside the tier. It is assumed that the database schema will store these as a structured field (e.g. a Postgres array or JSONB column) that can be returned without additional transformation.

---

## 6. Data Model

### `customers`

The primary entity. Represents a customer who has been assessed for risk.

| Column | Type | Description |
|---|---|---|
| `customer_id` | `VARCHAR` (PK) | The unique identifier for the customer. This is the query key for the API. |
| `name` | `VARCHAR` | The customer's display name. Returned in the API response for context. |
| `risk_tier` | `VARCHAR` | The assessed risk tier. Constrained to `LOW`, `MEDIUM`, or `HIGH`. |
| `risk_factors` | `TEXT[]` or `JSONB` | The list of factors that contributed to the assessed tier. Returned as an array in the API response. |
| `assessed_at` | `TIMESTAMP` | The timestamp of the most recent assessment. Informational — not used in query logic. |

**Notes**
- The schema is intentionally flat. There is no separate `risk_factors` table because the factors are read-only, always returned together with the tier, and do not need to be queried independently.
- `risk_tier` should be enforced with a `CHECK` constraint at the database level to prevent invalid values entering the seed data.
- The choice between `TEXT[]` and `JSONB` for `risk_factors` is an open question (see Section 7). Either is sufficient for the current requirements.

---

## 7. Open Questions

**OQ1 — What is the exact shape of a risk factor?**  
The requirements specify that risk factors should be returned but do not define their structure. Are they short machine-readable codes (`HIGH_DEBT_RATIO`), human-readable strings (`"Debt-to-income ratio exceeds threshold"`), or structured objects with a code and description? The answer affects the column type choice, the seed data design, and how useful the UI display will be to a non-technical user. *Needs client input before schema is finalised.*

**OQ2 — `TEXT[]` vs `JSONB` for risk factors**  
If risk factors are simple strings, a Postgres `TEXT[]` array is the most straightforward choice. If they are structured objects (code + label + severity), `JSONB` is more appropriate. This decision cannot be made until OQ1 is resolved.

**OQ3 — Should the API key be passed as a header or query parameter?**  
The architecture assumes a request header (`X-API-Key`), which is the conventional and safer approach (headers are not logged in most access logs, unlike query parameters). This should be confirmed before implementation to ensure consistency with any downstream tooling that may eventually call the API.

**OQ4 — What constitutes a meaningful seed dataset?**  
The requirements ask for records covering all three risk tiers. How many records are needed? Are there specific risk factor combinations that must be represented to make the demo useful? A seed dataset that is too thin will produce 404s for any realistic test and undermine confidence in the system.

**OQ5 — Is there a requirement to log API requests?**  
The original problem included a concern about bypassing access controls. A natural extension of solving that problem is capturing a record of who queried what and when. The current architecture has no logging. If audit logging is a real requirement for the client — even informally — it should be designed in now rather than retrofitted.

**OQ6 — How will the API key be distributed to operations staff?**  
The `.env` file holds the key for the service itself. But operations staff using the browser UI will receive the key injected into the page. If staff bookmark the page or share it, the key travels with it implicitly. There should be a defined answer to "how does a new staff member get access?" before the system is handed over.
