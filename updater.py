import sys
import re
import logging
import requests
from pathlib import Path
import shutil 

# --- Configuration ---
FLAKE_FILENAME = "flake.nix"
REPO_OWNER = "Voxelum"
REPO_NAME = "x-minecraft-launcher"

ARCH = "x64"
REPO_API_URL = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"
REQUEST_TIMEOUT = 15

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s',
    stream=sys.stderr, # Log INFO and higher to stderr like the bash script
)

# --- Functions ---

def error_exit(message: str, exit_code: int = 1):
    """Logs an error message and exits."""
    logging.error(message)
    sys.exit(exit_code)

def get_current_version(flake_path: Path) -> str | None:
    """Gets the current version from flake.nix using regex."""
    logging.info(f"Checking current version in {flake_path}...")
    version_pattern = re.compile(r'^\s*xmclVersion\s*=\s*"([^"]+)"\s*;?\s*$')
    try:
        with flake_path.open('r', encoding='utf-8') as f:
            for line in f:
                match = version_pattern.search(line)
                if match:
                    version = match.group(1)
                    logging.info(f"Current version found: {version}")
                    return version
        logging.warning(f"Could not find current version pattern in {flake_path}.")
        return None
    except IOError as e:
        error_exit(f"Failed to read {flake_path}: {e}")
        return None # Should not be reached due to error_exit

