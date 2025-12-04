# Qwen Multimodal Agent - Homelab Deployment

A fully automated containerized AI agent system using Qwen models for multimodal tasks (text, vision, voice).

## 🚀 Quick Start

```bash
# 1. Download AI models (first time only, ~15GB)
./download_models.sh

# 2. One-command deployment
./master_deploy.sh
```

That's it! The system will automatically:
- Build all required containers
- Deploy services with proper networking
- Set up health checks and monitoring
- Provide access endpoints

## 📋 Prerequisites

- Fedora 43+ with Podman installed
- At least 16GB RAM, 8GB available
- AMD GPU with ROCm support (optional, for acceleration)
- 20GB+ free disk space
- Docker Compose (for monitoring stack)

## 🏗️ Architecture

- **Agent (Qwen3-4B)**: Orchestrates queries and delegates to specialists
- **Coder (Qwen2.5-Coder-7B)**: Code generation and debugging
- **Vision (Qwen2-VL-7B)**: Image analysis and OCR
- **Voice (Qwen2-Audio-7B)**: Audio processing (experimental)
- **Router**: Intelligent query routing

## 🤖 AI Models

The system uses optimized Qwen models (Q5_K_M quantization for balance of quality/speed):

| Service | Model | Size | Purpose |
|---------|-------|------|---------|
| Agent | Qwen3-4B-Instruct | ~3GB | Query orchestration & delegation |
| Coder | Qwen2.5-Coder-7B-Instruct | ~5GB | Code generation & debugging |
| Vision | Qwen2-VL-7B-Instruct + mmproj | ~5GB + 1GB | Image analysis & OCR |
| Voice | Qwen2-Audio-7B | ~5GB | Audio transcription (experimental) |

Models are automatically downloaded during first deployment.

## 🔧 Manual Control

If you need more control:

```bash
# Clean everything
./cleanup.sh

# Build containers only
./build.sh

# Deploy services only
./deploy.sh

# Run integration tests
./test_integration.sh

# Manage secrets
./secrets.sh help

# Start monitoring stack
cd monitoring && docker-compose up -d
```

## 🌐 Service Endpoints

After deployment, services will be available at:
- Agent: http://localhost:8084
- Coder: http://localhost:8081
- Vision: http://localhost:8082
- Voice: http://localhost:8083 (if model available)

## 📁 Project Structure

```
/
├── master_deploy.sh      # 🚀 Main deployment script
├── build.sh             # 🏗️ Container building
├── deploy.sh            # 🚢 Service deployment
├── cleanup.sh           # 🧹 System cleanup
├── agent-router.sh      # 🎯 Query routing logic
├── secrets.sh           # 🔐 Secrets management
├── download_models.sh   # 🤖 Model downloader
├── test_integration.sh  # ✅ Integration testing
├── Dockerfile*          # 🐳 Container definitions
├── .github/             # 🤖 CI/CD workflows
├── monitoring/          # 📊 Monitoring stack
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   └── grafana/
├── docs/                # 📚 API documentation
│   └── api-spec.yml
├── vault/               # 🔒 Configuration and data
│   ├── configs/         # ⚙️ Service configurations
│   ├── models/          # 🤖 Model placeholders
│   ├── secrets/         # 🔐 Encrypted secrets
│   ├── apis/            # 🔑 API keys directory
│   ├── certs/           # 🔐 SSL certs directory
│   ├── logs/            # 📝 Runtime logs
│   └── backups/         # 💾 System backups
├── llama.cpp/           # 🧠 AI inference engine
└── *.service            # ⚙️ Systemd service files
```

## 🔒 Security

- Sensitive data is stored in `vault/` directory
- Never commit API keys, certificates, or model files
- Use `.gitignore` to protect sensitive files

## 🧪 Testing

```bash
# Test all services
./test_integration.sh

# Test individual components
curl http://localhost:8081/health
curl http://localhost:8082/health
curl http://localhost:8084/health
```

## 📊 Monitoring & Observability (Optional)

The system includes a **free tier compatible** monitoring stack:

```bash
# Start monitoring services (optional)
cd monitoring && docker-compose up -d

# Access dashboards:
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
# Loki: http://localhost:3100
```

### Monitoring Stack (Free Tier Compatible)
- **Prometheus**: Metrics collection (free, self-hosted)
- **Grafana**: Dashboards and visualization (free tier available)
- **Loki**: Log aggregation (free, self-hosted)
- **Promtail**: Log shipping from containers (free)
- **Node Exporter**: System metrics collection (free)

### Metrics Collected
- System resources (CPU, memory, disk, GPU)
- Container health and performance
- AI model inference metrics
- API response times and error rates
- Application logs and events

### Free Tier Notes
- ✅ All components are free and self-hosted
- ✅ No subscription costs or usage limits
- ✅ Works entirely offline after initial setup
- ✅ Optional - can be skipped if not needed

## 🔐 Secrets Management

Secure encrypted storage for sensitive data:

