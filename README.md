# Shell User Management System

Shell-based user management system designed for system administrators to create, manage, and maintain user accounts on Unix/Linux systems with enterprise-grade features.

## What it can do

- **Secure User Creation**: Auto-generate cryptographically secure passwords
- **Comprehensive User Management**: Create, delete, modify, and list users
- **Advanced Backup System**: Full and incremental backup capabilities
- **Robust Logging**: Multi-level logging with rotation and archival
- **Configuration Management**: Centralized configuration with validation
- **Security Features**: Input validation, privilege checking, audit trails
- **Multiple Output Formats**: JSON, CSV, XML, and table formats
- **Enterprise Integration**: LDAP, Active Directory, and API support
- **Compliance Ready**: SOX, HIPAA, GDPR, and ISO 27001 compliance features

## Requirements

- **Operating System**: Linux/Unix systems (tested on Ubuntu, CentOS, RHEL)
- **Privileges**: Root access required for all operations
- **Shell**: Bash 4.0 or higher
- **Dependencies**: Standard Unix utilities (useradd, userdel, usermod, passwd, etc.)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/1cbyc/shell-user-management.git
cd shell-user-management
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Setup the system:
```bash
sudo ./logging.sh --setup
sudo ./config.sh --setup
```

## Usage

### User Creation

Create a new user with auto-generated password:
```bash
sudo ./user_make.sh username "User Full Name"
```

Example:
```bash
sudo ./user_make.sh john "John Doe"
```

### User Management

**List Users:**
```bash
sudo ./user_list.sh                    # List regular users
sudo ./user_list.sh --all              # List all users including system users
sudo ./user_list.sh --format json      # Output in JSON format
sudo ./user_list.sh --group sudo       # Filter by group membership
sudo ./user_list.sh --verbose          # Show detailed information
```

**Delete Users:**
```bash
sudo ./user_delete.sh username         # Delete user with confirmation
sudo ./user_delete.sh username --force # Force delete without confirmation
sudo ./user_delete.sh username --remove-home # Delete with home directory
```

**Modify Users:**
```bash
sudo ./user_modify.sh username --comment "New Name"
sudo ./user_modify.sh username --shell /bin/zsh
sudo ./user_modify.sh username --groups sudo,docker
sudo ./user_modify.sh username --password newpass123
sudo ./user_modify.sh username --lock   # Lock account
sudo ./user_modify.sh username --unlock # Unlock account
```

### Backup and Recovery

**Backup Operations:**
```bash
sudo ./user_backup.sh --backup username     # Backup specific user
sudo ./user_backup.sh --backup --full       # Full system backup
sudo ./user_backup.sh --backup --incremental # Incremental backup
sudo ./user_backup.sh --list                # List available backups
sudo ./user_backup.sh --verify              # Verify backup integrity
```

**Restore Operations:**
```bash
sudo ./user_backup.sh --restore backup_file.tar.gz
sudo ./user_backup.sh --cleanup 7           # Clean up old backups
```

### Configuration Management

**Configuration Operations:**
```bash
sudo ./config.sh --show                    # Show current configuration
sudo ./config.sh --edit                    # Edit configuration file
sudo ./config.sh --get LOG_LEVEL           # Get specific setting
sudo ./config.sh --set LOG_LEVEL DEBUG     # Set specific setting
sudo ./config.sh --backup                  # Backup configuration
sudo ./config.sh --reset                   # Reset to defaults
```

### Logging System

**Log Management:**
```bash
sudo ./logging.sh --setup                  # Setup logging system
sudo ./logging.sh --tail 100               # Show last 100 lines
sudo ./logging.sh --follow                 # Follow logs in real-time
sudo ./logging.sh --grep "ERROR"           # Search for errors
sudo ./logging.sh --export logs.json json  # Export logs in JSON format
sudo ./logging.sh --analyze                # Analyze log statistics
sudo ./logging.sh --rotate                 # Rotate log files
sudo ./logging.sh --cleanup 30             # Clean up old logs
```

## Configuration

The system uses a centralized configuration file located at `/etc/user_management/user_management.conf`. Key configuration sections include:

### Security Settings
- Password complexity requirements
- Account lockout policies
- Session timeout settings
- UID/GID ranges

### Logging Configuration
- Log levels (DEBUG, INFO, WARN, ERROR)
- Log rotation settings
- Retention policies
- Output formats

### Backup Settings
- Backup directories
- Retention periods
- Compression options
- Verification settings

