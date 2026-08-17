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
## @deftypefn  {drafting} {@var{CTR} =} geom.fillet (@var{A}, @var{B}, @var{R})
## @deftypefnx {drafting} {[@var{CTR}, @var{TA}, @var{TB}, @var{ANG}] =} geom.fillet (@dots{})
##
## The arc of a given radius tangent to two lines.
##
## @code{@var{CTR} = geom.fillet (@var{A}, @var{B}, @var{R})} returns the centre
## of the arc of radius @var{R} that runs tangent to both lines, rounding the
## corner they form.  Each line is a 2-by-2 matrix of two points on it.
##
## @code{[@var{CTR}, @var{TA}, @var{TB}, @var{ANG}] = geom.fillet (@dots{})}
## also returns the point at which the arc meets each line, and the two angles
## @code{[@var{A1}, @var{A2}]} in degrees at which those points stand from the
## centre.  Those four values are exactly the arguments of
## @code{draw.Drawing.arc}, so the fillet is drawn by handing them straight on.
##
## Rounding a corner is among the most common things done to a drawing, and it
## is the operation a fabricator most often needs specified: an internal corner
## has a radius whether the drawing says so or not, because the tool that cut
## it had one.
##
## @subheading Which of the four corners
##
## Two crossing lines make four corners, and a radius fits in each.  The one
## filleted here is the corner the given points face into: for each line the
## endpoint further from the crossing sets a direction, and the arc is placed in
## the wedge between those two directions.
##
## So the lines are read as they would be drawn --- each running away from the
## corner being rounded --- and no fourth argument is needed to say which corner
## was meant.
##
## The @emph{order} of a line's two points does not matter, only which side of
## the crossing they lie on: the further of the two sets the direction either
## way.  To round a different corner, give points on the other side of the
## crossing, not the same points reversed.
##
## @subheading What is refused
##
## Parallel lines have no corner to round, and raise.  So does a radius the
## corner cannot hold: the tangent points would fall beyond the ends of the
## lines supplied, meaning the fillet wants more line than exists.  That last
## check uses the given points as the extent of real material, which is what
## they are when the lines come from a drawing.
##
## @seealso{geom.intersectlines, geom.tangentpoints, draw.Drawing}
## @end deftypefn

function [CTR, TA, TB, ANG] = fillet (A, B, R)

  ## Input validation
  if (nargin != 3)
    error ("geom.fillet: invalid number of input arguments.");
  endif
  A = checkline (A, 'A');
  B = checkline (B, 'B');
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R <= 0)
    error ("geom.fillet: R must be a positive real finite scalar.");
  endif

  X = geom.intersectlines (A, B);
  if (isempty (X))
    error (strcat ("geom.fillet: the lines are parallel and form no corner", ...
                   " to round."));
  endif

  ## Each line runs away from the corner towards whichever of its points is
  ## further from it; that pair of directions is the wedge to fill
  ua = awayfrom (A, X);
  ub = awayfrom (B, X);

  ## The centre lies on the bisector, at R over the sine of the half angle
  half = acos (max (-1, min (1, ua * ub'))) / 2;
  if (sin (half) <= 1e-12)
    error ("geom.fillet: the lines are parallel and form no corner to round.");
  endif
  bis = ua + ub;
  bis /= norm (bis);
  CTR = X + (R / sin (half)) * bis;

  ## The tangent points are the feet of the perpendiculars onto each line
  dA = R / tan (half);
  TA = X + dA * ua;
  TB = X + dA * ub;

  ## The fillet must not want more line than was given
  if (dA > lengthfrom (A, X) + 1e-12 || dA > lengthfrom (B, X) + 1e-12)
    error (strcat ("geom.fillet: a radius of %g needs %g of line either", ...
                   " side of the corner, which is more than was given."), ...
           R, dA);
  endif

  if (nargout > 3)
    a1 = atan2 (TA(2) - CTR(2), TA(1) - CTR(1)) * 180 / pi;
    a2 = atan2 (TB(2) - CTR(2), TB(1) - CTR(1)) * 180 / pi;
    ## Report the arc counter-clockwise over the short way round, which is the
    ## fillet rather than its reflex complement
    if (mod (a2 - a1, 360) > 180)
      ANG = [mod(a2, 360), mod(a1, 360)];
    else
      ANG = [mod(a1, 360), mod(a2, 360)];
    endif
  endif

endfunction

## The unit direction from X towards the further endpoint of the line
function u = awayfrom (L, X)

  d1 = norm (L(1,:) - X);
  d2 = norm (L(2,:) - X);
  if (d2 >= d1)
    u = L(2,:) - X;
  else
    u = L(1,:) - X;
  endif
  u /= norm (u);

endfunction

## How much line there is between the corner and the further endpoint
function d = lengthfrom (L, X)

  d = max (norm (L(1,:) - X), norm (L(2,:) - X));

endfunction

function L = checkline (L, name)
  if (! isnumeric (L) || ! isreal (L) || ! isequal (size (L), [2, 2]) ...
      || ! all (isfinite (L(:))))
    error (strcat ("geom.fillet: %s must be a 2-by-2 matrix of two real", ...
                   " finite points."), name);
  endif
  if (isequal (L(1,:), L(2,:)))
    error ("geom.fillet: %s must be two distinct points.", name);
  endif
endfunction

%!demo
%! ## Rounding a corner is the commonest edit a drawing gets.  `geom.fillet`
%! ## returns the arc centre, where it meets each line, and the two angles ---
%! ## which are exactly what `draw.Drawing.arc` takes, so the fillet is drawn by
%! ## handing them straight on.
%!
%! A = [10, 60; 10, 10];
%! B = [10, 10; 80, 10];
%! [C, TA, TB, ANG] = geom.fillet (A, B, 20)
%!
%! ## Each line is drawn only as far as its tangent point, and the arc joins
%! ## them; the red marks are where the arc meets each line.
%! D = draw.Drawing ();
%! D = D.line (A(1,:), TA).line (TB, B(2,:)).arc (C, 20, ANG(1), ANG(2));
%! D.Colour = 'red';
%! D = D.circle (TA, 1.5).circle (TB, 1.5);
%! draw.plot (D);
%! title ('a 20 mm fillet, and the two tangent points it meets');

%!demo
%! ## The corner filleted is the one the given points face into, so all four
%! ## are reachable without a fifth argument.  The order of a line's two points
%! ## does not matter; which side of the crossing they lie on does.
%!
%! D = draw.Drawing ();
%! for s = [1, -1]
%!   for t = [1, -1]
%!     A = [0, 0; 60 * s, 0];
%!     B = [0, 0; 0, 60 * t];
%!     [C, TA, TB, ANG] = geom.fillet (A, B, 15);
%!     D = D.line (A(2,:), TA).line (TB, B(2,:)).arc (C, 15, ANG(1), ANG(2));
%!   endfor
%! endfor
%! draw.plot (D);
%! title ('the same call fillets whichever corner the points face into');

%!test  # a right angle at the origin, filleted with radius 5
%! [CTR, TA, TB] = geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 5);
%! assert_equal (CTR, [5, 5], 1e-12);
%! assert_equal (TA, [5, 0], 1e-12);
%! assert_equal (TB, [0, 5], 1e-12);

%!test  # the centre stands the radius away from both lines, which is the
%!       # definition of tangency
%! R = 4;
%! [CTR, TA, TB] = geom.fillet ([0, 0; 30, 0], [0, 0; 20, 20], R);
%! assert_equal (norm (CTR - TA), R, 1e-12);
%! assert_equal (norm (CTR - TB), R, 1e-12);

%!test  # and the radius to each tangent point is perpendicular to its line
%! [CTR, TA, TB] = geom.fillet ([0, 0; 30, 0], [0, 0; 20, 20], 4);
%! assert_equal (dot (CTR - TA, [30, 0] - [0, 0]), 0, 1e-9);
%! assert_equal (dot (CTR - TB, [20, 20] - [0, 0]), 0, 1e-9);

%!test  # the angles are those draw.Drawing.arc wants, and place the tangents
%! [CTR, TA, TB, ANG] = geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 5);
%! p1 = CTR + 5 * [cosd(ANG(1)), sind(ANG(1))];
%! p2 = CTR + 5 * [cosd(ANG(2)), sind(ANG(2))];
%! assert_equal (sortrows ([p1; p2]), sortrows ([TA; TB]), 1e-9);

%!test  # the arc takes the short way round, not the reflex complement
%! [CTR, TA, TB, ANG] = geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 5);
%! assert_equal (mod (ANG(2) - ANG(1), 360) <= 180, true);