```bash
# Initialize secrets vault
./secrets.sh init

# Store a secret
./secrets.sh set api_key "your-secret-key"

# Retrieve a secret
./secrets.sh get api_key

# Setup common secrets interactively
./secrets.sh setup

# List all secrets
./secrets.sh list

# Backup secrets
./secrets.sh backup
```

## 🤖 CI/CD Pipeline (Free Tier)

Automated testing and validation via GitHub Actions Free Tier:

### Pipeline Features
- **Security scanning** with basic vulnerability checks
- **Script validation** and syntax checking
- **Container validation** and file verification
- **Documentation validation** and link checking
- **Quality assurance** for all code changes

### Workflow Triggers
- Push to main/master branches
- Pull requests
- Manual dispatch

### Quality Gates
- Shell script linting with shellcheck
- Dockerfile syntax validation
- Security vulnerability scanning
- File permission checks
- Documentation validation

### Free Tier Limits
- ✅ 2,000 minutes/month for public repos
- ✅ Unlimited storage for code
- ✅ All standard GitHub Actions included
- ✅ No additional costs for this workflow

### Check Usage
```bash
# Monitor your GitHub usage
./check_github_usage.sh
```

## 💰 GitHub Free Tier Compliance

This project is **optimized for GitHub's free tier** with no additional costs:

### ✅ What's Included (Free)
- **Repository hosting**: Unlimited public repositories
- **GitHub Actions**: 2,000 minutes/month for public repos
- **GitHub Pages**: Static website hosting
- **Issues & PRs**: Full project management
- **Wiki**: Documentation hosting
- **Basic security**: Dependency alerts

### ❌ What's NOT Used (Paid Features)
- **GitHub Packages**: No container registry usage
- **GitHub Releases**: Automated releases removed
- **Large file storage**: Model files downloaded at runtime
- **Advanced security**: Basic scanning only
- **Enterprise features**: Not required

### 📊 Repository Size Warning
⚠️ **Important**: Keep repository under 1GB for optimal performance

Current repository contains:
- **Code**: ~500MB (acceptable)
- **Git history**: May contain large files from previous commits

### 🧹 Repository Cleanup (Required)
```bash
# Clean repository before GitHub upload
./cleanup_repo.sh

# Check repository size
./check_github_usage.sh
```

### 📊 Usage Monitoring
```bash
# Monitor GitHub usage regularly
./check_github_usage.sh

# Expected usage:
# - Repository size: <1GB (after cleanup)
# - CI/CD minutes: <50/month
# - Bandwidth: Minimal
```

### 🎯 Free Tier Optimization
- **Model files**: Downloaded at runtime via `./download_models.sh`
- **Build artifacts**: Excluded from repository
- **Large files**: Proper .gitignore rules
- **CI/CD**: Lightweight, efficient workflows
- **Storage**: Optimized folder structure

### 🚨 GitHub Upload Instructions

⚠️ **Important**: Due to repository size constraints, follow the detailed upload instructions in `GITHUB_UPLOAD.md`

### Quick Checklist
- [ ] Read `GITHUB_UPLOAD.md` for detailed instructions
- [ ] Create clean repository (avoid 11GB git history)
- [ ] Run `./cleanup_repo.sh` on clean copy
- [ ] Verify `./check_github_usage.sh` shows <1GB
- [ ] Push to GitHub public repository
- [ ] Enable GitHub Actions in repository settings

## 📚 API Documentation

Complete OpenAPI specification available at `docs/api-spec.yml`

### Key Endpoints
- `POST /completion` - Text generation
- `POST /chat/completions` - Chat completions (OpenAI-compatible)
- `POST /v1/chat/completions` - Vision-enabled chat
- `GET /health` - Health checks

### API Features
- Streaming responses
- Vision and multimodal input
- Configurable generation parameters
- Comprehensive error handling

## 🛠️ Troubleshooting

### Common Issues

1. **Build fails**: Ensure ROCm dependencies are installed
2. **Out of memory**: Free up RAM or reduce model sizes
3. **Port conflicts**: Run `./cleanup.sh` to reset
4. **GPU not detected**: Check ROCm installation

### Logs

Check logs in `vault/logs/` for detailed information.

## 📚 Advanced Usage

### Systemd Integration

```bash
# Copy service files
sudo cp *.service /etc/systemd/system/

# Enable services
sudo systemctl enable qwen-agent qwen-coder qwen-vision qwen-router

# Start services
sudo systemctl start qwen-agent qwen-coder qwen-vision qwen-router
```

### Model Management

Models are downloaded automatically during first deployment. Available models:
- Qwen3-4B-Instruct (Agent orchestration)
- Qwen2.5-Coder-7B-Instruct (Code generation)
- Qwen2-VL-7B-Instruct (Vision tasks)
- Qwen2-Audio-7B (Voice processing)

## 🤝 Contributing

This is a specialized homelab project. Ensure changes maintain:
- Container-only architecture
- Automated deployment capability
- Security best practices
- Comprehensive error handling

## 📄 License

Personal homelab use only. AI models have their own licenses.