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
## @deftypefn  {drafting} {@var{S} =} draw.hatchlines (@var{P})
## @deftypefnx {drafting} {@var{S} =} draw.hatchlines (@var{P}, @var{PATTERN})
## @deftypefnx {drafting} {@var{S} =} draw.hatchlines (@var{P}, @var{PATTERN}, @var{ANGLE}, @var{SPACING})
## @deftypefnx {drafting} {@var{NAMES} =} draw.hatchlines ()
##
## The line segments that fill a boundary with a hatch pattern.
##
## @code{@var{S} = draw.hatchlines (@var{P})} returns the segments that hatch
## the polygon @var{P} with the default pattern, as an @math{N}-by-4 matrix
## whose rows are @code{[@var{x1}, @var{y1}, @var{x2}, @var{y2}]}.
##
## @code{@var{S} = draw.hatchlines (@var{P}, @var{PATTERN}, @var{ANGLE},
## @var{SPACING})} chooses the pattern, rotates it by @var{ANGLE} degrees and
## sets the perpendicular distance between lines to @var{SPACING} millimetres.
## @var{ANGLE} defaults to zero and @var{SPACING} to the pattern's own.
##
## @code{@var{NAMES} = draw.hatchlines ()} lists the patterns defined.
##
## @subheading Why this is a function and not a rendering detail
##
## A hatch is a set of lines.  Formats that have no hatch entity of their own
## --- and the DXF revision this package writes is one --- can still carry the
## hatch if the lines are generated explicitly, and a figure can draw it the
## same way.  Producing them once, here, is what lets every backend show the
## same fill rather than each inventing its own or dropping it.
##
## @subheading The patterns
##
## @multitable @columnfractions 0.16 0.16 0.68
## @headitem Name @tab Spacing @tab
## @item @qcode{'ANSI31'} @tab 3.175 @tab 45 degrees; the general-purpose
## section hatch, and what an unqualified hatch means
## @item @qcode{'ANSI32'} @tab 6.35 @tab 45 degrees, widely spaced; steel
## @item @qcode{'ANSI37'} @tab 3.175 @tab crosshatch at 45 and 135 degrees
## @item @qcode{'HORIZONTAL'} @tab 3.175 @tab lines along the x axis
## @item @qcode{'VERTICAL'} @tab 3.175 @tab lines along the y axis
## @item @qcode{'CROSS'} @tab 3.175 @tab square grid
## @end multitable
##
## @subheading How the lines are clipped
##
## The boundary is rotated so the hatch runs horizontally, scanned at the
## requested spacing, and each scan line is cut against the polygon edges by the
## even-odd rule before the pieces are rotated back.  A boundary that is concave
## or re-entrant is therefore filled correctly, in as many pieces as it takes.
##
## An edge is counted when the scan line crosses its lower vertex but not its
## upper one, so a scan passing exactly through a vertex produces one crossing
## rather than none or two.  Without that rule a hatch develops occasional
## stray lines running out of the shape, and only at particular spacings.
##
## Self-intersecting boundaries are not rejected, but the even-odd rule then
## fills them the way it fills any such figure, leaving the crossed regions
## bare.  Check with @code{geom.selfintersects} if that matters.
##
## @seealso{draw.Drawing, draw.entities, draw.plot, geom.selfintersects}
## @end deftypefn

function S = hatchlines (varargin)

  ## Input validation
  if (numel (varargin) > 4)
    error ("draw.hatchlines: invalid number of input arguments.");
  endif

  T = {'ANSI31',     [45],       3.175; ...
       'ANSI32',     [45],       6.35; ...
       'ANSI37',     [45, 135],  3.175; ...
       'HORIZONTAL', [0],        3.175; ...
       'VERTICAL',   [90],       3.175; ...
       'CROSS',      [0, 90],    3.175};

  if (numel (varargin) == 0)
    S = T(:,1)';
    return;
  endif

  [errmsg, P] = geom.__checkpoly__ (varargin{1});
  if (! isempty (errmsg))
    error ("draw.hatchlines: %s", errmsg);
  endif

  PATTERN = 'ANSI31';
  if (numel (varargin) > 1 && ! isempty (varargin{2}))
    PATTERN = varargin{2};
  endif
  if (! ischar (PATTERN) || ! isrow (PATTERN))
    error ("draw.hatchlines: PATTERN must be a character vector.");
  endif
  k = find (strcmpi (PATTERN, T(:,1)), 1);
  if (isempty (k))
    error (strcat ("draw.hatchlines: '%s' is not a defined pattern; use", ...
                   " draw.hatchlines () for the list."), PATTERN);
  endif

  ANGLE = 0;
  if (numel (varargin) > 2 && ! isempty (varargin{3}))
    ANGLE = varargin{3};
  endif
  SPACING = T{k,3};
  if (numel (varargin) > 3 && ! isempty (varargin{4}))
    SPACING = varargin{4};
  endif
  if (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE) ...
      || ! isfinite (ANGLE))
    error ("draw.hatchlines: ANGLE must be a real finite scalar.");
  endif
  if (! isnumeric (SPACING) || ! isreal (SPACING) || ! isscalar (SPACING) ...
      || ! isfinite (SPACING) || SPACING <= 0)
    error ("draw.hatchlines: SPACING must be a positive real finite scalar.");
  endif

  S = zeros (0, 4);
  for a = T{k,2} + ANGLE
    S = [S; scanfill(P, a, SPACING)];
  endfor

endfunction

