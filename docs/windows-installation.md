# Windows Installation Guide

This guide covers installing Vibe on Windows using native cmd.exe (DOS) batch scripts.

## Prerequisites

- **Ruby 2.6+** installed and available in PATH
  - Download from [RubyInstaller](https://rubyinstaller.org/)
  - Verify: `ruby --version`
- **Git** installed (for repository detection)
  - Download from [git-scm.com](https://git-scm.com/)

## Installation Methods

### Method 1: Native Windows Batch Scripts (Recommended)

This method uses native Windows batch files (.bat) that work in cmd.exe without requiring PowerShell or Git Bash.

1. **Clone the repository**:
   ```cmd
   git clone https://github.com/your-org/vibesop.git
   cd vibesop
   ```

2. **Run the Windows installer**:
   ```cmd
   bin\vibe-install.bat
   ```

3. **Add to PATH** (if not already):
   - Open System Properties > Environment Variables
   - Add `%USERPROFILE%\.local\bin` to your user PATH
   - Restart your terminal

4. **Verify installation**:
   ```cmd
   vibe --version
   ```

5. **Install hooks** (optional):
   ```cmd
   cd hooks
   install.bat
   ```

### Method 2: WSL2 (Windows Subsystem for Linux)

If you have WSL2 installed, you can use the Unix installation method:

```bash
# Inside WSL2
./bin/vibe-install
```

### Method 3: Git Bash Fallback

Use the existing bash fallback script:

```bash
# In Git Bash
./bin/vibe-bash.sh --help
```

## Platform-Specific Notes

### cmd.exe vs PowerShell

The batch scripts (.bat) work in both cmd.exe and PowerShell. They are designed for maximum compatibility, especially in corporate environments where PowerShell may be restricted.

### Path Handling

Windows uses backslashes (`\`) for paths, but Ruby handles both forward slashes (`/`) and backslashes. The batch scripts automatically convert paths as needed.

### Hook Configuration

After running `hooks\install.bat`, you need to manually add the hook configuration to `%USERPROFILE%\.claude\settings.json`:

```json
{
  "hooks": {
    "PreSessionEnd": [
      {
        "type": "command",
        "command": "C:\\Users\\YourName\\.claude\\hooks\\pre-session-end.bat"
      }
    ]
  }
}
```

**Note**: Use double backslashes (`\\`) in JSON strings.

## Troubleshooting

### Ruby not found

If you get "ruby is not recognized", ensure Ruby is installed and in your PATH:

```cmd
where ruby
```

If not found, reinstall Ruby and check "Add Ruby to PATH" during installation.

### Permission errors

Unlike Unix systems, Windows doesn't require `sudo`. If you get permission errors:

1. Run cmd.exe as Administrator
2. Or install to a user directory (default: `%USERPROFILE%\.local\bin`)

### Git not found

The hooks require Git for repository detection. Install Git for Windows from [git-scm.com](https://git-scm.com/).

### Hook not triggering

1. Verify the hook file exists: `dir %USERPROFILE%\.claude\hooks\pre-session-end.bat`
2. Check `settings.json` has the correct path with double backslashes
3. Restart Claude Code after configuration changes

## Next Steps

After installation:

1. **Initialize global config**:
   ```cmd
   vibe init --platform claude-code
   ```

2. **Switch project to use Vibe**:
   ```cmd
   cd your-project
   vibe switch --platform claude-code
   ```

3. **Generate target files**:
   ```cmd
   vibe generate
   ```

## Comparison with Unix Installation

| Feature | Windows (cmd.exe) | Unix (bash) |
|---------|-------------------|-------------|
| Install location | `%USERPROFILE%\.local\bin` | `/usr/local/bin` |
| Requires admin | No | Yes (sudo) |
| Hook format | `.bat` | `.sh` |
| Path separator | `\` | `/` |
| Config location | `%USERPROFILE%\.vibe` | `~/.vibe` |

## Corporate Environment Notes

If you're in a restricted corporate environment:

- **PowerShell disabled**: Use the `.bat` scripts (cmd.exe)
- **Ruby not allowed**: Consider requesting Ruby via your IT department, or use WSL2
- **Git Bash available**: Use `vibe-bash.sh` as fallback
- **No admin rights**: Install to user directory (default behavior)

## Support

For issues specific to Windows:

1. Check this guide first
2. Review [TROUBLESHOOTING.md](../docs/troubleshooting.md)
3. Open an issue on GitHub with:
   - Windows version (`ver`)
   - Ruby version (`ruby --version`)
   - Error message
   - Installation method used
