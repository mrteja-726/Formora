# Formora Coding Standards

## Conventional Commits
All commits must follow the conventional commit format:
`<type>[optional scope]: <description>`

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `docs`: Documentation only changes
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools and libraries

Examples:
- `feat(auth): add JWT login`
- `fix(upload): resolve file validation issue`
- `docs(api): update endpoint specs`

## Testing Coverage
- **Minimum Acceptable Coverage**: 80%
- **Target Coverage**: 90%+

## Formatting & Linting
### Frontend (Flutter)
- Tooling: `flutter_lints`, `custom_lint`, `riverpod_lint`
- Rules: Single quotes, always use package imports, avoid print, no public member API docs required.
- Commands:
  - `flutter analyze`
  - `dart format .`

### Backend (NestJS)
- Tooling: ESLint + Prettier + Husky + lint-staged
- Prettier Config: Single quotes, trailing comma 'all', print width 100, semicolons required.
