# GIT
#
# fco - checkout git branch/tag
fco() {
  local branches branch
  branches=$(git --no-pager branch) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}


cdf() {
  cd $(find * -type d | fzf)
}
