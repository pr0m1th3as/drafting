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
## @deftypefnx {drafting} {@var{V} =} solid.show (@var{S})
##
## Show a solid, redrawing in place.
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
## @code{@var{V} = solid.show (@var{S})} also returns the viewer, a
## @code{solid.Viewer}.  Assigning to @code{@var{V}.Shape} redraws it at once,
## and @code{solid.Viewer.pick} picks edges and faces with the mouse:
##
## @example
## @group
## part = solid.box (80, 40, 12);
## V = solid.show (part);
## E = pick (V, 'edge');     # click the edges, then press Enter
## V.Shape = fillet (V.Shape, E, 3);
## @end group
## @end example
##
## Calling @code{solid.show (@var{S})} is the same as assigning @var{S} to the
## @code{Shape} of that one viewer.  Nothing else redraws it: changing the
## variable that was shown does not, until it is shown again.
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
  if (! isa (S, 'solid.Shape') || ! isscalar (S))
    error ("solid.show: S must be a solid.Shape object.");
  endif

  ## The one viewer solid.show keeps, its state in the graphics root where it
  ## outlasts clear all
  id = getappdata (0, 'drafting_solid_show');
  if (isempty (id) || isempty (getappdata (0, sprintf ...
                                           ('drafting_solid_viewer_%d', id))))
    viewer = solid.Viewer ();
    setappdata (0, 'drafting_solid_show', viewer.Id);
  else
    viewer = solid.Viewer ('__id__', id);
  endif
  name = inputname (1, false);
  if (isempty (name) || ! isvarname (name))
    name = 'S';
  endif
  viewer.Name = name;
  viewer.Shape = S;

  if (nargout > 0)
    V = viewer;
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
%!   W.Shape = solid.sphere (2);
%!   assert_equal (volume (V.Shape), 32 / 3 * pi, 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%!   setappdata (0, 'drafting_solid_show', old);
%! end_unwind_protect

%!error<solid.show: invalid number of input arguments.> solid.show ()
%!error<solid.show: S must be a solid.Shape object.> solid.show (1)
%!error<solid.show: S must be a solid.Shape object.> solid.show ('part.m')
%!error<solid.show: S must be a solid.Shape object.> ...
%! solid.show ([solid.Shape(), solid.Shape()])
