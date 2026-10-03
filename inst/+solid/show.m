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
## @deftypefnx {drafting} {} solid.show (@var{M})
## @deftypefnx {drafting} {@var{V} =} solid.show (@dots{})
##
## Show a solid or a mesh in a viewer of its own, redrawing in place.
##
## @code{solid.show (@var{S})} shows the @code{solid.Shape} @var{S} in a
## viewer, a window drawn by Open CASCADE in a process of its own.  Every
## variable gets a viewer of its own, titled with its name: the first
## @code{solid.show (part)} opens the window for @code{part}, and every later
## one redraws that window in place and keeps the camera where it was, while
## @code{solid.show (tool)} uses another.  So a script that ends by showing
## its parts can be run again and again, @code{clear all} and all, and each
## part changes in its own window.  A shape given as an expression rather than
## a variable, such as @code{solid.show (fillet (part, E, 3))}, has no name,
## and all such shapes share one window.
##
## Drag with the left mouse button to rotate, the middle one to pan, and turn
## the wheel to zoom; @kbd{F} fits the part to the window and @kbd{0},
## @kbd{1}, @kbd{2} and @kbd{3} turn it to the isometric, front, top and right
## views.  Closing a window ends its viewer, and the next
## @code{solid.show} of that variable opens a new one.  Showing the empty
## shape opens a variable's window before there is anything to draw in it.
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
## @code{solid.show (@var{M})} shows the triangle mesh @var{M}, a struct
## with the fields @code{vertices} and @code{faces} as @code{polymesh.read}
## returns it, in the same way, shaded facet by facet.  A coordinate system picked on
## it with @code{solid.Viewer.pickucs} is the plane to cut it with
## @code{polymesh.section}:
##
## @example
## @group
## M = polymesh.read ('bracket.stl');
## V = solid.show (M);
## U = pickucs (V);          # click a facet, then two points
## R = polymesh.section (M, U);
## @end group
## @end example
##
## Calling @code{solid.show (@var{S})} is the same as assigning @var{S} to the
## @code{Shape} of the variable's viewer.  Nothing else redraws it: changing
## the variable that was shown does not, until it is shown again.
##
## The viewer is built with the package when Open CASCADE and X11 are found,
## and needs a display to run.  It runs on Linux.
##
## @seealso{solid.Viewer, solid.Viewer.pick, polymesh.read, polymesh.section}
## @end deftypefn

function V = show (S)

  ## Input validation
  if (nargin != 1)
    error ("solid.show: invalid number of input arguments.");
  endif
  ismesh = isstruct (S) && isscalar (S) && isfield (S, 'vertices') ...
           && isfield (S, 'faces') && solid.Viewer.__ismesh__ (S);
  if (! ismesh && (! isa (S, 'solid.Shape') || ! isscalar (S)))
    error (strcat ("solid.show: S must be a solid.Shape object or a mesh", ...
                   " struct with vertices and faces."));
  endif

  ## A viewer for each variable name, and one for shapes without a name, kept
  ## in the graphics root where they outlast clear all
  name = inputname (1, false);
  if (isempty (name) || ! isvarname (name))
    name = '';
    key = 'unnamed';
  else
    key = ['v_' name];
  endif
  ids = getappdata (0, 'drafting_solid_show');
  if (! isstruct (ids))
    ids = struct ();
  endif
  if (isfield (ids, key)
      && ! isempty (getappdata (0, sprintf ('drafting_solid_viewer_%d', ...
                                            ids.(key)))))
    viewer = solid.Viewer ('__id__', ids.(key));
  else
    viewer = solid.Viewer ();
    ids.(key) = viewer.Id;
    setappdata (0, 'drafting_solid_show', ids);
  endif
  if (! isempty (name))
    viewer.Name = name;
  endif
  viewer.Shape = S;

  if (nargout > 0)
    V = viewer;
  endif

endfunction

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## Each variable has a viewer of its own, titled with its name, and shapes
%! ## without a name share one
%! old = getappdata (0, 'drafting_solid_show');
%! VA = solid.Viewer ('Hidden', true);
%! VB = solid.Viewer ('Hidden', true);
%! VU = solid.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_solid_show', struct ('v_part_a', VA.Id, ...
%!                                               'v_part_b', VB.Id, ...
%!                                               'unnamed', VU.Id));
%! unwind_protect
%!   part_a = solid.box (10, 20, 30);
%!   part_b = solid.cylinder (4, 12);
%!   W = solid.show (part_a);
%!   assert_equal (W.Id, VA.Id);
%!   solid.show (part_b);
%!   solid.show (solid.sphere (2));
%!   assert_equal (volume (VA.Shape), 6000, 1e-9);
%!   assert_equal (volume (VB.Shape), 192 * pi, 1e-9);
%!   assert_equal (volume (VU.Shape), 32 / 3 * pi, 1e-9);
%!   assert_equal (VA.Name, 'part_a');
%!   assert_equal (VA.__title__ (), 'part_a (drafting)');
%!   assert_equal (VB.__title__ (), 'part_b (drafting)');
%!   assert_equal (VU.Name, 'S');
%!   assert_equal (VU.__title__ (), 'drafting');
%!   ## Showing a variable again redraws its own window
%!   part_a = solid.box (10, 20, 40);
%!   solid.show (part_a);
%!   assert_equal (volume (VA.Shape), 8000, 1e-9);
%!   assert_equal (volume (VB.Shape), 192 * pi, 1e-9);
%! unwind_protect_cleanup
%!   close (VA);
%!   close (VB);
%!   close (VU);
%!   setappdata (0, 'drafting_solid_show', old);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## A mesh is shown in its variable's window like a solid
%! old = getappdata (0, 'drafting_solid_show');
%! VM = solid.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_solid_show', struct ('v_mesh', VM.Id));
%! unwind_protect
%!   mesh = struct ('vertices', [0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1], ...
%!                  'faces', [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4]);
%!   solid.show (mesh);
%!   assert_equal (VM.Shape, mesh);
%!   assert_equal (VM.__title__ (), 'mesh (drafting)');
%! unwind_protect_cleanup
%!   close (VM);
%!   setappdata (0, 'drafting_solid_show', old);
%! end_unwind_protect

%!error<solid.show: invalid number of input arguments.> solid.show ()
%!error<solid.show: S must be a solid.Shape object or a mesh struct with vertices and faces.> solid.show (1)
%!error<solid.show: S must be a solid.Shape object or a mesh struct with vertices and faces.> ...
%! solid.show (struct ('vertices', [0, 0, 0], 'faces', [1, 2, 3]))
%!error<solid.show: S must be a solid.Shape object or a mesh struct with vertices and faces.> solid.show ('part.m')
%!error<solid.show: S must be a solid.Shape object or a mesh struct with vertices and faces.> ...
%! solid.show ([solid.Shape(), solid.Shape()])
