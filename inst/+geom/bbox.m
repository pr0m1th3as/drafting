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
## @deftypefn  {drafting} {@var{B} =} geom.bbox (@var{P})
## @deftypefnx {drafting} {[@var{B}, @var{W}, @var{H}] =} geom.bbox (@var{P})
##
## Axis-aligned bounding box of a set of points.
##
## @code{@var{B} = geom.bbox (@var{P})} returns the axis-aligned bounding box of
## the points given as rows of the @math{N}-by-2 matrix @var{P}, as the 1-by-4
## row vector @code{[@var{xmin}, @var{ymin}, @var{xmax}, @var{ymax}]}.
##
## @code{[@var{B}, @var{W}, @var{H}] = geom.bbox (@var{P})} additionally returns
## the width @var{W} and height @var{H} of the box.
##
## Unlike most of this namespace, @code{geom.bbox} accepts any point set, not
## only a polygon: a single point is valid input and yields a box of zero width
## and height.
##
## @seealso{geom.signedarea, geom.centroid, geom.largestrect}
## @end deftypefn

function [B, W, H] = bbox (P)

  ## Input validation
  if (nargin != 1)
    error ("geom.bbox: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("geom.bbox: %s", errmsg);
  endif

  ## Extents along each axis
  B = [min(P(:,1)), min(P(:,2)), max(P(:,1)), max(P(:,2))];

  if (nargout > 1)
    W = B(3) - B(1);
  endif
  if (nargout > 2)
    H = B(4) - B(2);
  endif

endfunction

%!demo
%! ## The extent of a set of points, and the width and height with it.
%!
%! t = linspace (0, 2*pi, 181)(1:180)';
%! P = (30 + 5 * cos (5 * t)) .* [cos(t), sin(t)];
%! [B, W, H] = geom.bbox (P)
%!
%! D = draw.Drawing ().polyline (P, true);
%! D.Linetype = 'PHANTOM';
%! D.Colour = 'red';
%! D = D.polyline ([B(1), B(2); B(3), B(2); B(3), B(4); B(1), B(4)], true);
%! draw.plot (D);
%! title ('a profile and the box that bounds it');

%!test
%! assert_equal (geom.bbox ([0, 0; 1, 0; 1, 1; 0, 1]), [0, 0, 1, 1]);

%!test  # an outline in millimetres
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! [B, W, H] = geom.bbox (P);
%! assert_equal (B, [0, 0, 1600, 1800]);
%! assert_equal (W, 1600);
%! assert_equal (H, 1800);

%!test  # order of the vertices is irrelevant
%! P = [1600, 1800; 0, 0; 1600, 0; 0, 1800];
%! assert_equal (geom.bbox (P), [0, 0, 1600, 1800]);

%!test  # negative coordinates
%! assert_equal (geom.bbox ([-5, -3; 2, 7]), [-5, -3, 2, 7]);

%!test  # a single point gives a degenerate box
%! [B, W, H] = geom.bbox ([3, 4]);
%! assert_equal (B, [3, 4, 3, 4]);
%! assert_equal (W, 0);
%! assert_equal (H, 0);

%!test  # L-shaped polygon still reports the enclosing rectangle
%! P = [0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4];
%! assert_equal (geom.bbox (P), [0, 0, 4, 4]);

%!error<geom.bbox: invalid number of input arguments.> geom.bbox ()
%!error<geom.bbox: P must be a real numeric matrix.> geom.bbox ({1, 2})
%!error<geom.bbox: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.bbox ([1, 2, 3])
%!error<geom.bbox: P must contain at least one point.> geom.bbox (zeros (0, 2))
%!error<geom.bbox: P must not contain NaN or Inf values.> geom.bbox ([1, Inf])
