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
## @deftypefn  {drafting} {@var{R} =} geom.largestrect (@var{P})
## @deftypefnx {drafting} {@var{R} =} geom.largestrect (@var{P}, @var{MARGINS})
## @deftypefnx {drafting} {[@var{R}, @var{B}] =} geom.largestrect (@dots{})
##
## Largest axis-aligned rectangle inscribed in a rectilinear polygon.
##
## @code{@var{R} = geom.largestrect (@var{P})} returns the largest
## axis-aligned rectangle that fits inside the polygon @var{P}, as a 4-by-2
## matrix of vertices wound counter-clockwise starting from the lower-left
## corner.
##
## @code{@var{R} = geom.largestrect (@var{P}, @var{MARGINS})} additionally
## keeps the rectangle clear of @emph{every} wall of @var{P} by the given
## margins, the face of a notch included and not merely the bounding box.
## @var{MARGINS} is a scalar applied to all four sides, or the 1-by-4 vector
## @code{[@var{left}, @var{bottom}, @var{right}, @var{top}]} naming them
## individually, in the units of @var{P}.  All values must be non-negative and
## it defaults to zero.
##
## Clearance is measured per axis, so the @var{right} margin is held against
## whichever wall bounds the rectangle on its right --- the outline's own
## right-hand side, or the inner face of a notch, whichever it meets first.
##
## This is the operation that fits a usable rectangle inside an irregular
## outline: the per-side margins are the clearance budget --- whatever has to be
## kept free along each side --- and the result is the largest rectangle that
## budget leaves room for.
##
## @code{[@var{R}, @var{B}] = geom.largestrect (@dots{})} also returns the
## rectangle in the compact form
## @code{[@var{xmin}, @var{ymin}, @var{xmax}, @var{ymax}]} used by
## @code{geom.bbox}.
##
## @strong{Rectilinear input only.}  @var{P} must satisfy
## @code{geom.isrectilinear}.  The search considers only rectangles whose edges
## lie on lines through vertices of @var{P}, which is exactly where an optimal
## rectangle must lie when the outline is rectilinear; on a sloped edge that
## reasoning fails and the answer would be wrong rather than merely
## conservative, so such input is rejected instead.
##
## Where several rectangles tie for the largest area, the first encountered is
## returned, scanning @math{x} bounds before @math{y} bounds and each in
## ascending order.  The result is therefore deterministic.
##
## @seealso{geom.bbox, geom.offset, geom.isrectilinear}
## @end deftypefn

