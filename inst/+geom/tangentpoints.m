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
## @deftypefn {drafting} {@var{P} =} geom.tangentpoints (@var{C}, @var{R}, @var{Q})
##
## Where the tangents from a point touch a circle.
##
## @code{@var{P} = geom.tangentpoints (@var{C}, @var{R}, @var{Q})} returns the
## points at which the two lines through @var{Q} touch the circle of radius
## @var{R} centred at @var{C}.  @var{P} has two rows when @var{Q} lies outside
## the circle and one when it lies on it, that one being @var{Q} itself.
##
## Drawing the tangent from a point is how a belt is laid onto a pulley, a
## chamfer run out to a face, a leader taken to a hole without crossing it, and
## how the flanks of a slot meet its ends.
##
## @subheading A point inside the circle raises
##
## No line through a point inside a circle can touch it: every such line cuts
## it twice.  There is no answer to return, so this raises rather than handing
## back an empty result that would read as "none happen to exist here".
##
## @seealso{geom.intersectcircle, geom.intersectcircles, geom.fillet}
## @end deftypefn

function P = tangentpoints (C, R, Q)

  ## Input validation
  if (nargin != 3)
    error ("geom.tangentpoints: invalid number of input arguments.");
  endif
  if (! isnumeric (C) || ! isreal (C) || ! isequal (size (C), [1, 2]) ...
      || ! all (isfinite (C)))
    error ("geom.tangentpoints: C must be a 1-by-2 real finite point.");
  endif
  if (! isnumeric (Q) || ! isreal (Q) || ! isequal (size (Q), [1, 2]) ...
      || ! all (isfinite (Q)))
    error ("geom.tangentpoints: Q must be a 1-by-2 real finite point.");
  endif
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R <= 0)
    error ("geom.tangentpoints: R must be a positive real finite scalar.");
  endif

  v = Q - C;
  d = norm (v);
  tol = 1e-12 * max (R, d);

  if (d < R - tol)
    error (strcat ("geom.tangentpoints: Q is %g mm inside the circle, and", ...
                   " no line through an interior point can be tangent", ...
                   " to it."), ...
           R - d);
  endif

  if (abs (d - R) <= tol)
    P = Q;                              # Q is on the circle; it is the contact
    return;
  endif

  ## The contacts lie on the circle at an angle acos(R/d) either side of the
  ## direction to Q, which is the right-angle triangle C-contact-Q
  a = atan2 (v(2), v(1));
  b = acos (R / d);
  P = [C + R * [cos(a + b), sin(a + b)]; C + R * [cos(a - b), sin(a - b)]];

endfunction

%!demo
%! ## The tangent from a point is how a belt is laid onto a pulley, or a leader
%! ## taken to a hole without crossing it.  The radius to each contact meets the
%! ## tangent at a right angle, which is what makes it a tangent.
%!
%! C = [0, 0];
%! R = 20;
%! Q = [70, 30];
%! P = geom.tangentpoints (C, R, Q)
%!
%! D = draw.Drawing ().circle (C, R);
%! D = D.line (Q, P(1,:)).line (Q, P(2,:));
%! ## the radius to each contact, which meets its tangent at a right angle
%! D.Colour = 'red';
%! D = D.line (C, P(1,:)).line (C, P(2,:));
%! draw.plot (D);
%! title ('tangents from a point, with the radii to their contacts');

%!demo
%! ## A belt over two pulleys is four tangents and two arcs.  Here is the open
%! ## belt, taking the outer tangent on each side.
%!
%! C1 = [0, 0];  R1 = 25;
%! C2 = [90, 0]; R2 = 12;
%! ## The outer tangent touches where a circle of the radius difference does
%! T = geom.tangentpoints (C1, R1 - R2, C2);
%! D = draw.Drawing ().circle (C1, R1).circle (C2, R2);
%! for k = 1:2
%!   u = (T(k,:) - C1) / norm (T(k,:) - C1);
%!   D = D.line (C1 + R1 * u, C2 + R2 * u);
%! endfor
%! draw.plot (D);
%! title ('an open belt over two pulleys');

%!test  # from a point on the x axis, the contacts are symmetric about it
%! P = geom.tangentpoints ([0, 0], 3, [5, 0]);
%! assert_equal (rows (P), 2);
%! assert_equal (P(1,1), P(2,1), 1e-12);
%! assert_equal (P(1,2), -P(2,2), 1e-12);

%!test  # both contacts are on the circle
%! P = geom.tangentpoints ([1, 2], 4, [9, 7]);
%! assert_equal (sqrt (sum ((P - [1, 2]) .^ 2, 2)), [4; 4], 1e-12);

%!test  # the radius to a contact is perpendicular to the tangent, which is
%!       # what makes it a tangent
%! C = [1, 2];  R = 4;  Q = [9, 7];
%! P = geom.tangentpoints (C, R, Q);
%! for k = 1:2
%!   assert_equal (dot (P(k,:) - C, Q - P(k,:)), 0, 1e-9);
%! endfor

%!test  # the tangent length is the leg of the right triangle
%! C = [0, 0];  R = 3;  Q = [5, 0];
%! P = geom.tangentpoints (C, R, Q);
%! assert_equal (norm (P(1,:) - Q), 4, 1e-12);

%!test  # a point on the circle touches there and nowhere else
%! P = geom.tangentpoints ([0, 0], 5, [5, 0]);
%! assert_equal (rows (P), 1);
%! assert_equal (P, [5, 0], 1e-12);

%!test  # a distant point gives contacts approaching the diameter ends
%! P = geom.tangentpoints ([0, 0], 1, [1e6, 0]);
%! assert_equal (sort (P(:,2)), [-1; 1], 1e-4);

%!error<geom.tangentpoints: invalid number of input arguments.> ...
%! geom.tangentpoints ([0, 0], 1)
%!error<geom.tangentpoints: Q is 2 mm inside the circle, and no line through an interior point can be tangent to it.> ...
%! geom.tangentpoints ([0, 0], 5, [3, 0])
%!error<geom.tangentpoints: R must be a positive real finite scalar.> ...
%! geom.tangentpoints ([0, 0], 0, [3, 0])
%!error<geom.tangentpoints: Q must be a 1-by-2 real finite point.> ...
%! geom.tangentpoints ([0, 0], 1, [3, 0, 0])
