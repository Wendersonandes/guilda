<!-- RAILS DEVELOPMENT RULES GUIDELINES START -->

# Rails Development Rules - The Rails Way with AI Agents
***Built for: Solo developer + AI agents, maximum joy***

## Core Philosophy
You are building a Rails 8+ application following The Rails Way™. Code should be:
- Convention over configuration
- Database-first design
- Progressive enhancement with Hotwire
- Zero-build frontend approach
- Test-driven with Minitest
- Optimized for AI agent collaboration
- Lean, readable, and maintainable

## Rails 8+ Stack Preferences
- **Authentication**: Devise
- **Background Jobs**: Solid Queue (default Rails 8)
- **Caching**: Solid Cache (database-backed, Redis when needed)
- **WebSockets**: Action Cable with Solid Cable adapter
- **Database**: PostgreSQL with Active Record
- **Frontend**: Hotwire (Turbo + Stimulus) & TailwindCSS
- **Asset Pipeline**: Propshaft (simpler, no-build approach)
- **Testing**: Minitest with fixtures (no RSpec, no factories)
- **Rich Text**: Action Text for content editing
- **File Uploads**: Active Storage with direct uploads
- **Code Quality**: Rubocop Rails Omakase - Omakase Ruby styling for Rails
- **Development Tools**: Bullet gem for N+1 detection, Annotate gem for schema docs, Hotwire Spark gem for live-reloading
- **Error Tracking**: Rails built-in error reporter

## File Organization & Naming

### Consistent Directory Structure
```
app/
├── controllers/
│   ├── concerns/
│   └── application_controller.rb
├── models/
│   ├── concerns/
│   └── application_record.rb
├── views/
│   ├── layouts/
│   ├── shared/
│   └── [resource_name]/
├── services/
├── jobs/
├── channels/
├── mailers/
└── helpers/
```

