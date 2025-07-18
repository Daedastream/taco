# TACO Project Examples

This document provides detailed examples of projects you can build with TACO, including the prompts to use and what to expect.

## Web Applications

### 1. E-Commerce Platform

**Prompt:**
```
Build a modern e-commerce platform with:
- Next.js 14 frontend with TypeScript
- Tailwind CSS for styling
- Stripe payment integration
- Admin dashboard for product management
- Customer authentication with NextAuth
- Shopping cart with localStorage persistence
- Product search and filtering
- Order tracking system
- Email notifications for orders
- Inventory management
- PostgreSQL database with Prisma ORM
- Redis for session storage
- Comprehensive test coverage
- Docker deployment ready
```

**Expected Agents:**
- Frontend Developer (Next.js/React)
- Backend Developer (API endpoints)
- Database Architect (PostgreSQL schemas)
- Payment Integration Specialist
- Admin Dashboard Developer
- QA Engineer
- DevOps Engineer

### 2. Social Media Platform

**Prompt:**
```
Create a social media platform with:
- React frontend with Material-UI
- Real-time messaging using Socket.io
- User profiles with avatar upload
- Post creation with image/video support
- Like, comment, and share functionality
- Follow/unfollow system
- Notification system
- GraphQL API with Apollo Server
- MongoDB database
- AWS S3 for media storage
- JWT authentication
- Content moderation features
- Mobile-responsive design
- Comprehensive testing suite
```

### 3. Project Management Tool

**Prompt:**
```
Build a project management application like Trello with:
- Vue.js 3 frontend with Composition API
- Drag-and-drop kanban boards
- Team collaboration features
- Task assignments and due dates
- File attachments
- Comments and activity feed
- Email notifications
- REST API with Express.js
- PostgreSQL with TypeORM
- Real-time updates using WebSockets
- Role-based access control
- Time tracking
- Gantt charts
- Export to PDF/Excel
- Full test coverage
```

## API Services

### 1. RESTful Microservice

**Prompt:**
```
Create a microservices architecture for a banking system with:
- Account service (Node.js/Express)
- Transaction service (Python/FastAPI)
- Authentication service (Go/Gin)
- Notification service (Node.js)
- API Gateway using Kong
- Service discovery with Consul
- Message queue with RabbitMQ
- PostgreSQL for accounts
- MongoDB for transactions
- Redis for caching
- Comprehensive API documentation
- Rate limiting
- Circuit breakers
- Distributed tracing
- Unit and integration tests
```

### 2. GraphQL API

**Prompt:**
```
Build a GraphQL API for a learning management system with:
- Apollo Server with TypeScript
- Course management (CRUD operations)
- Student enrollment system
- Progress tracking
- Quiz and assignment handling
- Video streaming endpoints
- File upload capabilities
- PostgreSQL database
- Redis caching layer
- DataLoader for N+1 query prevention
- Subscription support for real-time updates
- Authentication with Auth0
- Role-based permissions
- Comprehensive test suite
- API documentation
```

## Mobile Applications

### 1. Cross-Platform Mobile App

**Prompt:**
```
Create a fitness tracking mobile app with:
- React Native with Expo
- TypeScript support
- User authentication
- Workout logging
- Progress charts
- Social features (share workouts)
- GPS tracking for runs
- Calorie counter
- Water intake reminder
- Push notifications
- Offline support with SQLite
- Node.js backend API
- PostgreSQL database
- Image upload for progress photos
- Integration with wearables
- Comprehensive testing
```

### 2. Native iOS/Android App

**Prompt:**
```
Build a food delivery app with:
- Flutter for iOS and Android
- Beautiful Material Design UI
- Restaurant browsing
- Menu management
- Cart functionality
- Real-time order tracking
- Payment integration (Stripe/PayPal)
- Driver app component
- Restaurant dashboard
- Push notifications
- Maps integration
- Review and rating system
- Node.js backend
- MongoDB database
- Redis for real-time features
- Full test coverage
```

## Full-Stack Applications

### 1. SaaS Application

**Prompt:**
```
Create a complete SaaS application for email marketing with:
- Next.js frontend with TypeScript
- Multi-tenant architecture
- Subscription billing with Stripe
- Email campaign builder (drag-drop)
- Contact list management
- Email templates
- Analytics dashboard
- A/B testing features
- API for integrations
- Webhook support
- PostgreSQL database
- Redis queue for email sending
- AWS SES integration
- Admin panel
- Comprehensive documentation
- Full test suite
```

### 2. Real-Time Collaboration Tool

**Prompt:**
```
Build a collaborative whiteboard application with:
- React frontend with Canvas API
- Real-time synchronization using WebRTC
- Multiple user cursors
- Drawing tools (pen, shapes, text)
- Image and file import
- Board sharing and permissions
- Voice/video chat integration
- Recording and playback
- Express.js backend
- Socket.io for real-time features
- MongoDB for persistence
- Redis for session management
- Docker deployment
- Comprehensive tests
```

## Data-Intensive Applications

### 1. Analytics Dashboard

**Prompt:**
```
Create a business intelligence dashboard with:
- React frontend with D3.js/Chart.js
- Customizable widgets
- Real-time data updates
- Data source integrations (SQL, APIs)
- Report generation (PDF/Excel)
- Scheduled reports
- User access control
- Python backend with FastAPI
- Apache Spark for data processing
- PostgreSQL data warehouse
- Redis for caching
- Elasticsearch for search
- Time-series data support
- Comprehensive testing
```

### 2. Machine Learning Platform

**Prompt:**
```
Build an ML model deployment platform with:
- React frontend with Material-UI
- Model upload and versioning
- Training job management
- Real-time inference API
- Model performance monitoring
- A/B testing for models
- Python backend with Flask
- Kubernetes for orchestration
- PostgreSQL for metadata
- S3 for model storage
- Redis for caching
- Prometheus monitoring
- GraphQL API
- Comprehensive test coverage
```

## Tips for Writing Effective Prompts

1. **Be Specific**: Include specific technologies, frameworks, and features
2. **Include Testing**: Always mention "comprehensive test coverage" or similar
3. **Consider Scale**: Mention if you need specific performance characteristics
4. **Architecture Details**: Specify if you want microservices, monolith, etc.
5. **Deployment Target**: Mention Docker, Kubernetes, or cloud platforms
6. **Security Requirements**: Include authentication, authorization needs
7. **Data Requirements**: Specify databases and data patterns
8. **Integration Needs**: List third-party services to integrate

## Using Example Files

Save any of these examples to a file and run:

```bash
# Save example to file
cat > my-project.txt << 'EOF'
[paste your selected example here]
EOF

# Run TACO
taco -f my-project.txt
```

## Custom Templates

You can create your own templates by combining:
- Frontend framework (React, Vue, Angular, etc.)
- Backend technology (Node.js, Python, Go, etc.)
- Database (PostgreSQL, MongoDB, MySQL, etc.)
- Additional services (Redis, Elasticsearch, etc.)
- Features specific to your domain
- Testing requirements
- Deployment specifications

Remember: The more detailed your prompt, the better TACO can orchestrate your agents!