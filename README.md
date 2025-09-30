# Sprintosaurus

<img src="public/sunset.png" alt="Sunset" width="80" align="right">

> [!IMPORTANT]  
> Sprintosaurus is sunsetting on Sept 30th, 2025. This README will help you self-host it if you still need it.

Sprintosaurus is a Ruby/Sinatra web application that generates comprehensive sprint reports for GitHub Projects. It integrates with the GitHub API to fetch project data, track issues across sprints with point estimates, and provides reporting capabilities including CSV exports and visual charts.

## Features

- **Sprint Tracking**: Monitor GitHub Project iterations with start dates and durations
- **Issue Management**: Track issues, points, status changes across sprints
- **Soft Deletion**: Issues can be moved between sprints with full audit trail
- **Visual Reports**: Charts showing sprint progress and completion
- **CSV Export**: Download sprint data for external analysis
- **Real-time Sync**: Background job continuously syncs with GitHub
- **Responsive Design**: Works on desktop and mobile devices

## Architecture

### Core Components

- **Web Application** (`app.rb`): Sinatra-based web server with ActionView helpers
- **Background Job** (`job.rb`): Continuous GitHub API synchronization
- **Models**: ActiveRecord models for Projects, Sprints, Issues, and relationships
- **GitHub Integration** (`lib/github/project.rb`): GraphQL API client with rate limiting

### Database Schema

- `projects`: GitHub project containers (number, title, URL)
- `sprints`: Time-boxed iterations (start_date, duration, iteration_id)
- `issues`: GitHub issues (points, status, sprint associations)
- `issues_sprints`: Join table with soft deletion using `removed_at` pattern

## Deployment on Fly.io

### Prerequisites

1. **Fly.io CLI**: Install from https://fly.io/docs/hands-on/install-flyctl/
2. **GitHub Personal Access Token**: Classic token with these scopes:
   - `repo` (Full control of private repositories)
   - `read:org` (Read org and team membership)
   - `read:project` (Read access to projects)

### Step 1: Clone and Setup

```bash
git clone https://github.com/ericboehs/sprintosaurus-sinatra.git
cd sprintosaurus-sinatra
```

### Step 2: Configure Fly Application

```bash
# Login to Fly.io
fly auth login

# Create a new Fly application
fly apps create your-sprintosaurus-app

# Update fly.toml with your app name
```

Edit `fly.toml`:
```toml
app = "your-sprintosaurus-app"  # Change this to your app name

[build]
  dockerfile = "./Dockerfile"

[experimental]
  allowed_public_ports = [9292]
  auto_rollback = true

[processes]
  web = "bundle exec rackup config.ru -o 0.0.0.0"
  job = "ruby job.rb"

[[services]]
  processes = ["web"]
  internal_port = 9292
  protocol = "tcp"

  [[services.ports]]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

  [[services.tcp_checks]]
    interval = 10000
    timeout = 2000
    grace_period = "5s"
    restart_limit = 0
```

### Step 3: Set Up PostgreSQL Database

```bash
# Create a PostgreSQL database
fly postgres create --name your-sprintosaurus-db --region ord

# Attach database to your app
fly postgres attach --app your-sprintosaurus-app your-sprintosaurus-db
```

### Step 4: Configure Environment Variables

```bash
# Set GitHub token (REQUIRED)
fly secrets set GH_TOKEN=your_github_personal_access_token

# Set initial project URLs to sync (OPTIONAL)
# Format: comma-separated GitHub project URLs
fly secrets set SEED_GH_PROJECT_URLS="https://github.com/orgs/your-org/projects/123,https://github.com/orgs/your-org/projects/456"

# Production environment
fly secrets set RACK_ENV=production

# Redirect all routes to sunset page (OPTIONAL - for service retirement)
fly secrets set SUNSET=true

# Show sunset banner (OPTIONAL - defaults to false for self-hosting)
fly secrets set SHOW_SUNSET_BANNER=true
```

### Step 5: Deploy

```bash
# Deploy the application
fly deploy

# Check deployment status
fly status

# View logs
fly logs
```

### Step 6: Run Database Migrations

```bash
# SSH into your app instance
fly ssh console

# Run migrations
dbmate up

# Exit SSH session
exit
```

## Local Development

### Prerequisites

- Ruby 3.3+
- PostgreSQL
- dbmate (database migration tool)
- Tailwind CSS standalone binary

### Setup

