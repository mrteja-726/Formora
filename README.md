# Formora

Formora is an AI-powered form automation platform that allows users to upload documents and automatically fill forms across mobile, desktop, and browser environments.

## Architecture
- **Frontend**: Flutter (Android, iOS, Windows, macOS, Linux, Web) with Riverpod and GoRouter.
- **Backend**: Node.js & NestJS with Prisma and PostgreSQL.
- **Infrastructure**: Docker & Docker Compose.

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Node.js (v20+)
- Flutter SDK (v3.19+)

### Running the Project Locally

#### Backend
1. Navigate to the backend directory: `cd backend`
2. Start the infrastructure (PostgreSQL & Redis): `docker-compose up -d`
3. Install dependencies: `npm install`
4. Setup environment variables: `cp ../.env.development .env`
5. Run migrations: `npx prisma migrate dev`
6. Start the development server: `npm run start:dev`

#### Frontend
1. Navigate to the frontend directory: `cd frontend`
2. Install dependencies: `flutter pub get`
3. Run the application: `flutter run`

## Documentation
- [Coding Standards](./docs/CODING_STANDARDS.md)

## CI/CD
This repository is configured with a GitHub Actions workflow to run code formatting, linting, testing, and generic Docker builds on every PR and push to the main branch.
