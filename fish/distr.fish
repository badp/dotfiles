function distr
  switch (count $argv)
    case 0 1
      echo "Not enough arguments"
    case '*'
      set file $argv[1]
      set hosts $argv[2..-1]
      set dest '~'
      echo -n '['; printf ' %.0s' $hosts; echo -ne "]\r"
      echo -n '['
      for host in $hosts
        if rsync $file $host':'$dest
          echo -n '.'
        else
          echo -n ':('
          return
        end
      end
  end
  echo
end
