# CLAUDE.md

Guide for AI assistants working on the **linux_cac** repository.

## Project Overview

**linux_cac** is a Bash script that automates Common Access Card (CAC) configuration on Debian-based Linux distributions. It installs middleware, downloads DoD certificates, imports them into browser certificate databases, and registers the PKCS#11 module — enabling smart card authentication in Firefox and Chrome.

The project uses OpenSC (migrated from Cackey) for PKCS#11 support.

## Repository Structure

```
linux_cac/
├── cac_setup.sh                 # Main script (single entry point, ~475 lines)
├── .github/workflows/CI.yml     # GitHub Actions: ShellCheck static analysis
├── README.md                    # User-facing documentation
├── LICENSE                      # MIT License (2022-2025, Jeremy Jackson)
└── CLAUDE.md                    # This file
```

This is a single-script project. All logic lives in `cac_setup.sh`.

## Language and Tooling

- **Language:** Bash (requires `bash` 4.0+ for `mapfile`)
- **Linter:** [ShellCheck](https://www.shellcheck.net/) with `-x` flag (follow source directives)
- **CI:** GitHub Actions runs ShellCheck on all branches and PRs
- **No build step** — the script is distributed and executed directly

## Running CI Locally

```bash
shellcheck -x cac_setup.sh
```

This is the only automated quality check. All ShellCheck warnings must be resolved or explicitly suppressed with `# shellcheck disable=SCXXXX` comments.

## Script Architecture

`cac_setup.sh` follows a top-level `main()` function pattern — `main` is defined first and called at the bottom of the file (line 475).

### Execution Flow

1. `root_check()` — Verify root/sudo privileges
2. `browser_check()` — Detect Firefox (snap vs apt) and Chrome
3. If snap Firefox: prompt user to replace with apt version via `reconfigure_firefox()`
4. Locate `cert9.db` databases in user's home directory
5. Install middleware packages via `apt`
6. Download DoD certificates from `militarycac.com`
7. Import certificates into each browser's database via `certutil`
8. Register CAC module with `pkcs11-register`
9. Enable `pcscd.socket` service
10. Clean up temporary artifacts

### Key Functions

| Function | Purpose |
|---|---|
| `main()` | Orchestrates the full setup flow |
| `root_check()` | Ensures script runs as root (exit 86 if not) |
| `browser_check()` | Detects browsers and sets control flags |
| `check_for_firefox()` | Finds Firefox, determines snap vs apt |
| `check_for_chrome()` | Finds Google Chrome |
| `reconfigure_firefox()` | Replaces snap Firefox with apt version |
| `backup_ff_profile()` | Backs up Firefox profile before snap removal |
| `migrate_ff_profile()` | Restores profile after reinstall |
| `run_firefox()` / `run_chrome()` | Headless launch to initialize profile dirs |
| `import_certs()` | Imports .cer files into a cert9.db database |
| `check_for_ff_pin()` | Detects GNOME favorites bar pin |
| `repin_firefox()` | Re-pins Firefox after reinstall |
| `revert_firefox()` | Rolls back to snap Firefox on failure |
| `print_err()` / `print_info()` | Colored output helpers (red/yellow) |

### Exit Codes

| Code | Constant | Meaning |
|---|---|---|
| 0 | `EXIT_SUCCESS` | Successful completion |
| 86 | `E_NOTROOT` | Script not run as root |
| 87 | `E_BROWSER` | No compatible browser found |
| 88 | `E_DATABASE` | No cert9.db database located |

### Key Variables

- `ORIG_HOME` — The invoking user's home directory (resolved from `$SUDO_USER`)
- `DWNLD_DIR` — Temp directory for artifacts (`/tmp`)
- `DB_FILENAME` — Certificate database name (`cert9.db`)
- `CERT_URL` — DoD certificate bundle URL (HTTPS)
- `snap_ff` / `ff_exists` / `chrome_exists` — Boolean flags controlling flow

## Code Conventions

### Style

- **Shebang:** `#!/usr/bin/env bash`
- **Function definitions:** Use `function_name ()` with opening brace on next line
- **Constants/globals:** `SCREAMING_SNAKE_CASE` (e.g., `EXIT_SUCCESS`, `DWNLD_DIR`)
- **Local/flag variables:** `lowercase_snake_case` (e.g., `snap_ff`, `chrome_exists`)
- **Booleans:** String comparison (`"$var" == true/false`)
- **Function closing:** Comment `} # function_name` after every closing brace
- **Quoting:** All variable expansions are quoted (`"$var"`)
- **Conditional style:** `if [ ... ]; then` or `if [ ... ]\nthen` (both used; multi-line `if/then` preferred)

### ShellCheck Compliance

The codebase must pass `shellcheck -x`. When a warning must be suppressed, use an inline directive with the specific code:

```bash
# shellcheck disable=SC2016
```

Only suppress warnings that are intentional (e.g., SC2016 for literal `$` in single-quoted strings meant for deferred evaluation).

### Interactive Prompts

The script prompts users interactively (y/n) for:
- Replacing snap Firefox with apt version
- Migrating Firefox profile data

Prompts use a `while` loop validating input is exactly `"y"` or `"n"`.

## System Dependencies

Packages installed by the script:
```
libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget opensc
```

## Supported Configurations

| Distribution | Versions | Browsers |
|---|---|---|
| Debian | 12.5 | Firefox ESR, Chrome, Edge |
| Mint | 21.2 | Firefox, Chrome |
| Parrot OS | 6.0.0-2 | Firefox, Brave |
| PopOS! | 20.04 LTS, 22.04 LTS | Firefox, Chrome |
| Ubuntu | 20.04 LTS, 22.04 LTS | Firefox, Chrome |

## Git Workflow

- **Default branch:** `main`
- **Branching:** Feature branches from `main` (e.g., `add-license`, `https-cert-url`)
- **Merges:** Pull requests into `main`
- **CI:** ShellCheck runs on all pushes and PRs

## Contributing Guidelines

Per README.md:
1. Fork the repository
2. Create a feature branch
3. Make focused, atomic commits
4. Ensure `shellcheck -x cac_setup.sh` passes
5. Open a PR against `main`
6. For larger changes, open an issue first to discuss

## Common Tasks

### Adding a new supported distribution
Update the table in `README.md` under "Supported Configurations" after testing.

### Adding a new browser
1. Add a detection function (like `check_for_firefox` / `check_for_chrome`)
2. Add a headless runner to initialize the profile directory
3. Update `browser_check()` to call the new detection function
4. Ensure `cert9.db` path discovery in `main()` captures the new browser's database
5. Update README.md supported configurations

### Modifying certificate import logic
The `import_certs()` function handles all cert importing. It takes a `cert9.db` path and uses `certutil` to import all `.cer` files with trust flags `TC`.

### Suppressing a ShellCheck warning
Add a comment directly above the flagged line:
```bash
# shellcheck disable=SC1234
problematic_line_here
```
Document why the suppression is necessary.

## Important Notes

- The script must be run as root (`sudo`) because it installs system packages and modifies system services
- Snap Firefox is incompatible with the certificate import method — the script offers to replace it with the apt version from Mozilla's PPA
- The script downloads certificates from an external URL (`militarycac.com`) — changes to that upstream source may break functionality
- `pkcs11-register` behavior can be unreliable in scripted contexts (documented known issue)
- All temporary artifacts are stored in `/tmp` and cleaned up on exit
