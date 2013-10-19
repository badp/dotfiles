function graph
  switch (git --version | cut -f3 -d' ' | cut -f1,2 -d.)
    case 1.7
        set -g __fish_graph_pretty "%C(yellow)%h%C(cyan)%d %C(green)%an %C(reset)%s"
    case '*'
        set -g __fish_graph_pretty "%C(yellow)%h%C(auto)%d %C(green)%an %C(reset)%s"
  end

  switch argv
    case s short
      git log -10 \
        --graph \
        --left-right \
        --decorate=full \
        --oneline
    case '*'
      git log \
        --graph \
        --left-right \
        --all \
        --pretty=format:$__fish_graph_pretty
  end
end
