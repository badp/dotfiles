function log
  git show-branch --color --current --topo-order --more=5 \
    (git rev-parse --abbrev-ref --symbolic-full-name "@{u}")
end
