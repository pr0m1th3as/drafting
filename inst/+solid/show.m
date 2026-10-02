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


## -*- texinfo -*-
## @deftypefn  {drafting} {} solid.show (@var{S})
## @deftypefnx {drafting} {} solid.show (@var{FILE})
## @deftypefnx {drafting} {@var{V} =} solid.show (@dots{})
##
## Show a solid, redrawing in place as it changes.
##
## @code{solid.show (@var{S})} shows the @code{solid.Shape} @var{S} in the
## viewer, a window drawn by Open CASCADE in a process of its own.  The first
## call opens it.  Every later call redraws the same window in place and keeps
## the camera where it was, so a script that ends by showing its part can be
## run again and again, @code{clear all} and all, and the part changes before
## your eyes.  Drag with the left mouse button to rotate, the middle one to
## pan, and turn the wheel to zoom; @kbd{F} fits the part to the window and
## @kbd{0}, @kbd{1}, @kbd{2} and @kbd{3} turn it to the isometric, front, top
## and right views.
##
## @code{solid.show (@var{FILE})} watches the script @var{FILE}: it runs it
## now, and again every time the file is saved, while Octave waits at its
## prompt.  The script shows its result itself, by ending with a call such
## as @code{solid.show (part)}.  Its variables are made in the base
## workspace, as by @code{run}, so they are there to inspect and to pick on
## between runs.  If a later run fails, the error is printed and shown in the
## viewer, and the last part that built stays on screen until the script is
## fixed.  Closing the viewer stops the watch; watching another script
## replaces it.
##
## @code{@var{V} = solid.show (@dots{})} also returns the viewer, a
## @code{solid.Viewer}, for picking edges and faces with
## @code{solid.Viewer.pick}:
##
## @example
## @group
## part = solid.box (80, 40, 12);
## V = solid.show (part);
## E = pick (V, 'edge');     # click the edges, then press Enter
## part = fillet (part, E, 3);
## solid.show (part);
## @end group
## @end example
##
## The viewer is built with the package when Open CASCADE and X11 are found,
## and needs a display to run.  It runs on Linux.
##
## @seealso{solid.Viewer, solid.Viewer.pick}
## @end deftypefn

function V = show (S)

  ## Input validation
  if (nargin != 1)
    error ("solid.show: invalid number of input arguments.");
  endif

  if (ischar (S))
    if (! isrow (S) || isempty (S))
      error ("solid.show: FILE must be a non-empty character vector.");
    endif
    [~, ~, ext] = fileparts (S);
    if (! strcmp (ext, '.m'))
      error ("solid.show: FILE must be an Octave script ending in .m.");
    endif
    if (! isfile (S))
      error ("solid.show: cannot find file '%s'.", S);
    endif
    file = make_absolute_filename (S);

    ## Run it now; its errors are raised as they would be by run
    w = struct ('file', file, 'hash', hash ('md5', fileread (file)));
    setappdata (0, 'drafting_solid_watch', w);
    unwind_protect
      evalin ('base', sprintf ("run ('%s');", strrep (file, "'", "''")));
      ok = true;
    unwind_protect_cleanup
      if (! exist ('ok', 'var'))
        rmappdata (0, 'drafting_solid_watch');
      endif
    end_unwind_protect
    viewer = current ();
    if (isempty (viewer) || ! isopen (viewer))
      rmappdata (0, 'drafting_solid_watch');
      error (strcat ("solid.show: FILE must show its result by calling", ...
                     " solid.show itself."));
    endif
    if (isempty (getappdata (0, 'drafting_solid_watch_hook')))
      setappdata (0, 'drafting_solid_watch_hook', ...
                  add_input_event_hook (@solid.__watch__));
    endif
  elseif (isa (S, 'solid.Shape') && isscalar (S))
    viewer = current ();
    if (isempty (viewer))
      viewer = solid.Viewer ();
      setappdata (0, 'drafting_solid_show', viewer.Id);
    endif
    name = inputname (1, false);
    if (isempty (name) || ! isvarname (name))
      name = 'S';
    endif
    viewer.Name = name;
    viewer.Shape = S;
  else
    error ("solid.show: S must be a solid.Shape object or a script name.");
  endif

  if (nargout > 0)
    V = viewer;
  endif

