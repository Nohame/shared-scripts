
# Shared Scripts

**Shared Scripts** is a repository containing reusable and centralized shell scripts to simplify common tasks across your projects. These scripts are designed to be sourced into your projects, centralizing functionality and improving maintainability.

---

## Features

- **Utility Functions:**
    - Manage display messages (success, error, etc.).
    - Use color-coded output for better readability.

---

## Repository Structure

The repository is organized as follows:

```
shared-scripts/
├── common-utils.sh       # General functions (display, colors, etc.).
├── docker-helpers.sh     # Docker-related functions.
├── env-check.sh          # Environment file verification.
└── README.md             # Project documentation.
```

---

## Installation

1. Clone the repository into a directory accessible by your projects:
   ```bash
   git clone https://gitlab.com/Nohame/shared-scripts.git
   ```

2. (Optional) Add the script path to your environment:
   ```bash
   export SHARED_SCRIPTS_PATH="/path/to/shared-scripts"
   ```

---

## Usage

### 1. **Import the scripts into your project**

Add an import statement in your main script to source the required shared scripts.

Example with `colors-messages.sh`:
```sh
#!/usr/bin/env sh

# Import shared scripts
source "/path/to/shared-scripts/colors-messages.sh"

# Example usage
display_success "Shared scripts have been successfully imported."
```

---

### 2. **Available Functions**

#### **common-utils.sh**
- `display(message)` : Displays a generic message.
- `display_success(message)` : Displays a success message (in green).
- `display_error(message)` : Displays an error message (in red).

---

## Integration Example

### Project Structure Using `shared-scripts`:
```
my-project/
├── scripts/
│   ├── main-script.sh
│   └── ...
├── .env
├── .env.sample
└── ...
```

### Example Main Script
```sh
#!/usr/bin/env sh

# Import shared scripts
SHARED_SCRIPTS_PATH="/path/to/shared-scripts"
source "$SHARED_SCRIPTS_PATH/colors-messages.sh"

# Check environment variables
if ! check_env_vars; then
    display_error "The script has stopped because some variables are missing."
    exit 1
fi

# Continue script...
display_success "All variables are present. Starting containers..."
```

---

## Updates

To update the shared scripts in your projects, simply run:
```bash
git pull origin main
```

---

## Contribution

1. Fork the repository.
2. Create a branch for your changes:
   ```bash
   git checkout -b feature/new-feature
   ```
3. Add your changes and push the branch:
   ```bash
   git push origin feature/new-feature
   ```
4. Create a Pull Request.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Contact

For any questions or suggestions, feel free to contact [Nohame] at [belkaid.nohame@gmail.com].