### Integration Settings
- LDAP/Active Directory configuration
- API endpoints
- Email notification settings
- Monitoring thresholds

## Security Features

### Password Security
- Cryptographically secure random generation using `/dev/urandom`
- Configurable password complexity requirements
- Automatic password expiration policies
- Secure password transmission

### Access Control
- Root privilege validation for all operations
- Input sanitization and validation
- Command injection prevention
- Secure file operations

### Audit Trail
- Comprehensive operation logging
- User action tracking
- Security event monitoring
- Compliance reporting capabilities

## Output Formats

The system supports multiple output formats for different use cases:

### Table Format (Default)
```
Username         UID      GID      Home Directory      Shell         Groups           Status
-------         ---      ---      --------------      -----         ------           ------
john            1001     1001     /home/john          /bin/bash     john sudo        P
```

### JSON Format
```json
[
  {
    "username": "john",
    "uid": 1001,
    "gid": 1001,
    "home_directory": "/home/john",
    "shell": "/bin/bash",
    "groups": "john sudo",
    "account_status": "P"
  }
]
```

### CSV Format
```csv
Username,UID,GID,Home Directory,Shell,Groups,Account Status
john,1001,1001,/home/john,/bin/bash,"john sudo",P
```

## Error Handling

The system implements comprehensive error handling:

- **Validation Errors**: Input format and range validation
- **System Errors**: User creation failures, permission issues
- **Recovery Procedures**: Automatic rollback on failures
- **Detailed Messages**: Clear error descriptions and solutions

## Logging

### Log Levels
- **DEBUG**: Detailed execution information
- **INFO**: General operation status
- **WARN**: Potential issues and warnings
- **ERROR**: Operation failures and errors

### Log Management
- Automatic log rotation based on size
- Configurable retention policies
- Compression of old log files
- Multiple export formats

## Compliance Features

### Audit Requirements
- Complete audit trail for all operations
- User action tracking and reporting
- Security event monitoring
- Compliance report generation

### Standards Support
- **SOX Compliance**: Financial reporting requirements
- **HIPAA Compliance**: Healthcare data protection
- **GDPR Compliance**: European data protection
- **ISO 27001**: Information security management

## Performance Optimization

### Resource Management
- Efficient memory usage patterns
- Optimized file operations
- Minimal system resource consumption
- Scalable architecture design

### Monitoring
- Real-time performance metrics
- Resource usage tracking
- Performance bottleneck detection
- Automated optimization suggestions

## Troubleshooting

### Common Issues

**Permission Denied Errors:**
- Ensure scripts are executed with root privileges
- Check file permissions on script files
- Verify system user creation permissions

**Password Generation Failures:**
- Check `/dev/urandom` availability
- Verify system entropy sources
- Review password complexity settings

**User Creation Conflicts:**
- Verify username uniqueness
- Check UID/GID availability
- Review system user limits

### Diagnostic Commands

```bash
# Check system status
sudo ./logging.sh --stats

# Analyze recent errors
sudo ./logging.sh --grep "ERROR" --tail 50

# Verify configuration
sudo ./config.sh --validate

# Test user creation
sudo ./user_make.sh testuser "Test User" --dry-run
```

## Development

### Project Structure
```
shell-user-management/
├── user_make.sh          # User creation script
├── user_delete.sh        # User deletion script
├── user_list.sh          # User listing script
├── user_modify.sh        # User modification script
├── user_backup.sh        # Backup and restore script
├── config.sh             # Configuration management
├── logging.sh            # Logging system
├── docs/
│   ├── explanation.md    # Technical documentation
│   └── whats-next.md     # Development roadmap
└── README.md             # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Testing

Run the test suite:
```bash
# Unit tests
./test_user_management.sh

# Integration tests
./test_integration.sh

# Security tests
./test_security.sh
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- **Issues**: [GitHub Issues](https://github.com/1cbyc/shell-user-management/issues)
- **Documentation**: [docs/explanation.md](docs/explanation.md)
- **Roadmap**: [docs/whats-next.md](docs/whats-next.md)

## Acknowledgments

- Unix/Linux community for shell scripting best practices
- Security researchers for input validation techniques
- System administrators for real-world usage feedback

## Version History

- **v1.0.0**: Initial release with core user management features
- **v1.1.0**: Added backup and restore capabilities
- **v1.2.0**: Enhanced logging and configuration management
- **v1.3.0**: Added compliance and security features
- **v1.4.0**: Performance optimizations and monitoring
- **v1.5.0**: Enterprise integration and API support 