# Deployment Guide

This guide walks you through publishing the Lumina Linux project to your
GitHub repository (`github.com/salom600/links`) and triggering the first
ISO build.

---

## ⚠️ Step 0 — Revoke the leaked token (URGENT)

If you haven't already done so, **revoke the GitHub Personal Access Token
you pasted in chat** before doing anything else:

1. Go to <https://github.com/settings/tokens>
2. Find the token starting with `ghp_NMcLDsNX9ns8...`
3. Click **Revoke**
4. (Optional) Generate a new token with scope `repo` only, and add it as
   a **repository secret** named `GH_TOKEN` if you need it for any future
   cross-repo operations

You do **not** need a Personal Access Token for the build workflow to work.
The workflow uses the built-in `GITHUB_TOKEN` that GitHub provides
automatically to every Actions run.

---

## Step 1 — Extract the project archive

You should have received a file named `lumina-linux-v0.1.0.tar.gz`.
Extract it anywhere you like:

```bash
tar xzf lumina-linux-v0.1.0.tar.gz
cd links
```

You should see the following structure:

```
links/
├── .github/workflows/build-iso.yml
├── airootfs/
├── bootloaders/
├── efiboot/
├── syslinux/
├── scripts/
├── packages.x86_64
├── pacman.conf
├── profiledef.sh
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

---

## Step 2 — Initialize git and commit

If you extracted into a fresh directory, initialize git here. If you
extracted on top of an existing clone of `salom600/links`, skip to step 3.

```bash
cd links
git init -b main
git add .
git commit -m "feat: initial Lumina Linux scaffold (v0.1.0)"
```

---

## Step 3 — Connect to your GitHub repo and push

The repo `https://github.com/salom600/links.git` already exists (it's the
empty one you created). You just need to point your local clone at it
and push:

```bash
git remote add origin https://github.com/salom600/links.git
# Or if you prefer SSH:
# git remote add origin git@github.com:salom600/links.git

git push -u origin main
```

GitHub will prompt you for credentials. **Do NOT paste a Personal Access
Token in plain text anywhere** — use one of these instead:

- **HTTPS with credential helper** (recommended): Install
  [GitHub CLI](https://cli.github.com/) and run `gh auth login`. Git will
  then push without prompting.
- **HTTPS with a Personal Access Token**: Generate a token at
  <https://github.com/settings/tokens> with scope `repo`, then when git
  prompts for a password, paste the token. **Do not save the token in
  any file in the repo.**
- **SSH**: Add an SSH key to your GitHub account
  (<https://github.com/settings/keys>) and use the SSH remote URL.

---

## Step 4 — Trigger the first build

The workflow triggers automatically when you push a tag matching
`v*.*.*`. To build the first ISO:

```bash
git tag -a v0.1.0 -m "First Lumina Linux release"
git push origin v0.1.0
```

Watch the build at: **<https://github.com/salom600/links/actions>**

Expected build time: **45–75 minutes**.

---

## Step 5 — Download the ISO

When the build finishes successfully:

1. Go to **<https://github.com/salom600/links/releases>**
2. Download `lumina-v0.1.0-x86_64.iso` (and the `.sha256sum` file)
3. Verify the checksum:
   ```bash
   sha256sum -c lumina-v0.1.0-x86_64.iso.sha256sum
   ```
4. Write to a USB drive:
   ```bash
   sudo dd if=lumina-v0.1.0-x86_64.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```
   (Replace `/dev/sdX` with your USB device. Use `lsblk` to identify it.)
5. Boot from the USB and click **Install Lumina** on the desktop.

---

## Alternative — Manual workflow dispatch (without tagging)

If you want to test the build without creating a release:

1. Go to **<https://github.com/salom600/links/actions/workflows/build-iso.yml>**
2. Click **Run workflow** → **Run workflow** (on the `main` branch)
3. When the build finishes, the ISO will be available as a **workflow
   artifact** (downloadable from the run's summary page) for 14 days

This does **not** create a GitHub Release — it's a way to iterate on the
build without polluting your release history.

---

## Troubleshooting

### Build fails at "Install build dependencies"

The archlinux Docker image occasionally has transient keyring issues. Wait
5 minutes and re-run the workflow. If it persists, check
<https://status.archlinux.org/> for outages.

### Build fails at "Build AUR packages"

Look for `WARNING:` lines in the workflow log. The script is designed to
skip optional packages on failure. If a critical package (pamac-aur,
paru-bin, fluent-gtk-theme-git) fails, open an issue with the build log
attached.

### Build fails at "Build ISO" (mkarchiso)

Most common cause: a package in `packages.x86_64` doesn't exist in the
official repos and isn't built by the AUR script. Check the log for
`package not found` errors, then edit `packages.x86_64` to remove the
offending package.

### Push fails with "Authentication failed"

You need to authenticate with GitHub. Use `gh auth login` (recommended)
or generate a Personal Access Token with `repo` scope and paste it when
git prompts for a password.

### Push fails with "refusing to allow an OAuth App to create or update workflow"

The default `GITHUB_TOKEN` is enough to run workflows, but to **push**
workflow files you need a token with the `workflow` scope. Generate a
new token at <https://github.com/settings/tokens> with both `repo` and
`workflow` scopes.

---

## Next steps after first successful build

1. **Replace branding assets**: The ISO ships with auto-generated
   placeholders (simple gradients with the Lumina "L" logo). Replace
   the files under `airootfs/usr/share/backgrounds/lumina/` with real
   designs, then tag a new release.

2. **Test the ISO in a VM**: Use VirtualBox, VMware, or GNOME Boxes to
   boot the ISO in a virtual machine before testing on real hardware.

3. **Iterate on packages**: Edit `packages.x86_64` to add/remove apps,
   then tag a new release to rebuild.

4. **Customize the theme**: Edit the files under
   `airootfs/etc/skel/.config/` to change the panel layout, picom effects,
   GTK theme, etc.

5. **Set up issue templates**: Add `.github/ISSUE_TEMPLATE/` to help
   users report bugs.

6. **Set up Discussions**: Enable GitHub Discussions on the repo for
   community Q&A.

---

## Need help?

Open an issue: <https://github.com/salom600/links/issues>
