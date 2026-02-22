# Add your own custom plugins in the custom/plugins directory. Plugins placed
# here will override ones with the same name in the main plugins directory.

## Git
alias gcd='git checkout dev'

## Docker
alias doa='docker attach --sig-proxy=false'
alias dcupd='docker-compose up -d'
alias dcc='docker-compose create'
alias dcsa='docker-compose start'
alias dcso='docker-compose stop'
alias artcc='php artisan ide-helper:eloquent && php artisan ide-helper:generate && php artisan ide-helper:meta && php artisan ide-helper:models -N'

## Git
alias gitcleanmerged='gco master && gb -r --merged | egrep -v "(^\*|master|develop|staging)" | sed "s/origin\//:/" | xargs -n 1 git push origin'
alias gitcleanmergedlocal='gco master && gb --merged | egrep -v "(^\*|master|develop|staging)" |  xargs git branch -d'
alias gmtodevelopment='TMPBRANCH=$(git branch --show-current) && gco development && ggpull && gm --no-ff --no-edit $TMPBRANCH'
alias gmtodevelop='TMPBRANCH=$(git branch --show-current) && gco develop && ggpull && gm --no-ff --no-edit $TMPBRANCH'
alias gmtostaging='TMPBRANCH=$(git branch --show-current) && gco staging && ggpull && gm --no-ff --no-edit $TMPBRANCH'
alias gmtomaster='TMPBRANCH=$(git branch --show-current) && gco master && ggpull && gm --no-ff --no-edit $TMPBRANCH'

alias gtlist='git tag -l -n99'


## Custom Alias for GIT
alias gtprune='git tag -l | xargs git tag -d'
alias gtfetch='git fetch --tags'


## Convert private key into single line
#alias keytoline="awk -v ORS='\\n' '1' $1 | pbcopy"

#Subtitle Renamer
alias rename_subtitle="${0:A:h}/rename_subtitles.sh"

#Video Renamer
alias rename_video="${0:A:h}/rename_video.sh"
