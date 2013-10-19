function fish_prompt --description 'Write out the prompt'

  if not set -q __fish_prompt_hostname
    set -g __fish_prompt_hostname (hostname -s)
  end

  if not set -q __fish_prompt_normal
    set -g __fish_prompt_normal (set_color normal)
  end

  if [ "$USER" = "rsanti" ]
    set -g __fish_user ""
  else
    set -g __fish_user (set_color yellow)"$USER$__fish_prompt_normal@"
  end

  switch $__fish_prompt_hostname
    case rsanti0
      set -g __fish_machine ""
    case rsanti-alpha
      set -g __fish_machine (set_color cyan)"@$__fish_prompt_hostname$__fish_prompt_normal"
    case '*'
      set -g __fish_machine (set_color red)"@$__fish_prompt_hostname$__fish_prompt_normal"
  end

  if not set -q __fish_prompt_cwd
    set -g __fish_prompt_cwd (set_color $fish_color_cwd)
  end

  if not set -q __fish_prompt_schroot
    set -g __fish_prompt_schroot (set_color $fish_color_param[1])
  end

  if not set -qg SCHROOT_CHROOT_NAME
    set -g __fish_schroot ""
  else
    set -g __fish_schroot ":"(set_color yellow)"$SCHROOT_CHROOT_NAME"
  end


  echo -n -s "$__fish_user" \
             "$__fish_machine" \
             "$__fish_schroot" \
             "$__fish_prompt_normal:" \
             "$__fish_prompt_cwd" \
             (prompt_pwd) \
             (__fish_git_prompt) \
             "$__fish_prompt_normal" \
             '> '

end
