# Contributing to Qwen Multimodal Agent

Thank you for your interest in contributing to the Qwen Multimodal Agent project! This document provides guidelines and information for contributors.

## 🚀 Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/homelab.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `./test_integration.sh`
6. Commit your changes: `git commit -m "Add your feature"`
7. Push to your fork: `git push origin feature/your-feature`
8. Create a Pull Request

## 📋 Development Setup

### Prerequisites
- Fedora 43+ with Podman
- At least 16GB RAM
- AMD GPU with ROCm (optional)

### Setup
```bash
# Download models (first time only)
./download_models.sh

# Deploy for development
./master_deploy.sh

# Run tests
./test_integration.sh
```

## 🐛 Reporting Issues

### Bug Reports
When reporting bugs, please include:
- **Description**: Clear description of the issue
- **Steps to reproduce**: Step-by-step instructions
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Environment**: OS, hardware, versions
- **Logs**: Relevant log output

### Feature Requests
For feature requests, please include:
- **Use case**: Why do you need this feature?
- **Proposed solution**: How should it work?
- **Alternatives**: Other solutions you've considered

## 💻 Development Guidelines

### Code Style
- **Shell scripts**: Follow POSIX standards, use `shellcheck`
- **Documentation**: Clear, concise, and complete
- **Commits**: Use conventional commit format
- **Branching**: Feature branches from `main`

### Testing
- Write tests for new features
- Ensure all tests pass before submitting PR
- Test on multiple environments when possible

### Documentation
- Update README.md for user-facing changes
- Add code comments for complex logic
- Update API documentation for endpoint changes

## 🔒 Security

### Reporting Security Issues
Please report security vulnerabilities by emailing security@homelab.local instead of creating public issues.

### Security Best Practices
- Never commit sensitive data (API keys, passwords, etc.)
- Use the secrets management system for sensitive configuration
- Follow the principle of least privilege
- Keep dependencies updated

## 📝 Commit Guidelines

Use conventional commits:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Testing changes
- `chore`: Maintenance tasks

Examples:
```
feat: add voice processing support
fix: resolve container startup issue
docs: update API documentation
```

## 🔄 Pull Request Process

1. **Create a PR**: Use the PR template
2. **Code Review**: Address reviewer feedback
3. **Tests**: Ensure CI passes
4. **Merge**: Squash merge with descriptive commit message

### PR Checklist
- [ ] Tests pass
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No sensitive data committed
- [ ] Backward compatibility maintained

## 🎯 Areas for Contribution

### High Priority
- Performance optimizations
- Additional model support
- Enhanced monitoring
- Security improvements

### Medium Priority
- UI improvements
- Additional integrations
- Documentation enhancements
- Testing improvements

### Low Priority
- Code refactoring
- Feature requests
- Community support

## 📞 Getting Help

- **Issues**: GitHub Issues for bugs and features
- **Discussions**: GitHub Discussions for questions
- **Documentation**: Check README.md and docs/

## 📜 License

By contributing to this project, you agree that your contributions will be licensed under the same MIT License that covers the project.

Thank you for contributing to the Qwen Multimodal Agent project! 🚀