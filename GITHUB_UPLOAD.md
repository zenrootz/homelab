# GitHub Upload Instructions

## 🚨 IMPORTANT: Repository Size Issue

The current git repository is **11GB** due to large files in git history. This exceeds GitHub's recommended limits.

## 🛠️ Solution: Create Clean Repository

```bash
# 1. Create new directory for clean repo
cd ..
mkdir homelab-clean
cd homelab-clean

# 2. Copy only the clean files (exclude .git)
cp -r ../homelab/* ./
cp ../homelab/.gitignore ./
cp ../homelab/.github/ ./ 2>/dev/null || mkdir -p .github/workflows

# 3. Remove any remaining large files
./cleanup_repo.sh

# 4. Initialize new git repository
rm -rf .git
git init
git add .
git commit -m "Initial commit - Qwen Multimodal Agent"

# 5. Create GitHub repository and push
# Visit https://github.com/new
# Create public repository named "homelab" or similar
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

## ✅ Verification

After upload, run:
```bash
./check_github_usage.sh
```

Expected results:
- Repository size: <1GB
- No large files in git
- All checks passing

## 📋 Files to Keep

The clean repository should contain:
- ✅ Core deployment scripts
- ✅ Dockerfiles and configurations
- ✅ Documentation and README
- ✅ CI/CD workflows
- ✅ Monitoring configurations
- ❌ Large model files (downloaded at runtime)
- ❌ Build artifacts
- ❌ Cache files
- ❌ Log files

## 🎯 GitHub Free Tier Benefits

- ✅ Unlimited public repositories
- ✅ 2,000 CI/CD minutes/month
- ✅ All features used are free
- ✅ No bandwidth charges
- ✅ No storage limits (within reason)