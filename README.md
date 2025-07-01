# DevDock
End-to-end DevOps pipeline with AWS, Docker, Terraform &amp; GitHub Actions

This monorepo contains the backend (Python Flask/FastAPI) and frontend (Next.js) applications for my internship project.

## Architecture Overview

* **Backend:** A simple Python REST API, dockerized and deployed to AWS ECS.
* **Frontend:** A Next.js web application, dockerized and deployed to AWS ECS, communicating with the backend.
* **Infrastructure:** Managed using Terraform on AWS (VPC, ECS, ALB, Secrets Manager, CloudWatch).
* **CI/CD:** Automated with GitHub Actions for testing, building, and deployment.

## Setup Instructions (Local Development)

### Prerequisites

* Git
* Node.js (LTS recommended) & npm
* Python 3.8+ & pip
* Docker Desktop
* AWS CLI (configured)
* Terraform

### Getting Started

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Sarang2401/DevDock.git]
    cd DevDock
    ```

2.  **Backend Setup:**
    ```bash
    cd backend
    pip install -r requirements.txt 
    python app.py 
    ```

3.  **Frontend Setup:**
    ```bash
    cd frontend
    npm install # or yarn install (if you use yarn)
    npm run dev # or yarn dev
    ```
    

## Branching Strategy (Git Flow Lite)

This project follows a simplified Git Flow model to manage development and releases.

* **`main` branch:**
    * Represents the production-ready code.
    * Only merges from `develop` are allowed (via Pull Request).
    * All deployments to the production environment are triggered from this branch.
    * Direct commits to `main` are strictly forbidden.

* **`develop` branch:**
    * Represents the latest stable development code.
    * All feature branches merge into `develop` (via Pull Request).
    * Serves as the integration branch for all new features.
    * Automated tests and Docker image builds are triggered on pushes to `develop`.

* **`feature/<feature-name>` branches:**
    * Created from `develop` for developing new features, bug fixes, or enhancements.
    * Name them descriptively (e.g., `feature/add-health-endpoint`, `feature/implement-message-api`).
    * Work on these branches, commit regularly.
    * Once complete, open a Pull Request (PR) from `feature/<feature-name>` to `develop`.

### Pull Request (PR) Workflow

1.  **Create a feature branch:** `git checkout -b feature/your-feature-name develop`
2.  **Develop your feature:** Make changes, commit frequently.
3.  **Push your feature branch:** `git push origin feature/your-feature-name`
4.  **Open a Pull Request:** Go to GitHub, select your branch, and open a PR targeting the `develop` branch.
5.  **Code Review:** Another team member (or you, practicing self-review) reviews the code for quality, correctness, and adherence to standards.
6.  **Merge:** Once approved, the PR is merged into `develop`.
7.  **Delete feature branch:** After merging, delete the feature branch.

### Release Flow

When `develop` is stable and ready for a release:

1.  A Pull Request is opened from `develop` to `main`.
2.  After review and approval, this PR is merged.
3.  Merging into `main` triggers a production deployment.
