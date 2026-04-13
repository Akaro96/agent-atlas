# Publishing Checklist

Use this before creating the public repository or tagging a release.

## Content

- [ ] README is accurate
- [ ] Quickstart still works
- [ ] comparison claims are still fair
- [ ] examples still match the templates

## Privacy

- [ ] validator passes
- [ ] no personal usernames in tracked files
- [ ] no absolute local personal paths in tracked files
- [ ] no private history or state files were added

## Maintainer Hygiene

- [ ] CONTRIBUTING.md is up to date
- [ ] SECURITY.md is up to date
- [ ] SUPPORT.md is up to date
- [ ] issue templates still reflect the current workflow
- [ ] Dependabot is enabled for the public repository
- [ ] CODEOWNERS still matches the real public maintainer handle or team
- [ ] branch protection is enabled on the default branch after publish

## Technical

- [ ] install script works in a clean temp directory
- [ ] project bootstrap script works in a clean temp directory
- [ ] generated Codex config parses
- [ ] generated Claude settings parse
- [ ] generated Obsidian vault opens with sane defaults
- [ ] scenario simulations pass