### Naming Conventions for AI Agents
- **Classes**: PascalCase, descriptive (`UserRegistrationService`, `InvoicePaymentProcessor`)
- **Files**: snake_case matching class name (`user_registration_service.rb`)
- **Methods**: snake_case, verb-first for actions (`process_payment`, `calculate_total`)
- **Variables**: snake_case, noun-first (`current_user`, `payment_amount`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_RETRY_ATTEMPTS`, `DEFAULT_CURRENCY`)

### AI Agent File Patterns
Always organize files predictably:
```
app/models/user.rb                    # Model: singular
app/controllers/users_controller.rb   # Controller: plural + _controller
app/services/user_registration.rb     # Service: domain + action
app/jobs/send_welcome_email_job.rb    # Job: action + _job
app/views/users/index.html.erb        # View: controller/action
```

### AI-Friendly Documentation
- Include purpose statement for AI comprehension
- Document key dependencies and return values
- Specify potential errors and exceptions
- Keep documentation close to code

## Models & Active Record

### Model Design Principles
- Keep models focused on data integrity and business rules
- Use schema annotations (annotate gem) for documentation
- Order model contents consistently: constants, includes, associations, validations, callbacks, scopes, methods
- Implement database constraints to match validations
- Use concerns for shared behavior across models

### Model Best Practices
- Always index foreign keys and frequently queried columns
- Use counter caches for association counts
- Implement scopes for common query patterns
- Keep callbacks minimal - prefer service objects for complex logic
- Use `dependent:` options to maintain referential integrity

### Database Design
- Design normalized schemas by default
- Use appropriate PostgreSQL data types
- Implement database-level constraints
- Create partial indexes for performance
- Document complex queries and decisions

## Controllers

### Controller Principles
- Keep controllers thin and focused on HTTP concerns
- Use before_action filters for common setup
- Follow RESTful conventions strictly
- Handle multiple response formats (HTML, Turbo Stream, JSON)
- Implement proper error handling with appropriate status codes

### Controller Patterns
- Always use strong parameters for user input
- Prefer redirect after mutations over render
- Keep business logic in models or service objects
- Use concerns for shared controller behavior
- Implement resourceful routes whenever possible

## Service Objects

### When to Use Service Objects
- Complex business logic spanning multiple models
- External API integrations
- Multi-step processes with transactions
- Operations that don't naturally fit in a model
- Background job logic that needs testing

### Service Object Principles
- Keep services focused on a single operation
- Use clear, descriptive names
- Return meaningful results (success/failure)
- Make services easy to test in isolation
- Include proper error handling

## Testing Philosophy

### The Rails Way of Testing
- Use fixtures over factories for simplicity and speed
- Write system tests for critical user flows
- Unit test models and services thoroughly
- Test controllers only for complex authorization
- Always test happy path and edge cases

### Testing Best Practices
- Keep tests fast and focused
- Use descriptive test names
- Test behavior, not implementation
- Mock external services appropriately
- Maintain high coverage without obsessing

## Background Jobs

### Job Design Principles
- Make all jobs idempotent and retryable
- Keep jobs small and focused
- Pass simple arguments (IDs, not objects)
- Design for eventual consistency
- Handle failures gracefully

### Solid Queue Configuration
- Use database-backed queuing for simplicity
- Configure workers based on priorities
- Set appropriate concurrency limits
- Monitor queue depth and latency
- Implement proper error handling

## Mailers

### Mailer Best Practices
- Keep mailers simple and focused
- Use layouts for consistent email design
- Test email delivery in development
- Implement proper error handling
- Consider delivery performance

### Email Design
- Design for email client limitations
- Provide text alternatives
- Test across email clients
- Keep templates maintainable
- Handle bounces appropriately

## Performance & Optimization

### Query Optimization
- Avoid N+1 queries with proper includes
- Use database-level operations when possible
- Implement appropriate indexes
- Profile before optimizing
- Monitor performance in production

### Caching Strategy
- Use Russian doll caching for nested content
- Implement fragment caching for expensive views
- Cache at the appropriate level
- Use cache keys that auto-expire
- Monitor cache effectiveness

## Security Best Practices

### Core Security Principles
- Always use strong parameters
- Implement proper authentication and authorization
- Sanitize user input appropriately
- Use CSRF protection for all forms
- Keep credentials in Rails credentials system

### Security Patterns
- Validate input at multiple levels
- Implement rate limiting for APIs
- Use secure headers in production
- Audit dependencies regularly
- Follow OWASP guidelines

## Error Handling

### Error Handling Strategy
- Use Rails error reporter for centralized tracking
- Implement custom error pages
- Handle exceptions at appropriate levels
- Provide meaningful error messages
- Log errors with sufficient context

### Logging Best Practices
- Use appropriate log levels
- Include structured data in logs
- Avoid logging sensitive information
- Implement request correlation IDs
- Monitor logs for patterns

## Code Style & Conventions

### Method Organization
- Order methods logically: public, protected, private
- Group related methods together
- Use descriptive method names
- Keep methods small and focused
- Document complex logic

### Rails Conventions
- Use `?` suffix for boolean methods
- Use `!` suffix for dangerous methods
- Follow Rails naming patterns strictly
- Prefer Rails helpers over custom solutions
- Keep code idiomatic to Rails

### Code Quality Tools
- Use StandardRB for consistent formatting
- Run Bullet gem to detect N+1 queries
- Keep schema annotations current
- Use pre-commit hooks for quality
- Review code for Rails best practices

## Secrets & Configuration

### Credential Management
- Use Rails credentials for all secrets
- Never commit sensitive data
- Use environment variables for non-sensitive config
- Document credential requirements
- Rotate credentials regularly

### Configuration Best Practices
- Keep configuration DRY
- Use Rails configuration patterns
- Document environment-specific settings
- Validate configuration on boot
- Handle missing configuration gracefully

## AI Agent Collaboration

### Documentation for AI Agents
- Write clear, comprehensive comments
- Use consistent patterns throughout
- Document business logic thoroughly
- Explain non-obvious decisions
- Include examples where helpful

### Predictable Patterns
- Follow Rails conventions religiously
- Use standard file organization
- Keep naming consistent
- Write explicit rather than clever code
- Maintain comprehensive test coverage

### Task Breakdown
- Reference Backlog.md task clearly
- Break complex tasks into phases
- Document dependencies between tasks
- Keep scope manageable
- Communicate progress clearly

## Development Workflow

### Project Management Integration
- The workflow supports various project management tools
- Backlog.md is the default project management tool (see BACKLOG.MD GUIDELINES section)
- Maintain consistent commit and branch naming patterns

### Local Development
- Use Rails generators appropriately
- Keep development close to production
- Use Rails console for debugging
- Implement helpful seed data
- Document setup requirements

### Git Workflow
- Follow GitHub Flow for simplicity and clarity
- Create feature branches from main/master
- Keep commits atomic and well-documented

### Code Review
- Check for Rails best practices
- Verify test coverage
- Review security implications
- Ensure performance considerations
- Validate documentation completeness

## Production Considerations

### Deployment Checklist
- Run tests before deployment
- Check migration safety
- Verify environment configuration
- Monitor deployment progress
- Have rollback plan ready

### Production Best Practices
- Use health check endpoints
- Implement proper monitoring
- Configure appropriate timeouts
- Set up error alerting
- Plan for scaling

## Final Reminders

### Always Prefer Rails Conventions
- Trust the framework's decisions
- Use built-in solutions first
- Follow established patterns
- Avoid premature optimization
- Keep solutions simple

### Code Quality Checklist
- [ ] Tests written and passing
- [ ] No N+1 queries detected
- [ ] Code follows Rails conventions
- [ ] Security considerations addressed
- [ ] Performance implications considered
- [ ] Documentation is complete
- [ ] Linear ticket referenced
- [ ] AI agents can understand the code

Remember: Rails provides everything you need. Trust the framework, follow conventions, and focus on delivering value. Write code that's a joy to work with.
<!-- RAILS DEVELOPMENT RULES GUIDELINES END -->

<!-- ACTIVITY STREAMS GUIDELINES START -->
# Activity Streams Domain
The application implements a highly customized, database-first social graph based on the Activity Streams 2.0 (AS2) format.

## Activity
Activities follow the Activity Streams standard and represent the core action in the network.
Every `Activity` has an `#author`, `#user_author` and `#owner`.
- **author:** The Actor (Profile, Group, or Site) that originated the activity.
- **user_author:** The authentication `User` logged in when the Activity was created.
- **owner:** The Actor whose timeline the activity belongs to (e.g., the wall being posted on).

### Threading & Visibility
Activities form threads via `parent`/`children` relationships. Visibility is dictated by `Audiences` (which join Activities to specific `Relations`).

## ActivityAction
A durable, per-actor action an Actor holds over an `ActivityObject` (currently `follow`). Unlike an `Activity` (a one-off event), it is a standing flag toggled via `follow!`/`unfollow!`.

## Actor
An `Actor` represents a node in the social graph.
**IMPORTANT:** The application uses Rails 8 `delegated_type :actorable` to handle polymorphism. The current subtypes are:
- `Profile` (represents an individual's social presence)
- `Group` (represents a collective entity)
- `Site` (represents the application itself)

*Note: The Devise `User` is strictly for authentication and is NOT an Actor. Users act in the network through their associated `Profile`.*

## ActivityObject
The `ActivityObject` is the target receiving actions (e.g., a Post being liked).
The application uses Rails 8 `delegated_type :objectable` for polymorphism. Subtypes include `Post`, `Profile`, and `Group`.

## Contacts and Ties (The Social Graph)
- **Contact:** An ordered pair of Actors (Sender → Receiver). It is essentially a request or connection attempt. Its `#inverse` is the opposite-direction Contact, used to tell whether a connection has been reciprocated (`#replied?`).
- **Relation:** Defines the role/type of a connection (e.g., `Follow`, `Public`, `Custom`). Uses STI (`Relation::Public`, `Relation::Follow`, etc). Relations are **positive** (real connections: Custom, Public, Follow, Owner, LocalAdmin) or **negative** (`Relation::Reject`, which records a rejection and creates no Activity).
- **Tie:** The materialization of a connection. A `Tie` joins a `Contact` with a `Relation`, officially granting the `Permissions` tied to that Relation.

## Audiences
Sharing is modeled by join records that connect content to `Relations`:
- **Audience:** joins an `Activity` to a `Relation`.
- **ActivityObjectAudience:** joins an `ActivityObject` to a `Relation`.
Each `Relation` stands for the set of Actors holding a `Tie` of that relation, so audiences define who can reach the content.

## Permissions
Authorization in the network is extremely granular and data-driven. A `Permission` is a pair of `action` (create, read, update, destroy, follow, represent) and `object` (activity, post, comment, group, member, admin, role). Permissions are attached to `Relations`; when Actor A creates a `Tie` with Actor B using a specific Relation, Actor B is granted all Permissions defined in that Relation.

Authorization decisions go through **`Actor#can?(action, object = nil, context = Site.instance)`**. `has_relation_with?` / `role?` (alias `has_role?`) are **identity checks only** — for labels and business rules (e.g. "owner cannot leave group"), never to grant/deny a resource action. `has_permission?` is a deprecated alias of `can?`.

After changing `SocialStream.available_permissions` or `SocialStream.custom_relations`, run `bin/rails permissions:sync` in every environment so existing ties pick up the new grants.

Full model, role → capability matrix and the capability checklist: see [`docs/permissions.md`](docs/permissions.md).
<!-- ACTIVITY STREAMS GUIDELINES END -->