%!test  # a sharper corner needs more line, since the tangent distance is the
%!       # radius over the tangent of the half angle
%! [~, TAsharp] = geom.fillet ([0, 0; 100, 0], [0, 0; 100, 100], 5);
%! [~, TAblunt] = geom.fillet ([0, 0; 100, 0], [0, 0; 10, 100], 5);
%! assert_equal (norm (TAsharp) > norm (TAblunt), true);
%! assert_equal (norm (TAsharp), 5 / tand (22.5), 1e-9);

%!test  # the order of a line's points does not matter
%! C1 = geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 5);
%! C2 = geom.fillet ([20, 0; 0, 0], [0, 20; 0, 0], 5);
%! assert_equal (C1, C2, 1e-12);
%! assert_equal (C1, [5, 5], 1e-12);

%!test  # which side the points lie on does: all four corners are reachable
%! R = 5;
%! quad = @(a, b) geom.fillet ([0, 0; a, 0], [0, 0; 0, b], R);
%! assert_equal (quad (20, 20), [5, 5], 1e-12);
%! assert_equal (quad (-20, 20), [-5, 5], 1e-12);
%! assert_equal (quad (-20, -20), [-5, -5], 1e-12);
%! assert_equal (quad (20, -20), [5, -5], 1e-12);

%!test  # the corner need not be at the origin, nor the lines meet at their ends
%! [CTR, TA, TB] = geom.fillet ([10, 5; 40, 5], [25, -10; 25, 30], 3);
%! assert_equal (norm (CTR - TA), 3, 1e-12);
%! assert_equal (norm (CTR - TB), 3, 1e-12);

%!test  # the fillet is drawable straight from the outputs
%! [CTR, TA, TB, ANG] = geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 5);
%! D = draw.Drawing ().arc (CTR, 5, ANG(1), ANG(2));
%! assert_equal (numentities (D), 1);

%!error<geom.fillet: invalid number of input arguments.> ...
%! geom.fillet ([0, 0; 1, 0], [0, 0; 0, 1])
%!error<geom.fillet: the lines are parallel and form no corner to round.> ...
%! geom.fillet ([0, 0; 10, 0], [0, 5; 10, 5], 1)
%!error<geom.fillet: a radius of 50 needs 50 of line either side of the corner, which is more than was given.> ...
%! geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 50)
%!error<geom.fillet: R must be a positive real finite scalar.> ...
%! geom.fillet ([0, 0; 20, 0], [0, 0; 0, 20], 0)
