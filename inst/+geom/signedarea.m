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
## @deftypefn {drafting} {@var{A} =} geom.signedarea (@var{P})
##
## Signed area of a simple polygon.
##
## @code{@var{A} = geom.signedarea (@var{P})} returns the signed area of the
## polygon whose vertices are the rows of the @math{N}-by-2 matrix @var{P}, in
## the square of the unit of @var{P}.  Package convention is millimetres, so
## the area is in square millimetres.
##
## The polygon is implicitly closed: the last vertex joins the first.  An
## explicitly repeated closing vertex is accepted and ignored.
##
## The sign carries the orientation.  @var{A} is positive when the vertices run
## counter-clockwise and negative when they run clockwise, so
## @code{sign (geom.signedarea (@var{P}))} is the cheapest orientation test
## available, and @code{abs} of the result is the plain area.
##
## The result is meaningful only for a @emph{simple} polygon, that is, one whose
## edges do not cross.  Self-intersecting input returns a number, but not one
## that means anything.
##
## @seealso{geom.bbox, geom.centroid, geom.isrectilinear}
## @end deftypefn

function A = signedarea (P)

  ## Input validation
  if (nargin != 1)
    error ("geom.signedarea: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.signedarea: %s", errmsg);
  endif

  ## Shoelace formula over the closed vertex ring
  x = P(:,1);
  y = P(:,2);
  xNext = [x(2:end); x(1)];
  yNext = [y(2:end); y(1)];
  A = sum (x .* yNext - xNext .* y) / 2;

endfunction

%!demo
%! ## The sign carries the orientation, so `sign (geom.signedarea (P))` is the
%! ## cheapest orientation test there is, and `abs` of it is the plain area.
%!
%! P = [0, 0; 40, 0; 40, 30; 0, 30];
%! geom.signedarea (P)                 # counter-clockwise: positive
%! geom.signedarea (flipud (P))        # clockwise: negative
%!
%! ## An L-shape, whose area is not its bounding box
%! L = [0, 0; 40, 0; 40, 15; 20, 15; 20, 30; 0, 30];
%! geom.signedarea (L)

%!test  # counter-clockwise unit square
%! assert_equal (geom.signedarea ([0, 0; 1, 0; 1, 1; 0, 1]), 1);

%!test  # clockwise unit square is the negative
%! assert_equal (geom.signedarea ([0, 0; 0, 1; 1, 1; 1, 0]), -1);

%!test  # explicitly closed input gives the same answer
%! P = [0, 0; 1, 0; 1, 1; 0, 1; 0, 0];
%! assert_equal (geom.signedarea (P), 1);

%!test  # rectangle in millimetres
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! assert_equal (geom.signedarea (P), 2880000);

%!test  # triangle
%! assert_equal (geom.signedarea ([0, 0; 4, 0; 0, 3]), 6);

%!test  # translation invariance
%! P = [0, 0; 4, 0; 4, 3; 0, 3];
%! assert_equal (geom.signedarea (P + 1000), geom.signedarea (P), 1e-9);

%!test  # L-shaped rectilinear polygon
%! P = [0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4];
%! assert_equal (geom.signedarea (P), 12);

%!test  # degenerate collinear polygon has zero area
%! assert_equal (geom.signedarea ([0, 0; 1, 0; 2, 0]), 0);

%!error<geom.signedarea: invalid number of input arguments.> geom.signedarea ()
%!error<geom.signedarea: P must be a real numeric matrix.> geom.signedarea ('a')
%!error<geom.signedarea: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.signedarea ([1, 2, 3])
%!error<geom.signedarea: P must not contain NaN or Inf values.> ...
%! geom.signedarea ([0, 0; 1, 0; NaN, 1])
%!error<geom.signedarea: P must be a polygon with at least 3 vertices.> ...
%! geom.signedarea ([0, 0; 1, 1])
