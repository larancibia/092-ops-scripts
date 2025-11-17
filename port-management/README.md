# Port Management Scripts

Professional port allocation and management system for GuanacoLabs projects.

## Quick Start

### Check if a port is available
```bash
./check-port.sh 3000
```

### Find next free port
```bash
./find-free-port.sh frontend    # For frontend ports (3000-3199)
./find-free-port.sh backend     # For backend ports (8000-8199)
```

### Allocate a port for a new project
```bash
./allocate-port.sh MyProject frontend high
./allocate-port.sh MyAPI backend medium
./allocate-port.sh MyCache redis low
```

### List all ports
```bash
./list-ports.sh              # All ports
./list-ports.sh in-use       # Only production
./list-ports.sh reserved     # Only reserved
./list-ports.sh critical     # Only critical priority
```

### Migrate a project to a new port
```bash
./migrate-port.sh MyProject 3050 3150
```

## Port Ranges

| Type | Range | Capacity | Description |
|------|-------|----------|-------------|
| Frontend | 3000-3199 | 200 | Web applications |
| Backend | 8000-8199 | 200 | API services |
| Database | 5432-5531 | 100 | PostgreSQL, MySQL |
| Redis | 6379-6478 | 100 | Cache services |
| Services | 9000-9199 | 200 | Microservices |

## Files

- **Registry:** `/home/luis/port-registry.json`
- **Documentation:** `/home/luis/PORT_ASSIGNMENTS.md`
- **Scripts:** `/home/luis/scripts/port-management/`

## Priority Levels

- `critical` - Production systems
- `high` - Important/staging
- `medium` - Development
- `low` - Experimental
- `archived` - Inactive

## Examples

### Deploy a new fullstack app
```bash
# Allocate frontend port
./allocate-port.sh MyApp frontend high

# Allocate backend port
./allocate-port.sh MyApp backend high

# Allocate database port
./allocate-port.sh MyApp postgresql high

# Allocate Redis port
./allocate-port.sh MyApp redis medium
```

### Check what ports are in use
```bash
# Check specific port
./check-port.sh 3000

# List all production ports
./list-ports.sh in-use

# List all AI projects
./list-ports.sh | grep "AI & Machine Learning"
```

### Find conflicts
```bash
# Check if port is truly available
./check-port.sh 3050

# Find next available port in range
./find-free-port.sh frontend
```

## Current Usage

- **Total Projects:** 84
- **Ports Allocated:** 336 (84 × 4)
- **Conflicts:** 0
- **Production Systems:** 5

## Next Available Ports

- Frontend: 3105
- Backend: 8088
- Database: 5520
- Redis: 6468

## Support

For issues or questions, check:
1. Main documentation: `/home/luis/PORT_ASSIGNMENTS.md`
2. Registry file: `/home/luis/port-registry.json`
3. Script help: `./script-name.sh --help`

---

**Last Updated:** 2025-11-17
**Version:** 2.0.0
