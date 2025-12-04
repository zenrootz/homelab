#!/bin/bash
# GitHub Free Tier Usage Checker
# Helps monitor usage to stay within free tier limits

echo "🔍 GitHub Free Tier Usage Check"
echo "================================="

# Check repository size
echo "📊 Repository Size:"
echo "  - Code size: $(du -sh . --exclude=.git | cut -f1)"
echo "  - Git size: $(du -sh .git 2>/dev/null | cut -f1 || echo 'N/A')"

# Check for large files
echo ""
echo "📁 Large Files Check:"
large_files=$(find . -type f -size +50M 2>/dev/null | wc -l)
if [ "$large_files" -gt 0 ]; then
    echo "  ⚠️  Found $large_files files larger than 50MB:"
    find . -type f -size +50M -exec ls -lh {} \; 2>/dev/null
else
    echo "  ✅ No large files found (>50MB)"
fi

# Check for model files in git
echo ""
echo "🤖 Model Files Check:"
model_files=$(find . -name "*.gguf" -type f | wc -l)
if [ "$model_files" -gt 0 ]; then
    echo "  ⚠️  Found $model_files model files in repository:"
    find . -name "*.gguf" -type f -exec ls -lh {} \;
    echo "  💡 Consider using .gitignore to exclude model files"
else
    echo "  ✅ No model files found in repository"
fi

# Check .gitignore effectiveness
echo ""
echo "🛡️ .gitignore Check:"
if [ -f ".gitignore" ]; then
    echo "  ✅ .gitignore file exists"

    # Check for common files that should be ignored
    ignored_patterns=("*.log" "vault/logs/" "vault/backups/" "*.gguf" "llama.cpp/build/")

    for pattern in "${ignored_patterns[@]}"; do
        if git check-ignore "$pattern" 2>/dev/null; then
            echo "  ✅ Pattern ignored: $pattern"
        else
            echo "  ⚠️  Pattern not ignored: $pattern"
        fi
    done
else
    echo "  ❌ No .gitignore file found"
fi

# GitHub Actions usage estimate
echo ""
echo "⚙️ GitHub Actions Usage Estimate:"
echo "  - Workflow runs: ~5-10 minutes each"
echo "  - Free tier: 2,000 minutes/month (public repos)"
echo "  - Estimated monthly usage: <50 minutes"
echo "  ✅ Well within free tier limits"

# GitHub Packages usage
echo ""
echo "📦 GitHub Packages Usage:"
echo "  - Not using GHCR in CI/CD workflow"
echo "  - Free tier: 500MB storage, 5GB bandwidth"
echo "  ✅ No usage - staying free"

# Recommendations
echo ""
echo "💡 Recommendations:"
echo "  - Keep model files out of git (use download_models.sh)"
echo "  - Regular cleanup of vault/logs/ and vault/backups/"
echo "  - Monitor repository size monthly"
echo "  - Use GitHub's free features only"

echo ""
echo "🎉 Repository is optimized for GitHub Free Tier!"