endfunction

## The viewer solid.show keeps, or empty before the first call
function V = current ()

  id = getappdata (0, 'drafting_solid_show');
  if (isempty (id) || isempty (getappdata (0, sprintf ...
                                           ('drafting_solid_viewer_%d', id))))
    V = [];
  else
    V = solid.Viewer ('__id__', id);
  endif

endfunction

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## Every call redraws the same viewer, under the variable's name
%! old = getappdata (0, 'drafting_solid_show');
%! V = solid.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_solid_show', V.Id);
%! unwind_protect
%!   part = solid.box (10, 20, 30);
%!   W = solid.show (part);
%!   assert_equal (W.Id, V.Id);
%!   assert_equal (V.Name, 'part');
%!   assert_equal (volume (V.Shape), 6000, 1e-9);
%!   solid.show (solid.cylinder (4, 12));
%!   assert_equal (V.Name, 'S');
%!   assert_equal (volume (V.Shape), 192 * pi, 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%!   setappdata (0, 'drafting_solid_show', old);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## A watched script runs again when it changes, and a failing run leaves
%! ## the last part on screen
%! old = getappdata (0, 'drafting_solid_show');
%! V = solid.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_solid_show', V.Id);
%! f = [tempname(), '.m'];
%! unwind_protect
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "part_9f2c = solid.box (10, 20, 30);\n");
%!   fprintf (fid, "solid.show (part_9f2c);\n");
%!   fclose (fid);
%!   solid.show (f);
%!   assert_equal (volume (V.Shape), 6000, 1e-9);
%!   assert_equal (V.Name, 'part_9f2c');
%!   solid.__watch__ ();
%!   assert_equal (volume (V.Shape), 6000, 1e-9);
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "part_9f2c = solid.box (10, 20, 40);\n");
%!   fprintf (fid, "solid.show (part_9f2c);\n");
%!   fclose (fid);
%!   solid.__watch__ ();
%!   assert_equal (volume (V.Shape), 8000, 1e-9);
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "part_9f2c = solid.box (10, 20, -1);\n");
%!   fprintf (fid, "solid.show (part_9f2c);\n");
%!   fclose (fid);
%!   out = evalc ("solid.__watch__ ();");
%!   assert_equal (strfind (out, 'DZ must be a positive') > 0, true);
%!   assert_equal (volume (V.Shape), 8000, 1e-9);
%!   ## Closing the viewer ends the watch
%!   close (V);
%!   solid.__watch__ ();
%!   assert_equal (isempty (getappdata (0, 'drafting_solid_watch')), true);
%!   assert_equal (isempty (getappdata (0, 'drafting_solid_watch_hook')), true);
%! unwind_protect_cleanup
%!   close (V);
%!   unlink (f);
%!   evalin ('base', 'clear part_9f2c');
%!   setappdata (0, 'drafting_solid_show', old);
%!   if (isappdata (0, 'drafting_solid_watch'))
%!     rmappdata (0, 'drafting_solid_watch');
%!   endif
%!   if (isappdata (0, 'drafting_solid_watch_hook'))
%!     remove_input_event_hook (getappdata (0, 'drafting_solid_watch_hook'));
%!     rmappdata (0, 'drafting_solid_watch_hook');
%!   endif
%! end_unwind_protect

%!error<solid.show: invalid number of input arguments.> solid.show ()
%!error<solid.show: S must be a solid.Shape object or a script name.> ...
%! solid.show (1)
%!error<solid.show: S must be a solid.Shape object or a script name.> ...
%! solid.show ([solid.Shape(), solid.Shape()])
%!error<solid.show: FILE must be a non-empty character vector.> solid.show ('')
%!error<solid.show: FILE must be an Octave script ending in .m.> ...
%! solid.show ('part.step')
%!error<solid.show: cannot find file 'no_such_script_9f2c.m'.> ...
%! solid.show ('no_such_script_9f2c.m')
%!error<solid.show: FILE must show its result by calling solid.show itself.>
%! f = [tempname(), '.m'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "x_9f2c = 1;\n");
%! fclose (fid);
%! unwind_protect
%!   solid.show (f);
%! unwind_protect_cleanup
%!   unlink (f);
%!   evalin ('base', 'clear x_9f2c');
%! end_unwind_protect
