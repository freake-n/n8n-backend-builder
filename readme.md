# ![n8n](https://avatars.githubusercontent.com/u/45487711?s=48&v=4) n8n Backend Builder
### No-Code Backend-as-a-Service (Local & Free)

![n8n](https://img.shields.io/badge/n8n-Workflow_Engine-ff6d5a?style=flat-square&logo=n8n)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Persistence-336791?style=flat-square&logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ed?style=flat-square&logo=docker)
![JWT](https://img.shields.io/badge/JWT-Secure_Auth-000000?style=flat-square&logo=jsonwebtokens)

A production-style backend platform built entirely using **n8n**. This project demonstrates how automation workflows can be engineered to act as a **secure, observable, RESTful backend** without writing a traditional server in Node.js or Python.

---

## 🧠 Engineering Philosophy

Most n8n projects focus on simple data piping. This project treats n8n as a **Backend Orchestration Engine**, handling platform-level concerns:

* **Security:** Inputs are validated before reaching the database. Auth headers are parsed and verified against JWT signatures.
* **Scalability:** The architecture is stateless (delegating state to Postgres), allowing for future horizontal scaling.
* **Observability:** Every request (Method, IP, Duration, Status) is logged for analysis.

**Ideal For:** Demonstrating skills for Backend, Platform, and Automation Engineer roles.

---

## ⚙️ Setup Instructions

### 1. Prerequisites
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.
* [Git](https://git-scm.com/) installed.

### 2. Installation
Clone the repository and prepare the environment

---
## 1. 🚦 Rate Limiting & Security

#### Rate Limits: Configured to block IPs exceeding 60 requests per minute or 1000 requests per hour.

#### Response: Returns 429 Too Many Requests with a Retry-After header.

#### Input Validation: All endpoints validate data types and required fields before processing to prevent SQL injection and logic errors.

---

## 📈 Future Roadmap
**[ ] Redis Integration:** Move rate limiting from Postgres to Redis for higher performance.

**[ ] Swagger/OpenAPI:** Auto-generate API documentation.

**[ ] Multi-tenancy:** Add org_id context to support multiple client organizations.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

