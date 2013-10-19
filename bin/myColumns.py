#!/usr/bin/python3

import os, sys, subprocess, pprint

def arrangeDataInRows(data, height, max_width, sep_width = 2):
  #bundle lines
  data_copy = data[:]
  width_left = max_width
  data_left = data
  columns = []
  while data_left:
    column = data[:height]
    blanks = height - len(column)
    if blanks > 0:
      column += [""]*(blanks)
    column_width = max(map(len, column))
    column = [x + " "*(column_width-len(x)) for x in column]
    width_left -= column_width + sep_width
    if width_left <= 0:
      return arrangeDataInRows(data_copy, height + 1, max_width, sep_width)
    columns.append(column)
    del data[:height]
  #we can do this! but first we have to pad the columns
  rows = map(list, zip(*columns))
  col_sep = " "*sep_width
  output = "\n".join(col_sep.join(row) for row in rows) + "\n"
  smart_print(output, globals()["height"])

def getTerminalSize():
    import os
    env = os.environ
    def ioctl_GWINSZ(fd):
        try:
            import fcntl, termios, struct, os
            cr = struct.unpack('hh', fcntl.ioctl(fd, termios.TIOCGWINSZ,
        '1234'))
        except:
            return
        return cr
    cr = ioctl_GWINSZ(0) or ioctl_GWINSZ(1) or ioctl_GWINSZ(2)
    if not cr:
        try:
            fd = os.open(os.ctermid(), os.O_RDONLY)
            cr = ioctl_GWINSZ(fd)
            os.close(fd)
        except:
            pass
    if not cr:
        cr = (env.get('LINES', 25), env.get('COLUMNS', 80))

        ### Use get(key[, default]) instead of a try/catch
        #try:
        #    cr = (env['LINES'], env['COLUMNS'])
        #except:
        #    cr = (25, 80)
    return int(cr[1]), int(cr[0])

def smart_print(text, terminal_height):
  if len(text.splitlines()) <= terminal_height:
    sys.stdout.buffer.write(text.encode("utf-8"))
  else:
    less = subprocess.Popen("less", stdin = subprocess.PIPE)
    less.stdin.write(text.encode("utf-8"))
    less.stdin.close()
    less.wait()

data = sys.stdin.buffer.read().decode("utf-8").splitlines()
width, height = getTerminalSize()
#deal with excessively long lines
max_width = (width-8)//4


data = [x if len(x) < max_width else x[:max_width-1] + "\N{HORIZONTAL ELLIPSIS}" for x in data]
arrangeDataInRows(data, 1, width)