def get_latest_tag_from_github() -> str:
    """Fetches the latest release tag name from the GitHub API."""
    try:
        response = requests.get(REPO_API_URL, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()  # Raises HTTPError for 4xx/5xx status codes
        data = response.json()
        tag = data.get('tag_name')

        if not tag:
            error_exit(f"Could not find 'tag_name' in API response from {REPO_API_URL}. Response: {data}")

        # Validate tag format (e.g., vX.Y.Z)
        if not re.match(r'^v\d+\.\d+\.\d+$', tag):
            error_exit(f"Fetched tag '{tag}' does not match expected format (e.g., vX.Y.Z).")

        return tag

    except requests.exceptions.Timeout:
        error_exit(f"Request timed out while fetching {REPO_API_URL}.")
    except requests.exceptions.HTTPError as e:
        error_message = f"HTTP Error fetching latest release: {e}\nURL: {REPO_API_URL}"
        if e.response.status_code in (403, 429):
             error_message += "\nPossible reason: GitHub API rate limit exceeded. Wait or use an access token."
        elif e.response.status_code == 404:
             error_message += f"\nPossible reason: Repository '{REPO_OWNER}/{REPO_NAME}' or API endpoint not found."
        error_exit(error_message)
    except requests.exceptions.RequestException as e:
        error_exit(f"Network error fetching latest release: {e}\nURL: {REPO_API_URL}")
    except ValueError as e: # Catches JSONDecodeError in older requests/Python
         error_exit(f"Failed to decode JSON response from {REPO_API_URL}. Error: {e}")
    return "" # Should not be reached

def get_sha256_for_tag(tag: str) -> str:
    """Downloads and returns the SHA256 hash for a given tag and architecture."""
    if not tag.startswith('v'):
        error_exit(f"Tag '{tag}' must start with 'v'.")

    version = tag.lstrip('v')
    sha256_filename = f"xmcl-{version}-{ARCH}.tar.xz.sha256"
    sha256_url = f"https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/{tag}/{sha256_filename}"

    try:
        response = requests.get(sha256_url, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        sha256_content = response.text.strip() # Get text content and remove whitespace

        if not sha256_content:
            error_exit(f"Received empty content from SHA256 URL: {sha256_url}")

        # Validate SHA256 format
        if not re.match(r'^[a-f0-9]{64}$', sha256_content):
            error_exit(f"Content from SHA256 URL ('{sha256_content}') does not look like a valid SHA256 hash.")

        return sha256_content

    except requests.exceptions.Timeout:
        error_exit(f"Request timed out while fetching {sha256_url}.")
    except requests.exceptions.HTTPError as e:
         error_exit(f"HTTP Error {e.response.status_code} fetching SHA256.\nURL: {sha256_url}\nCheck if the asset exists for tag {tag} and architecture {ARCH}.")
    except requests.exceptions.RequestException as e:
         error_exit(f"Network error fetching SHA256: {e}\nURL: {sha256_url}")
    return "" # Should not be reached


def update_flake_file(flake_path: Path, new_version: str, new_sha256: str):
    """Updates the version and sha256 in the flake.nix file."""
    backup_path = flake_path.with_suffix(flake_path.suffix + '.bak')

    try:
        # Read original content
        with flake_path.open('r', encoding='utf-8') as f:
            lines = f.readlines()

        new_lines = []
        version_updated = False
        sha256_updated = False

        # Regex patterns for replacement
        version_pattern = re.compile(r'^(\s*xmclVersion\s*=\s*)"[^"]+"(\s*;?\s*)$')
        sha256_pattern = re.compile(r'^(\s*sha256\s*=\s*)"[^"]+"(\s*;?\s*)$')

        for line in lines:
            new_line = line
            if not version_updated:
                new_line, count = version_pattern.subn(rf'\1"{new_version}"\2', line)
                if count > 0:
                    version_updated = True

            if not sha256_updated and new_line is line: # Check if line was already modified by version
                 new_line, count = sha256_pattern.subn(rf'\1"{new_sha256}"\2', line)
                 if count > 0:
                     sha256_updated = True

            new_lines.append(new_line)

        if not version_updated:
            logging.error(f"Failed to find the 'xmclVersion' line to update in {flake_path}.")
            # No exit here, maybe only sha needs update? Check below.
        if not sha256_updated:
             error_exit(f"Failed to find the 'sha256' line to update in {flake_path}.") # SHA must be updated if version is new


        if not version_updated and not sha256_updated:
            error_exit(f"Failed to find either 'xmclVersion' or 'sha256' lines in {flake_path}.")


        # Create backup before writing
        logging.info(f"Creating backup: {backup_path}")
        shutil.copy2(flake_path, backup_path) # copy2 preserves metadata

        # Write updated content
        try:
            with flake_path.open('w', encoding='utf-8') as f:
                f.writelines(new_lines)
        except IOError as write_err:
             # Attempt to restore from backup on write error
             logging.error(f"Failed to write updated {flake_path}: {write_err}")
             logging.info(f"Attempting to restore from backup {backup_path}...")
             try:
                 shutil.move(backup_path, flake_path)
                 logging.info("Restored from backup successfully.")
             except Exception as restore_err:
                 logging.error(f"!!! CRITICAL: Failed to restore from backup: {restore_err}")
                 logging.error(f"!!! {flake_path} might be corrupted. Original backup is at {backup_path}")
             error_exit("File update failed.", 2) # Different exit code for update failure

        # Basic verification after writing (optional but good)
        # Re-read and check if the values are correct, though successful write is usually enough
        # if not verify_update(flake_path, new_version, new_sha256): # Implement verify_update if needed
        #     error_exit(f"Verification failed after updating {flake_path}. Check the file and backup {backup_path}.")

        logging.info(f"\033[32mSuccessfully updated {flake_path}\033[0m") # Green text for success
        backup_path.unlink() # Remove backup on success
        logging.info(f"Removed backup file: {backup_path}")

    except IOError as e:
        error_exit(f"Error during file update process for {flake_path}: {e}")
    except Exception as e:
        logging.error(f"An unexpected error occurred during update: {e}")
        if backup_path.exists():
             logging.error(f"Backup file might still exist at {backup_path}")
        error_exit("Unexpected error during update.", 3)

# --- Main Execution ---
def main():
    """Main script logic."""
    flake_file = Path(FLAKE_FILENAME)

    # Check if flake file exists
    if not flake_file.is_file():
        error_exit(f"File not found: {flake_file}")

    # 1. Get Current Version
    current_version = get_current_version(flake_file)
    # No exit if not found, proceed to get latest

    # 2. Get Latest Version from GitHub
    latest_tag = get_latest_tag_from_github()
    latest_version = latest_tag.lstrip('v')
    logging.info(f"Latest version from GitHub: {latest_version} (tag: {latest_tag})")

    # 3. Compare versions
    if current_version == latest_version:
        logging.info(f"\033[32mVersion {latest_version} is already up-to-date. No update needed.\033[0m")
        sys.exit(0)

    # 4. Update the flake file
    new_sha256 = get_sha256_for_tag(latest_tag)

    update_flake_file(flake_file, latest_version, new_sha256)

    logging.info(f"\033[32mUpdate process finished.\033[0m")

if __name__ == "__main__":
    # Check for dependencies implicitly via imports
    try:
        import requests
    except ImportError:
        error_exit("Required Python package 'requests' is not installed. Please install it (e.g., 'pip install requests').")

    main()