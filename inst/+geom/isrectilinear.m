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
## @deftypefn  {drafting} {@var{TF} =} geom.isrectilinear (@var{P})
## @deftypefnx {drafting} {@var{TF} =} geom.isrectilinear (@var{P}, @var{TOL})
##
## True when every edge of a polygon is parallel to an axis.
##
## @code{@var{TF} = geom.isrectilinear (@var{P})} returns @code{true} when every
## edge of the polygon @var{P} runs parallel to either the @math{x} or the
## @math{y} axis, and @code{false} otherwise.  The polygon is implicitly closed,
## so the edge joining the last vertex to the first is tested as well.
##
## @code{@var{TF} = geom.isrectilinear (@var{P}, @var{TOL})} uses @var{TOL} as
## the absolute tolerance, in the units of @var{P}, on the off-axis component of
## each edge.  @var{TOL} defaults to @code{1e-6}, that is one micrometre at the
## package's millimetre convention.  The default is deliberately looser than
## machine precision: coordinates that have been through a rotation, or that
## arrive from a CAD package, carry accumulated rounding that an exact test
## would reject.
##
## This is the gate for @code{geom.offset} and @code{geom.largestrect}, both of
## which are exact only on rectilinear outlines.  A building outline of the kind
## those functions serve is a rectangle in the great majority of cases and an L
## shape in most of the rest.
##
## A zero-length edge counts as axis-parallel, since it has no direction to
## disagree with.
##
## @seealso{geom.offset, geom.largestrect, geom.signedarea}
## @end deftypefn

function TF = isrectilinear (P, TOL = 1e-6)

  ## Input validation
  if (nargin < 1)
    error ("geom.isrectilinear: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.isrectilinear: %s", errmsg);
  endif
  if (! isnumeric (TOL) || ! isreal (TOL) || ! isscalar (TOL) ...
      || ! isfinite (TOL) || TOL < 0)
    error (strcat ("geom.isrectilinear: TOL must be a non-negative", ...
                   " real finite scalar."));
  endif

  ## Edge vectors around the closed ring
  D = [P(2:end,:); P(1,:)] - P;

  ## An edge is axis-parallel when one of its components vanishes
  TF = all (abs (D(:,1)) <= TOL | abs (D(:,2)) <= TOL);

endfunction

%!assert (geom.isrectilinear ([0, 0; 1, 0; 1, 1; 0, 1]), true)
%!assert (geom.isrectilinear ([0, 0; 4, 0; 0, 3]), false)

%!test  # L-shaped outline
%! P = [0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4];
%! assert_equal (geom.isrectilinear (P), true);

%!test  # the closing edge is tested too
%! P = [0, 0; 4, 0; 4, 3; 1, 3; 1, 1];
%! assert_equal (geom.isrectilinear (P), false);

%!test  # explicitly closed input behaves identically
%! P = [0, 0; 1, 0; 1, 1; 0, 1; 0, 0];
%! assert_equal (geom.isrectilinear (P), true);

%!test  # CAD-scale rounding passes under the default tolerance
%! P = [0, 0; 1600, 1e-9; 1600, 1800; 0, 1800];
%! assert_equal (geom.isrectilinear (P), true);

%!test  # but not under an exact tolerance
%! P = [0, 0; 1600, 1e-9; 1600, 1800; 0, 1800];
%! assert_equal (geom.isrectilinear (P, 0), false);

%!test  # a generous tolerance accepts a genuinely skewed edge
%! P = [0, 0; 1600, 5; 1600, 1800; 0, 1800];
%! assert_equal (geom.isrectilinear (P), false);
%! assert_equal (geom.isrectilinear (P, 10), true);

%!test  # a zero-length edge is not a disqualification
%! P = [0, 0; 1, 0; 1, 0; 1, 1; 0, 1];
%! assert_equal (geom.isrectilinear (P), true);

%!error<geom.isrectilinear: invalid number of input arguments.> ...
%! geom.isrectilinear ()
%!error<geom.isrectilinear: P must be a polygon with at least 3 vertices.> ...
%! geom.isrectilinear ([0, 0; 1, 1])
%!error<geom.isrectilinear: TOL must be a non-negative real finite scalar.> ...
%! geom.isrectilinear ([0, 0; 1, 0; 1, 1], -1)
%!error<geom.isrectilinear: TOL must be a non-negative real finite scalar.> ...
%! geom.isrectilinear ([0, 0; 1, 0; 1, 1], [1, 2])
%!error<geom.isrectilinear: TOL must be a non-negative real finite scalar.> ...
%! geom.isrectilinear ([0, 0; 1, 0; 1, 1], Inf)