```bash
# Install dependencies
bundle install

# Install dbmate (if not already installed)
# Download from: https://github.com/amacneil/dbmate/releases
# Or install via your package manager, e.g.: brew install dbmate

# Set up environment variables
cp .env.local.example .env.local
# Edit .env.local with your values

# Create database
createdb sprintosaurus_development
createdb sprintosaurus_test

# Run migrations
dbmate up

# Install Tailwind CSS standalone binary (if not already installed)
# Download from: https://github.com/tailwindlabs/tailwindcss/releases
# Or install via your package manager, e.g.: brew install tailwindcss

# Build Tailwind CSS
tailwindcss -i input.css -o public/tailwind.css --config tailwind.config.js

# Start development server
bundle exec rerun 'rackup config.ru -o 0.0.0.0'

# In another terminal, start background job
ruby job.rb
```

### Environment Variables

Create `.env.local` with:

```bash
# Database connections
DATABASE_URL="postgres://localhost/sprintosaurus_development?sslmode=disable"
TEST_DATABASE_URL="postgres://localhost/sprintosaurus_test?sslmode=disable"

# GitHub integration (REQUIRED)
GH_TOKEN="your_github_personal_access_token"

# Initial projects to sync (OPTIONAL)
SEED_GH_PROJECT_URLS="https://github.com/orgs/your-org/projects/123"

# Development settings (OPTIONAL)
RACK_ENV="development"
ENABLE_CSP="false"
DEBUG="false"

# Redirect all routes to sunset page (OPTIONAL - for service retirement)
SUNSET="false"

# Sunset banner (OPTIONAL - set to "true" to show the banner)
SHOW_SUNSET_BANNER="false"
```

### Running Tests

```bash
# Run all tests
ruby test/job_test.rb

# Run with minitest
bundle exec ruby -Itest test/job_test.rb
```

## GitHub Setup

### Creating a Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select these scopes:
   - `repo` - Full control of private repositories
   - `read:org` - Read org and team membership
   - `read:project` - Read access to projects
4. Copy the token and use it as `GH_TOKEN`

### Project Requirements

Your GitHub Projects must have:

- **Sprint/Iteration field**: Used to track sprint iterations
- **Points/Estimate field**: Used for story point tracking (optional)
- **Status field**: Used for issue status tracking (optional)

The application automatically detects these field names and adapts to your project structure.

## Adding Projects

### Via Environment Variable

Set `SEED_GH_PROJECT_URLS` with comma-separated project URLs:

```bash
fly secrets set SEED_GH_PROJECT_URLS="https://github.com/orgs/my-org/projects/123"
```

### Via Web Interface

1. Navigate to your deployed application
2. Click "Add Project"
3. Enter the GitHub project URL
4. The background job will automatically sync the project

## Monitoring and Maintenance

### Logs

```bash
# View application logs
fly logs

# Follow logs in real-time
fly logs -f

# Filter by process
fly logs --app your-app-name job
```

### Updates

```bash
# Deploy new version
git pull origin main
fly deploy

# Check deployment
fly status
```

## Security Considerations

### Content Security Policy

When `ENABLE_CSP=true`, the application enforces strict CSP headers:

- Only self-hosted resources allowed
- Nonces required for inline scripts/styles
- HTTPS upgrade enforced in production

This is the default for production but is useful for testing locally.

### Environment Variables

- Never commit `.env.local` or actual tokens to version control
- Use Fly secrets for sensitive data
- Rotate GitHub tokens periodically

### Database Security

- Database is encrypted at rest on Fly.io
- Use SSL connections in production
- Regular backups are handled by Fly Postgres

## Troubleshooting

### Common Issues

**Database Connection Errors**
```bash
# Check database status
fly postgres list

# View database logs
fly logs --app your-db-name
```

**GitHub API Rate Limits**
- The application automatically handles rate limits
- Monitor logs for rate limit messages
- Consider using multiple tokens for high-volume usage

**Build Failures**
```bash
# Check build logs
fly logs --app your-app-name

# Rebuild from scratch
fly deploy --no-cache
```

**Background Job Not Running**
```bash
# Check process status
fly status

# View job logs specifically
fly logs job
```

### Performance Optimization

- Background job runs every 10 minutes by default
- Adjust sync frequency in `job.rb` if needed
- Use database indexing for large datasets
- Monitor memory usage and scale accordingly

## License

MIT License - see LICENSE file for details.

## Support

This project is being sunset and will not receive active support after September 30th, 2025. This README provides comprehensive self-hosting instructions. For issues specific to self-hosting, please open a GitHub issue.
