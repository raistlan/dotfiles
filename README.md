### Instructions

1. checkout/clone this repository into `~/dotfiles/`
2. create a symlink into your home folder by running: `ln -s -f ~/dotfiles/ ~/`
   - `ln` command creates a link
   - `-s` flag indicates that the link is symbolic (it acts as a pointer/reference instead of as a copy)
   - `-f` flag overwrites the destination path of the symlink if a file already exists there (BE CAREFUL -- THIS CAN BE DESTRUCTIVE)
   - `~/dotfiles` is the directory that the repo lives at
   - `~/` is the home directory, where your shell looks for dotfiles
3. make sure to update your source

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
