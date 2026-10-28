# Contributing to NidanIQ

Thank you for your interest in contributing to **NidanIQ**, an open-source sovereign Digital Public Infrastructure (DPI) for predictive vector-borne disease surveillance and early warning in Nepal.

We welcome contributions from public health researchers, epidemiologists, GIS developers, mobile engineers, backend architects, and open-source contributors around the world.

---

## Code of Conduct

All contributors and maintainers are expected to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please report unacceptable behavior to `hello@shivm.com`.

---

## Architectural Principles & Constraints

When contributing to NidanIQ, please keep our core sovereign principles in mind:

1. **Zero Citizen PII**: Field surveillance records and vision scans must strictly reject citizen names, citizenship numbers (*Nagarikta*), national identity numbers (*NID*), phone numbers, or facial images.
2. **Deterministic & Verifiable**: All risk scoring formulas, larvicide dosage calculations, and audit logs must be reproducible and tamper-evident (WORM SHA-256 hash chaining).
3. **Offline-First Resilience**: Mobile clients must operate reliably without cellular connectivity in rural and mountainous terrains, syncing via local SQLite/Hive queues when reconnected.
4. **Sovereign Data Protection**: Code must adhere to the Constitution of Nepal (2072) Schedule 8 and Data Center and Cloud Service (Operation and Management) Directive, 2081.

---

## Development Setup

### 1. Prerequisites
- **Python**: 3.12 or newer
- **Flutter**: 3.24+ / Dart 3.11+
- **Node.js**: 20+ (for Citizen Portal & Video Showcase)
- **PostgreSQL**: 16 with PostGIS 3.4
- **Redis**: 7.2+

### 2. Backend & API Setup
```bash
# Clone the repository
git clone https://github.com/codexshivam/nidaniq.git
cd nidaniq

# Set up Python virtual environment
python3.12 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r backend/requirements.txt pytest pytest-asyncio httpx ruff bandit
pip install -e ./backend

# Run test suite
pytest backend/tests -q
```

### 3. Mobile Client Setup
```bash
cd flutter_app
flutter pub get
flutter test
```

### 4. Citizen Portal Setup
```bash
cd citizen_portal
npm install
npm run build
```

---

## Pre-Commit Hooks & Quality Standards

Before committing, ensure all automated security and lint checks pass:

```bash
# Run Ruff linting
ruff check backend/

# Run Bandit security static analysis
bandit -r backend/app -ll -ii

# Execute Pytest test suite
pytest backend/tests -q
```

Ensure pre-commit hooks are active in your local clone:
```bash
pre-commit install
pre-commit run --all-files
```

---

## Git Workflow & Pull Requests

1. **Fork the Repository**: Create your own fork on GitHub.
2. **Branch Naming**: Use descriptive branch names:
   - `feat/feature-name`
   - `fix/bug-description`
   - `docs/documentation-update`
3. **Commit Messages**: Follow Conventional Commits format:
   - `feat: add ST_DWithin indexing for vector traps`
   - `fix: resolve potential log injection in notification service`
   - `docs: update deployment guidelines for IDMC`
4. **Submit a PR**:
   - Ensure all automated checks (Bandit, Ruff, CodeQL, Pytest) pass.
   - Link any relevant issues or public health specifications.
   - Provide clear reproduction steps or screenshots for UI changes.

---

## License

By contributing to NidanIQ, you agree that your contributions will be licensed under the [Apache License, Version 2.0](LICENSE).