function [R, B] = largestrect (P, MARGINS = 0)

  ## Input validation
  if (nargin < 1)
    error ("geom.largestrect: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.largestrect: %s", errmsg);
  endif
  if (! isnumeric (MARGINS) || ! isreal (MARGINS) ...
      || ! all (isfinite (MARGINS(:))) || any (MARGINS(:) < 0) ...
      || ! (isscalar (MARGINS) || isequal (size (MARGINS), [1, 4])))
    error (strcat ("geom.largestrect: MARGINS must be a non-negative real", ...
                   " finite scalar or 1-by-4 vector."));
  endif
  if (! geom.isrectilinear (P))
    error (strcat ("geom.largestrect: P must be a rectilinear polygon;", ...
                   " inscribing in a general polygon is not implemented."));
  endif
  if (isscalar (MARGINS))
    MARGINS = MARGINS * ones (1, 4);
  endif

  ## The search window is the whole bounding box.  The margins are not taken
  ## out of it, but out of each candidate rectangle below, so that they are
  ## measured from whichever wall of P that rectangle actually meets --- a
  ## re-entrant one included.
  box = geom.bbox (P);
  win = box;
  if (MARGINS(1) + MARGINS(3) >= box(3) - box(1) ...
      || MARGINS(2) + MARGINS(4) >= box(4) - box(2))
    error (strcat ("geom.largestrect: MARGINS leave no room inside the", ...
                   " bounding box of P."));
  endif

  ## Candidate edge positions: every vertex coordinate, plus the window itself,
  ## clipped to the window.  An optimal rectangle in a rectilinear outline has
  ## its edges on these lines.
  xs = unique ([P(:,1); win(1); win(3)]);
  ys = unique ([P(:,2); win(2); win(4)]);
  xs = xs(xs >= win(1) & xs <= win(3));
  ys = ys(ys >= win(2) & ys <= win(4));
  nx = numel (xs);
  ny = numel (ys);

  ## Those lines cut the window into cells.  Because every edge of P lies on a
  ## candidate line, no edge crosses a cell interior, so one test per cell
  ## centre settles the whole cell.
  xMid = (xs(1:end-1) + xs(2:end)) / 2;
  yMid = (ys(1:end-1) + ys(2:end)) / 2;
  [xGrid, yGrid] = ndgrid (xMid, yMid);
  inside = inpolygon (xGrid, yGrid, P(:,1), P(:,2));

  ## Summed-area table, so that testing a block of cells costs four lookups
  ## rather than a scan.
  total = zeros (nx, ny);
  total(2:end, 2:end) = cumsum (cumsum (inside, 1), 2);

  ## Search every pair of x bounds against every pair of y bounds
  bestArea = 0;
  B = [];
  ## A rectangle stands off every wall of P by MARGINS exactly when the
  ## rectangle grown by MARGINS is inside P.  So the block of cells tested is
  ## the grown rectangle, and what is scored and returned is that block less
  ## the margins.
  for i1 = 1:nx-1
    for i2 = i1+1:nx
      wide = xs(i2) - xs(i1) - MARGINS(1) - MARGINS(3);
      if (wide <= 0)
        continue;
      endif
      for j1 = 1:ny-1
        for j2 = j1+1:ny
          high = ys(j2) - ys(j1) - MARGINS(2) - MARGINS(4);
          if (high <= 0)
            continue;
          endif
          area = wide * high;
          if (area <= bestArea)
            continue;
          endif
          ## Every cell spanned must be inside P
          nIn = total(i2,j2) - total(i1,j2) - total(i2,j1) + total(i1,j1);
          if (nIn == (i2 - i1) * (j2 - j1))
            bestArea = area;
            B = [xs(i1) + MARGINS(1), ys(j1) + MARGINS(2), ...
                 xs(i2) - MARGINS(3), ys(j2) - MARGINS(4)];
          endif
        endfor
      endfor
    endfor
  endfor

  if (isempty (B))
    error (strcat ("geom.largestrect: no rectangle fits inside P within", ...
                   " MARGINS."));
  endif

  ## Counter-clockwise from the lower-left corner
  R = [B(1), B(2); B(3), B(2); B(3), B(4); B(1), B(4)];

endfunction

%!demo
%! ## The largest axis-aligned rectangle that fits inside an outline, with a
%! ## per-side clearance kept free.  The margins are the budget; the rectangle
%! ## is what that budget leaves room for.
%!
%! P = [0, 0; 60, 0; 60, 20; 30, 20; 30, 45; 0, 45];
%! [R, B] = geom.largestrect (P, [4, 6, 4, 3])
%!
%! D = draw.Drawing ().polyline (P, true);
%! D.Colour = 'red';
%! D = D.polyline (R, true);
%! plot (D);
%! title ('the biggest rectangle that fits, after the clearances');

%!test  # a rectangle is its own largest inscribed rectangle
%! P = [0, 0; 10, 0; 10, 6; 0, 6];
%! [R, B] = geom.largestrect (P);
%! assert_equal (B, [0, 0, 10, 6]);
%! assert_equal (R, [0, 0; 10, 0; 10, 6; 0, 6]);

%!test  # the result is wound counter-clockwise
%! P = [0, 0; 10, 0; 10, 6; 0, 6];
%! assert_equal (sign (geom.signedarea (geom.largestrect (P))), 1);

%!test  # a clockwise outline gives the same rectangle
%! cw = geom.largestrect ([0, 0; 0, 6; 10, 6; 10, 0]);
%! ccw = geom.largestrect ([0, 0; 10, 0; 10, 6; 0, 6]);
%! assert_equal (cw, ccw);

%!test  # a scalar margin insets all four sides
%! P = [0, 0; 10, 0; 10, 6; 0, 6];
%! [~, B] = geom.largestrect (P, 1);
%! assert_equal (B, [1, 1, 9, 5]);

%!test  # per-side margins: [left, bottom, right, top]
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! [~, B] = geom.largestrect (P, [100, 50, 200, 25]);
%! assert_equal (B, [100, 50, 1400, 1775]);

%!test  # an outline reduced by a per-side clearance budget
%! outline = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! [~, B] = geom.largestrect (outline, [50, 200, 50, 100]);
%! assert_equal (B(3) - B(1), 1500);     # width
%! assert_equal (B(4) - B(2), 1500);     # depth

