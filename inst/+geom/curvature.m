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
## @deftypefn  {drafting} {@var{K} =} geom.curvature (@var{P})
## @deftypefnx {drafting} {@var{K} =} geom.curvature (@var{P}, @var{CLOSED})
## @deftypefnx {drafting} {[@var{K}, @var{R}] =} geom.curvature (@dots{})
##
## Signed curvature of a sampled planar curve.
##
## @code{@var{K} = geom.curvature (@var{P})} returns the signed curvature at
## each point of the curve whose points are the rows of the @math{N}-by-2 matrix
## @var{P}.  @var{K} is an @math{N}-by-1 vector in reciprocal units of @var{P},
## so with the package convention of millimetres it is in reciprocal
## millimetres.
##
## @code{@var{K} = geom.curvature (@var{P}, @var{CLOSED})} treats the curve as
## closed when @var{CLOSED} is true, joining the last point to the first.  An
## explicitly repeated closing point is accepted and ignored.  @var{CLOSED}
## defaults to false.
##
## @code{[@var{K}, @var{R}] = geom.curvature (@dots{})} additionally returns the
## signed radius of curvature @var{R}, which is @code{1 ./ @var{K}}.  A straight
## run gives zero curvature and an infinite radius; neither is an error.
##
## The sign carries the direction of turning.  @var{K} is positive where the
## curve turns counter-clockwise, so on a counter-clockwise closed curve a
## positive value means the centre of curvature lies on the interior side.  This
## is the sign an inward offset must respect: an inward offset of @var{D} is
## geometrically valid only where @var{D} does not exceed @code{1 / @var{K}} at
## every point whose curvature is positive.
##
## The curvature at a point is that of the circle through it and its two
## neighbours, which is exact for points sampled from a circle at any spacing
## and needs no estimate of a derivative.  On an open curve the two end points
## have no such neighbourhood and are returned as @code{NaN}.
##
## Three coincident or collinear points give zero curvature rather than an
## error, since a sampled curve legitimately contains straight runs.
##
## @seealso{geom.curveoffset, geom.curvesample, geom.selfintersects}
## @end deftypefn

function [K, R] = curvature (P, CLOSED = false)

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("geom.curvature: invalid number of input arguments.");
  endif
  if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
    error ("geom.curvature: CLOSED must be a logical scalar.");
  endif
  CLOSED = logical (CLOSED);
  [errmsg, P] = geom.__checkcurve__ (P, CLOSED);
  if (! isempty (errmsg))
    error ("geom.curvature: %s", errmsg);
  endif

  n = rows (P);

  ## Three-point stencil: previous, current, next
  if (CLOSED)
    iPrev = [n, 1:n-1];
    iNext = [2:n, 1];
  else
    iPrev = [1, 1:n-1];
    iNext = [2:n, n];
  endif
  A = P(iPrev,:);
  B = P;
  C = P(iNext,:);

  ## Menger curvature: twice the signed triangle area over the product of the
  ## three side lengths, which is the reciprocal of the circumradius
  v1 = B - A;
  v2 = C - B;
  crossZ = v1(:,1) .* v2(:,2) - v1(:,2) .* v2(:,1);
  a = sqrt (sum (v1 .^ 2, 2));
  b = sqrt (sum (v2 .^ 2, 2));
  c = sqrt (sum ((C - A) .^ 2, 2));

  K = zeros (n, 1);
  ok = (a > 0 & b > 0 & c > 0);
  K(ok) = 2 * crossZ(ok) ./ (a(ok) .* b(ok) .* c(ok));

  ## An open curve has no neighbourhood at either end
  if (! CLOSED)
    K([1, n]) = NaN;
  endif

  if (nargout > 1)
    R = 1 ./ K;
  endif

endfunction

%!test  # a counter-clockwise unit circle has curvature 1 everywhere
%! t = linspace (0, 2*pi, 361)(1:360)';
%! K = geom.curvature ([cos(t), sin(t)], true);
%! assert_equal (K, ones (360, 1), 1e-9);

%!test  # a clockwise circle carries the opposite sign
%! t = linspace (0, 2*pi, 361)(1:360)';
%! K = geom.curvature ([cos(-t), sin(-t)], true);
%! assert_equal (K, -ones (360, 1), 1e-9);

%!test  # curvature is the reciprocal of the radius
%! t = linspace (0, 2*pi, 181)(1:180)';
%! K = geom.curvature (25 * [cos(t), sin(t)], true);
%! assert_equal (K, ones (180, 1) / 25, 1e-9);

%!test  # exact at coarse and uneven sampling, being a circumradius
%! t = [0; 0.3; 1.1; 2.0; 3.5; 4.0; 5.2]';
%! K = geom.curvature ([cos(t'), sin(t')], true);
%! assert_equal (K, ones (7, 1), 1e-9);

%!test  # the radius of curvature is the second output
%! t = linspace (0, 2*pi, 181)(1:180)';
%! [K, R] = geom.curvature (7 * [cos(t), sin(t)], true);
%! assert_equal (R, 7 * ones (180, 1), 1e-9);

%!test  # a straight run is flat, not an error
%! K = geom.curvature ([0, 0; 1, 0; 2, 0; 3, 0], true);
%! assert_equal (K, zeros (4, 1), 1e-12);

%!test  # an open curve has no curvature at its ends
%! K = geom.curvature ([0, 0; 1, 0; 1, 1; 0, 1]);
%! assert_equal (isnan (K), [true; false; false; true]);

%!test  # the interior of an open curve is still measured
%! K = geom.curvature ([1, 0; 0, 1; -1, 0]);
%! assert_equal (K(2), 1, 1e-12);

%!test  # an explicitly closed ring gives one value per distinct point
%! t = linspace (0, 2*pi, 61)(1:60)';
%! P = [cos(t), sin(t)];
%! K = geom.curvature ([P; P(1,:)], true);
%! assert_equal (rows (K), 60);

%!test  # coincident points do not divide by zero
%! K = geom.curvature ([0, 0; 1, 0; 1, 0; 2, 0], true);
%! assert_equal (any (isnan (K)), false);

%!error<geom.curvature: invalid number of input arguments.> geom.curvature ()
%!error<geom.curvature: CLOSED must be a logical scalar.> ...
%! geom.curvature ([0, 0; 1, 0; 1, 1], [true, false])
%!error<geom.curvature: P must be a real numeric matrix.> geom.curvature ('a')
%!error<geom.curvature: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.curvature ([1, 2, 3])
%!error<geom.curvature: P must not contain NaN or Inf values.> ...
%! geom.curvature ([0, 0; 1, 0; NaN, 1])
%!error<geom.curvature: P must be a curve with at least 3 points.> ...
%! geom.curvature ([0, 0; 1, 1])
