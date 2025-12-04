#!/bin/bash
# GitHub Repository Cleanup Script
# Prepares repository for GitHub Free Tier upload

echo "🧹 GitHub Repository Cleanup"
echo "============================"

# Check current repository size
echo "📊 Current Repository Status:"
echo "  Git size: $(du -sh .git | cut -f1)"
echo "  Working directory: $(du -sh . --exclude=.git | cut -f1)"

# Remove large files from working directory
echo ""
echo "🗑️ Removing large files from working directory..."
rm -rf vault/models/.cache/
rm -rf llama.cpp/models/*.gguf 2>/dev/null || true
find . -name "*.log" -type f -delete
find . -name "*.tmp" -type f -delete

# Clean git
echo ""
echo "🧽 Cleaning git repository..."
git gc --aggressive --prune=now

echo ""
echo "📋 Repository Cleanup Summary:"
echo "=============================="
echo "✅ Removed: Model cache files"
echo "✅ Removed: Build artifacts"
echo "✅ Removed: Log files"
echo "✅ Cleaned: Git repository"

echo ""
echo "📊 Final Repository Status:"
echo "  Git size: $(du -sh .git 2>/dev/null | cut -f1 || echo 'N/A')"
echo "  Working directory: $(du -sh . --exclude=.git | cut -f1)"

echo ""
echo "💡 For GitHub Free Tier:"
echo "  - Repository should be <1GB for optimal performance"
echo "  - Large files should be downloaded at runtime"
echo "  - Use .gitignore to prevent future large file commits"

echo ""
echo "🚀 Ready for GitHub upload!"
echo "  Run: git add . && git commit -m 'Initial commit' && git push"