## Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the drafting package for GNU Octave.
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.


## Internal helper.  The input event hook behind solid.show (FILE): while
## Octave waits at its prompt, run the watched script again whenever its text
## has changed.
##
## An error in the script is printed and shown in the viewer rather than
## raised, so the watch carries on and the last part that built stays on
## screen.  The watch ends when the viewer is closed.

function __watch__ ()

  w = getappdata (0, 'drafting_solid_watch');
  if (isempty (w))
    return;
  endif
  id = getappdata (0, 'drafting_solid_show');
  V = [];
  if (! isempty (id))
    V = solid.Viewer ('__id__', id);
  endif
  if (isempty (V) || ! isopen (V))
    rmappdata (0, 'drafting_solid_watch');
    hook = getappdata (0, 'drafting_solid_watch_hook');
    if (! isempty (hook))
      remove_input_event_hook (hook);
      rmappdata (0, 'drafting_solid_watch_hook');
    endif
    return;
  endif

  try
    h = hash ('md5', fileread (w.file));
  catch
    return;
  end_try_catch
  if (strcmp (h, w.hash))
    return;
  endif
  w.hash = h;
  setappdata (0, 'drafting_solid_watch', w);

  try
    evalin ('base', sprintf ("run ('%s');", strrep (w.file, "'", "''")));
    message (V, '');
  catch err
    [~, name, ext] = fileparts (w.file);
    printf ("solid.show: %s%s: %s\n", name, ext, err.message);
    message (V, sprintf ("%s%s: %s", name, ext, err.message));
  end_try_catch

endfunction