## Fill one direction: rotate the boundary so the hatch is horizontal, scan it,
## clip each scan line by the even-odd rule, rotate the pieces back.
function S = scanfill (P, adeg, spacing)

  c = cosd (adeg);
  s = sind (adeg);
  R = [c, s; -s, c];                  # rotate by -adeg
  Q = P * R';

  ymin = min (Q(:,2));
  ymax = max (Q(:,2));
  y0 = ceil (ymin / spacing) * spacing;
  ys = y0:spacing:ymax;

  A = Q;
  B = Q([2:end, 1],:);
  S = zeros (0, 4);

  for y = ys
    ## Half-open in y: a scan through a vertex crosses once, not twice
    lo = min (A(:,2), B(:,2));
    hi = max (A(:,2), B(:,2));
    hit = (lo <= y) & (hi > y);
    if (! any (hit))
      continue;
    endif
    a = A(hit,:);
    b = B(hit,:);
    t = (y - a(:,2)) ./ (b(:,2) - a(:,2));
    x = sort (a(:,1) + t .* (b(:,1) - a(:,1)));

    for ii = 1:2:numel (x) - 1
      S(end+1,:) = [x(ii), y, x(ii+1), y];
    endfor
  endfor

  if (! isempty (S))
    S = [S(:,1:2) * R, S(:,3:4) * R];
  endif

endfunction

%!test  # the list names every pattern
%! N = draw.hatchlines ();
%! assert_equal (iscellstr (N), true);
%! assert_equal (any (strcmp ('ANSI31', N)), true);

%!test  # a square is filled, and every segment lies inside it
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! S = draw.hatchlines (P);
%! assert_equal (columns (S), 4);
%! assert_equal (rows (S) > 0, true);
%! assert_equal (all (S(:) >= -1e-9 & S(:) <= 20 + 1e-9), true);

%!test  # a crosshatch produces both directions, so more segments than one
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! assert_equal (rows (draw.hatchlines (P, 'ANSI37')) ...
%!               > rows (draw.hatchlines (P, 'ANSI31')), true);

%!test  # wider spacing means fewer lines
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! n1 = rows (draw.hatchlines (P, 'ANSI31', 0, 1));
%! n2 = rows (draw.hatchlines (P, 'ANSI31', 0, 4));
%! assert_equal (n1 > n2, true);

%!test  # horizontal hatch really is horizontal
%! S = draw.hatchlines ([0, 0; 20, 0; 20, 20; 0, 20], 'HORIZONTAL');
%! assert_equal (S(:,2), S(:,4), 1e-9);

%!test  # vertical hatch really is vertical
%! S = draw.hatchlines ([0, 0; 20, 0; 20, 20; 0, 20], 'VERTICAL');
%! assert_equal (S(:,1), S(:,3), 1e-9);

%!test  # the hatched length of a square matches its area over the spacing
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! S = draw.hatchlines (P, 'HORIZONTAL', 0, 0.05);
%! L = sum (sqrt ((S(:,3) - S(:,1)) .^ 2 + (S(:,4) - S(:,2)) .^ 2));
%! assert_equal (L * 0.05, 400, 1);

%!test  # and for a rotated pattern too, which is the real test of the clipping
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! S = draw.hatchlines (P, 'ANSI31', 0, 0.05);
%! L = sum (sqrt ((S(:,3) - S(:,1)) .^ 2 + (S(:,4) - S(:,2)) .^ 2));
%! assert_equal (L * 0.05, 400, 1);

%!test  # a concave boundary is filled in pieces, leaving the notch bare
%! P = [0, 0; 20, 0; 20, 20; 12, 20; 12, 6; 8, 6; 8, 20; 0, 20];
%! S = draw.hatchlines (P, 'HORIZONTAL', 0, 0.05);
%! L = sum (sqrt ((S(:,3) - S(:,1)) .^ 2 + (S(:,4) - S(:,2)) .^ 2));
%! assert_equal (L * 0.05, abs (geom.signedarea (P)), 1);

%!test  # a scan passing exactly through vertices does not leak outside
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! S = draw.hatchlines (P, 'HORIZONTAL', 0, 1);
%! assert_equal (all (S(:,1) >= -1e-9 & S(:,3) <= 10 + 1e-9), true);

%!test  # a triangle, whose scans cross a sloping pair of edges
%! P = [0, 0; 10, 0; 5, 10];
%! S = draw.hatchlines (P, 'HORIZONTAL', 0, 0.02);
%! L = sum (sqrt ((S(:,3) - S(:,1)) .^ 2 + (S(:,4) - S(:,2)) .^ 2));
%! assert_equal (L * 0.02, 50, 0.5);

%!test  # ANGLE rotates the pattern
%! P = [0, 0; 20, 0; 20, 20; 0, 20];
%! S = draw.hatchlines (P, 'HORIZONTAL', 90);
%! assert_equal (S(:,1), S(:,3), 1e-9);

%!error<draw.hatchlines: invalid number of input arguments.> ...
%! draw.hatchlines ([0,0;1,0;1,1], 'ANSI31', 0, 1, 2)
%!error<draw.hatchlines: P must be a polygon with at least 3 vertices.> ...
%! draw.hatchlines ([0, 0; 1, 1])
%!error<draw.hatchlines: 'TARTAN' is not a defined pattern; use draw.hatchlines \(\) for the list.> ...
%! draw.hatchlines ([0,0;1,0;1,1], 'TARTAN')
%!error<draw.hatchlines: SPACING must be a positive real finite scalar.> ...
%! draw.hatchlines ([0,0;1,0;1,1], 'ANSI31', 0, 0)
%!error<draw.hatchlines: ANGLE must be a real finite scalar.> ...
%! draw.hatchlines ([0,0;1,0;1,1], 'ANSI31', Inf)