%!test  # a margin is held against a re-entrant wall, not just the bounding box
%! P = [0, 0; 60, 0; 60, 20; 30, 20; 30, 45; 0, 45];
%! [~, B] = geom.largestrect (P, [4, 6, 4, 3]);
%! assert_equal (B, [4, 6, 26, 42], 1e-9);

%!test  # the clearance from a notch face equals the margin for that side
%! P = [0, 0; 60, 0; 60, 5; 30, 5; 30, 45; 0, 45];
%! [~, B] = geom.largestrect (P, [0, 0, 7, 0]);
%! assert_equal (30 - B(3), 7, 1e-9);

%!test  # the notch of an L shape is excluded: 40, not the 64 of the outline
%! P = [0, 0; 10, 0; 10, 4; 4, 4; 4, 10; 0, 10];
%! [~, B] = geom.largestrect (P);
%! assert_equal (geom.signedarea (P), 64);
%! assert_equal (geom.signedarea (geom.largestrect (P)), 40);
%! ## Both arms are 10-by-4, so they tie; the documented scan order takes the
%! ## smaller x-span first.
%! assert_equal (B, [0, 0, 4, 10]);

%!test  # an unequal L takes the larger arm outright, with no tie to break
%! P = [0, 0; 10, 0; 10, 4; 3, 4; 3, 10; 0, 10];
%! [~, B] = geom.largestrect (P);
%! assert_equal (B, [0, 0, 10, 4]);       # 40, against 30 for the upright arm

%!test  # a symmetric plus shape picks one arm deterministically
%! P = [1, 0; 2, 0; 2, 1; 3, 1; 3, 2; 2, 2; 2, 3; 1, 3; 1, 2; 0, 2; 0, 1; 1, 1];
%! [~, B] = geom.largestrect (P);
%! assert_equal (geom.signedarea (geom.largestrect (P)), 3);
%! assert_equal (B, [0, 1, 3, 2]);

%!test  # the inscribed rectangle never exceeds the polygon area
%! P = [0, 0; 10, 0; 10, 4; 4, 4; 4, 10; 0, 10];
%! assert_equal (geom.signedarea (geom.largestrect (P)) ...
%!               <= geom.signedarea (P), true);

%!test  # growing a margin can only shrink the result
%! P = [0, 0; 10, 0; 10, 6; 0, 6];
%! a = arrayfun (@(m) geom.signedarea (geom.largestrect (P, m)), [0, 1, 2]);
%! assert_equal (all (diff (a) < 0), true);

%!test  # margins agree with offsetting the outline first, on a rectangle
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! assert_equal (geom.largestrect (P, 60), geom.offset (P, 60), 1e-9);

%!error<geom.largestrect: invalid number of input arguments.> ...
%! geom.largestrect ()
%!error<geom.largestrect: P must be a polygon with at least 3 vertices.> ...
%! geom.largestrect ([0, 0; 1, 1])
%!error<geom.largestrect: MARGINS must be a non-negative real finite scalar or 1-by-4 vector.> ...
%! geom.largestrect ([0, 0; 10, 0; 10, 6; 0, 6], -1)
%!error<geom.largestrect: MARGINS must be a non-negative real finite scalar or 1-by-4 vector.> ...
%! geom.largestrect ([0, 0; 10, 0; 10, 6; 0, 6], [1, 2, 3])
%!error<geom.largestrect: MARGINS must be a non-negative real finite scalar or 1-by-4 vector.> ...
%! geom.largestrect ([0, 0; 10, 0; 10, 6; 0, 6], Inf)
%!error<geom.largestrect: P must be a rectilinear polygon; inscribing in a general polygon is not implemented.> ...
%! geom.largestrect ([0, 0; 10, 0; 0, 10])
%!error<geom.largestrect: MARGINS leave no room inside the bounding box of P.> ...
%! geom.largestrect ([0, 0; 10, 0; 10, 6; 0, 6], 5)
%!error<geom.largestrect: P must be a real numeric matrix.> ...
%! geom.largestrect ({1, 2})
%!error<geom.largestrect: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.largestrect (ones (3, 3))
%!error<geom.largestrect: P must contain at least one point.> ...
%! geom.largestrect (zeros (0, 2))
%!error<geom.largestrect: P must not contain NaN or Inf values.> ...
%! geom.largestrect ([0, 0; 1, 1; 2, 2; NaN, 3])
