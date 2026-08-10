### Instructions

1. checkout/clone this repository into `~/development/dotfiles/`
   - I updated this on 2026-04-23 since I think it allows for better consistency between file systems
2. create a symlink into your home folder by running: `ln -s -f ~/development/dotfiles/.bash_aliases ~/.bash_aliases`
   - `ln` command creates a link
   - `-s` flag indicates that the link is symbolic (it acts as a pointer/reference instead of as a copy)
   - `-f` flag overwrites the destination path of the symlink if a file already exists there (BE CAREFUL -- THIS CAN BE DESTRUCTIVE)
   - `~/development/dotfiles` is the directory that the repo lives at
   - `~/` is the home directory, where your shell looks for dotfiles
3. make sure to update your source

#### Claude

1. Create the directory for skills if you don't have it: `mkdir -p ~/development/dotfiles/.claude/skills`
2. [Optional] Check what exists already in your `~/.claude`. You may want to back up your contents
   - `ls ~/.claude`
   - `ls ~/.claude/skills`
3. Create the symlinks: 
   - `ln -s ~/development/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md`
   - `ln -s ~/development/dotfiles/.claude/settings.json ~/.claude/settings.json`
   - `ln -s ~/development/dotfiles/.claude/skills/napkin ~/.claude/skills/napkin`

#### Zed

1. [Optional] Back up what's there already: `cp ~/.config/zed/settings.json ~/.config/zed/keymap.json /some/backup/dir/`
2. Create the symlinks:
   - `ln -s -f ~/development/dotfiles/.config/zed/settings.json ~/.config/zed/settings.json`
   - `ln -s -f ~/development/dotfiles/.config/zed/keymap.json ~/.config/zed/keymap.json`

Link the two files individually rather than the whole `~/.config/zed/` directory —
Zed also writes caches, logs, and a `prompts/` LMDB database of AI prompt history
into that directory, none of which should be in a public repo.

Repo-specific Zed config (formatters, linters, language servers) does not belong
here. It goes in that repo's own `.zed/settings.json`, which Zed layers on top of
these settings.


### Alternatively, per "the hacker news way"

- https://news.ycombinator.com/item?id=11071754
- https://www.atlassian.com/git/tutorials/dotfiles

1. Run the following

```
git clone --bare https://github.com/raistlan/dotfiles $HOME/.dotfiles
function config {
   /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $@
}
mkdir -p .dotfiles-backup
config checkout
if [ $? = 0 ]; then
  echo "Checked out dotfiles.";
  else
    echo "Backing up pre-existing dot files.";
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .dotfiles-backup/{}
fi;
config checkout
config config status.showUntrackedFiles no
```

2. Make sure to source each of your files ie `source .bash_aliases`
