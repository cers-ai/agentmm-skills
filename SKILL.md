# AgentMM Skill - Enhanced Version

This skill provides advanced integration with AgentMM API for intelligent agent memory operations and email sending with smart features.

## API Endpoint
https://api.agentmm.site/functions/v1/agent-api

## Authentication
Bearer Token: amm_sk_c37620f5a839416398b9364512aa8a17


## Enhanced Features

### Intelligent Memory System
- Categorized memory storage with tags
- Full-text search capabilities
- Context-aware memory retrieval
- Automatic memory expiration and cleanup
- Memory linking and relationship tracking
- Backup and export functionality

### Smart Email System
- Email templating with variable substitution
- Read receipt tracking and delivery status
- Conversation threading and grouping
- HTML email support
- Attachment handling
- Scheduled email sending
- Smart categorization and filtering

## Supported Actions

### Memory Operations
- `write_memory`: Write a memory entry with tags and metadata
- `read_memory`: Read memory entries with advanced filtering
- `search_memory`: Full-text search across memories
- `forget_memory`: Delete a memory entry
- `update_memory`: Update existing memory entry
- `list_memory_tags`: List all used tags
- `get_memory_stats`: Get memory usage statistics
- `backup_memory`: Export memories to file
- `restore_memory`: Import memories from file

### Email Operations
- `send_mail`: Send an email (plain text or HTML)
- `send_template_mail`: Send email using predefined template
- `list_mail`: List emails with advanced filtering
- `search_mail`: Search emails by content
- `get_mail_thread`: Get conversation thread
- `track_email`: Get email tracking information
- `schedule_email`: Schedule email for later sending
- `get_email_stats`: Get email usage statistics

## Usage

Each action is implemented as a script in the `scripts/` directory. You can invoke them via the `exec` tool or directly from the command line.

### Memory Scripts

#### write_memory.sh
Write a memory entry with enhanced features.

Parameters:
- `--key`: Memory key (unique identifier)
- `--content`: Memory content (string)
- `--tags`: Comma-separated tags for categorization (optional)
- `--ttl`: Time to live in seconds (optional, default: 86400 - 24 hours)
- `--context`: Context information for better retrieval (optional)
- `--related`: Related memory keys (comma-separated, optional)

Example:
```bash
./scripts/write_memory.sh \
  --key "project_x_meeting_20260315" \
  --content "Discussed Q2 roadmap, decided to prioritize feature A" \
  --tags "project,x,meeting,roadmap" \
  --context "Q2 planning session" \
  --related "project_x_backlog,project_x_stakeholders"
```

#### read_memory.sh
Read memory entries with filtering options.

Parameters:
- `--key`: Memory key to read (if omitted, returns all memories)
- `--tags`: Filter by tags (comma-separated)
- `--context-filter`: Filter by context (optional)
- `--limit`: Number of entries to return (default 100)
- `--offset`: Offset for pagination (default 0)
- `--sort`: Sort by field (created_at, updated_at, key) (default: created_at)

#### search_memory.sh
Full-text search across memories.

Parameters:
- `--query`: Search query string
- `--tags`: Filter by tags (optional)
- `--limit`: Number of results (default 50)
- `--fuzzy`: Enable fuzzy matching (default: false)

#### update_memory.sh
Update existing memory entry.

Parameters:
- `--key`: Memory key to update
- `--content`: New content (optional)
- `--tags`: New tags (optional)
- `--context`: New context (optional)
- `--add-tags`: Tags to add (optional)
- `--remove-tags`: Tags to remove (optional)

#### forget_memory.sh
Delete a memory entry.

Parameters:
- `--key`: Memory key to delete

#### list_memory_tags.sh
List all used tags with usage counts.

#### get_memory_stats.sh
Get memory usage statistics.

Parameters:
- `--days`: Number of days to look back (default: 30)

#### backup_memory.sh
Export memories to file.

Parameters:
- `--output`: Output file path (default: memories_backup_YYYYMMDD_HHMMSS.json)
- `--format`: Format (json, csv) (default: json)
- `--tags`: Filter by tags (optional)
- `--days`: Only memories from last N days (optional)

#### restore_memory.sh
Import memories from file.

Parameters:
- `--input`: Input file path
- `--merge`: Merge with existing memories (default: true)
- `--overwrite`: Overwrite existing keys (default: false)

### Email Scripts

#### send_mail.sh
Send an email.

Parameters:
- `--to`: Recipient email address
- `--subject`: Email subject
- `--body`: Email body (plain text)
- `--html`: HTML body (optional, if provided sends as HTML)
- `--cc`: CC recipients (comma-separated, optional)
- `--bcc`: BCC recipients (comma-separated, optional)
- `--reply-to`: Reply-To address (optional)
- `--attachments`: File paths to attach (comma-separated, optional)
- `--track`: Enable read tracking (default: true)

#### send_template_mail.sh
Send email using predefined template.

Parameters:
- `--template`: Template name (welcome, meeting_invite, follow_up, etc.)
- `--to`: Recipient email address
- `--vars`: Template variables as key=value pairs (comma-separated)
- `--cc`: CC recipients (optional)
- `--bcc`: BCC recipients (optional)
- `--track`: Enable read tracking (default: true)

#### list_mail.sh
List emails with advanced filtering.

Parameters:
- `--direction`: sent/received/all (default: all)
- `--limit`: Number of emails to return (default 50)
- `--offset`: Offset for pagination (default 0)
- `--search`: Search in subject/body (optional)
- `--from`: Filter by sender email (optional)
- `--to`: Filter by recipient email (optional)
- `--start-date`: Start date (YYYY-MM-DD, optional)
- `--end-date`: End date (YYYY-MM-DD, optional)
- `--has-attachments`: Filter emails with attachments (true/false)
- `--is-tracked`: Filter tracked emails (true/false)

#### search_mail.sh
Search emails by content.

Parameters:
- `--query`: Search query string
- `--direction`: sent/received/all (default: all)
- `--limit`: Number of results (default 50)
- `--fuzzy`: Enable fuzzy matching (default: false)

#### get_mail_thread.sh
Get conversation thread.

Parameters:
- `--thread-id`: Thread identifier (or use --subject to find thread)
- `--subject`: Subject to find thread for
- `--limit`: Maximum emails in thread (default 100)

#### track_email.sh
Get email tracking information.

Parameters:
- `--email-id`: Email ID to track
- `--include-events`: Include open/click events (default: true)

#### schedule_email.sh
Schedule email for later sending.

Parameters:
- `--to`: Recipient email address
- `--subject`: Email subject
- `--body`: Email body
- `--send-at`: Timestamp to send (ISO 8601 format)
- `--html`: HTML body (optional)
- `--track`: Enable read tracking (default: true)

#### get_email_stats.sh
Get email usage statistics.

Parameters:
- `--days`: Number of days to look back (default: 30)
- `--direction`: sent/received/all (default: all)

## Installation
This skill is installed via `skillhub install AgentMM` or manually copied to the skills directory.

## Notes
- All scripts require `curl` and `jq` for JSON processing.
- The API key is hardcoded in the scripts for simplicity. For production use, consider using environment variables or a secure vault.
- Templates are stored in the `templates/` directory.
- Memory backups are stored in the `backups/` directory by default.
