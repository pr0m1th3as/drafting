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
## @deftypefn  {drafting} {@var{P} =} geom.intersectlines (@var{A}, @var{B})
## @deftypefnx {drafting} {[@var{P}, @var{TA}, @var{TB}] =} geom.intersectlines (@var{A}, @var{B})
##
## Where two lines cross.
##
## @code{@var{P} = geom.intersectlines (@var{A}, @var{B})} returns the point at
## which the lines through @var{A} and @var{B} meet.  Each line is given as a
## 2-by-2 matrix holding two points on it, one per row.  @var{P} is empty when
## the lines are parallel.
##
## @code{[@var{P}, @var{TA}, @var{TB}] = geom.intersectlines (@dots{})} also
## returns where the crossing falls along each line, as a fraction of the
## distance from its first point to its second.  @code{@var{TA} = 0} is
## @code{@var{A}(1,:)} and @code{@var{TA} = 1} is @code{@var{A}(2,:)}.
##
## @subheading Lines, not segments --- and why the parameters are returned
##
## The lines are treated as infinite, which is what construction geometry
## wants: a corner is filleted, a centre line extended, a bisector dropped, all
## from lines whose given points rarely reach the crossing.
##
## A caller wanting @emph{segments} tests the parameters: the segments cross
## when both @var{TA} and @var{TB} lie between 0 and 1.  Returning them costs
## nothing and lets one function serve both questions, rather than having two
## that differ in a detail easily forgotten.
##
## @subheading Collinear lines
##
## Two collinear lines meet everywhere, not somewhere, so @var{P} is empty for
## them as it is for parallel ones.  A caller who must tell the two apart can
## test whether a point of one lies on the other.
##
## @seealso{geom.intersectcircle, geom.intersectcircles, geom.fillet}
## @end deftypefn

function [P, TA, TB] = intersectlines (A, B)

  ## Input validation
  if (nargin != 2)
    error ("geom.intersectlines: invalid number of input arguments.");
  endif
  A = checkline (A, 'A');
  B = checkline (B, 'B');

  r = A(2,:) - A(1,:);
  s = B(2,:) - B(1,:);
  d = r(1) * s(2) - r(2) * s(1);

  if (d == 0)
    P = zeros (0, 2);
    TA = [];
    TB = [];
    return;
  endif

  q = B(1,:) - A(1,:);
  TA = (q(1) * s(2) - q(2) * s(1)) / d;
  TB = (q(1) * r(2) - q(2) * r(1)) / d;
  P = A(1,:) + TA * r;

endfunction

## A line is two distinct points, one per row
function L = checkline (L, name)

  if (! isnumeric (L) || ! isreal (L) || ! isequal (size (L), [2, 2]) ...
      || ! all (isfinite (L(:))))
    error (strcat ("geom.intersectlines: %s must be a 2-by-2 matrix of two", ...
                   " real finite points."), name);
  endif
  if (isequal (L(1,:), L(2,:)))
    error (strcat ("geom.intersectlines: %s must be two distinct points;", ...
                   " a single point names no line."), name);
  endif

endfunction

%!demo
%! ## The lines are infinite, which is what construction geometry wants: the
%! ## crossing is usually nowhere near the points that define the lines.
%!
%! A = [0, 0; 30, 12];
%! B = [60, 0; 60, 40];
%! [P, TA, TB] = geom.intersectlines (A, B)
%!
%! D = draw.Drawing ();
%! D.Linetype = 'PHANTOM';
%! D = D.line (A(1,:), P).line (B(1,:), P);
%! D.Linetype = 'CONTINUOUS';
%! D = D.line (A(1,:), A(2,:)).line (B(1,:), B(2,:));
%! D.Colour = 'red';
%! D = D.circle (P, 2);
%! draw.plot (D);
%! title ('the crossing lies beyond both given segments');

%!demo
%! ## The parameters say where along each line the crossing falls, so one
%! ## function answers both the line question and the segment question: the
%! ## segments cross when both lie between 0 and 1.
%!
%! [P, TA, TB] = geom.intersectlines ([0, 0; 20, 0], [10, -5; 10, 5]);
%! crossed = TA >= 0 && TA <= 1 && TB >= 0 && TB <= 1
%!
%! [P, TA, TB] = geom.intersectlines ([0, 0; 5, 0], [10, -5; 10, 5]);
%! crossed = TA >= 0 && TA <= 1 && TB >= 0 && TB <= 1

%!test  # two lines crossing at the origin
%! P = geom.intersectlines ([-1, 0; 1, 0], [0, -1; 0, 1]);
%! assert_equal (P, [0, 0], 1e-12);

%!test  # the parameters say where along each line the crossing falls
%! [P, TA, TB] = geom.intersectlines ([0, 0; 10, 0], [4, -2; 4, 2]);
%! assert_equal (P, [4, 0], 1e-12);
%! assert_equal (TA, 0.4, 1e-12);
%! assert_equal (TB, 0.5, 1e-12);

%!test  # the lines are infinite, so a crossing beyond the given points is found
%! [P, TA] = geom.intersectlines ([0, 0; 1, 0], [10, -1; 10, 1]);
%! assert_equal (P, [10, 0], 1e-12);
%! assert_equal (TA, 10, 1e-12);

%!test  # segments are tested by the parameters, which is the intended use
%! [P, TA, TB] = geom.intersectlines ([0, 0; 1, 0], [10, -1; 10, 1]);
%! assert_equal (TA >= 0 && TA <= 1 && TB >= 0 && TB <= 1, false);
%! [P, TA, TB] = geom.intersectlines ([0, 0; 20, 0], [10, -1; 10, 1]);
%! assert_equal (TA >= 0 && TA <= 1 && TB >= 0 && TB <= 1, true);

%!test  # parallel lines do not meet
%! [P, TA, TB] = geom.intersectlines ([0, 0; 1, 0], [0, 5; 1, 5]);
%! assert_equal (isempty (P), true);
%! assert_equal (isempty (TA), true);

%!test  # collinear lines meet everywhere, so nowhere in particular
%! P = geom.intersectlines ([0, 0; 1, 0], [5, 0; 6, 0]);
%! assert_equal (isempty (P), true);

%!test  # an oblique crossing, checked against hand geometry
%! P = geom.intersectlines ([0, 0; 4, 4], [0, 4; 4, 0]);
%! assert_equal (P, [2, 2], 1e-12);

%!test  # the answer does not depend on which line is given first
%! A = [0, 0; 3, 5];
%! B = [1, 7; 6, -2];
%! assert_equal (geom.intersectlines (A, B), geom.intersectlines (B, A), 1e-12);

%!test  # nor on the direction each is given in
%! A = [0, 0; 3, 5];
%! B = [1, 7; 6, -2];
%! assert_equal (geom.intersectlines (A, B), ...
%!               geom.intersectlines (flipud (A), flipud (B)), 1e-12);

%!error<geom.intersectlines: invalid number of input arguments.> ...
%! geom.intersectlines ([0, 0; 1, 1])
%!error<geom.intersectlines: A must be a 2-by-2 matrix of two real finite points.> ...
%! geom.intersectlines ([0, 0; 1, 1; 2, 2], [0, 0; 1, 0])
%!error<geom.intersectlines: B must be a 2-by-2 matrix of two real finite points.> ...
%! geom.intersectlines ([0, 0; 1, 1], [0, 0; Inf, 0])
%!error<geom.intersectlines: A must be two distinct points; a single point names no line.> ...
%! geom.intersectlines ([2, 3; 2, 3], [0, 0; 1, 0])
