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
## @deftypefn  {drafting} {@var{S} =} solid.surface (@var{X}, @var{Y}, @var{Z}, @var{H})
## @deftypefnx {drafting} {@var{S} =} solid.surface (@dots{}, 'Label', @var{L})
##
## A solid made of a smooth surface through a grid of points.
##
## @code{@var{S} = solid.surface (@var{X}, @var{Y}, @var{Z}, @var{H})} fits an
## exact B-spline surface through the grid of points @var{X}, @var{Y} and
## @var{Z}, passing within 0.001 mm of every point, and returns the
## @code{solid.Shape} that surface makes thickened square to itself.
## @var{X}, @var{Y} and @var{Z} are real matrices of one size, at least 2 by
## 2, holding the coordinates of the points in rows and columns, as
## @code{meshgrid} makes them.  The grid stays the input and what comes out is
## smooth, where @code{solid.polyhedron} on the same grid gives facets.
##
## The normal of the surface is the step from one column of the grid to the
## next crossed with the step from one row to the next.  For a grid made by
## @code{meshgrid}, whose columns step along @math{x} and rows along @math{y},
## it points up, along @math{+z}.  Transposing @var{X}, @var{Y} and @var{Z}
## turns it round.
##
## @var{H} is the thickness in millimetres and which way it goes, as
## @code{solid.extrude} takes it:
##
## @table @asis
## @item a positive scalar
## along the normal, the surface the face of the solid against it;
## @item a negative scalar
## against the normal, the same thickness the other way;
## @item @code{[@var{H1}, @var{H2}]}, both positive
## to both sides of the surface, @var{H1} along the normal and @var{H2}
## against it, so @code{[0.5, 0.5]} is a thickness of 1 centred on it.
## @end table
##
## The grid must be open: neighbouring points must not coincide, and neither
## its first and last rows nor its first and last columns may meet, closing
## the surface on itself.
##
## A surface thickened by more than the radius it curves with folds over
## itself.  That is refused, naming the side of the surface and its tightest
## radius there.  A point the grid comes to, such as the tip of
## @code{sind (hypot (@var{X}, @var{Y}))} at the origin, is rounded off by the
## fit at a radius set by the spacing of the grid, and limits the thickness
## the same way.  The edges of the solid run square to the surface.
##
## The option @qcode{'Label'} names the faces of the solid, so that a later step
## finds a face by its name with @code{solid.Shape.faces}.  @var{L} is a valid
## Octave identifier or keyword.  The two large faces are @var{L}@code{.start},
## on the side against the normal, and @var{L}@code{.end}, on the side along it,
## whichever way @var{H} goes.  The narrow walls round the rim are named by the
## edge of the grid they stand on, as the grid is indexed @code{@var{X}(@var{i},
## @var{j})}: @var{L}@code{.imin} along its first row, @var{L}@code{.imax} along
## its last, @var{L}@code{.jmin} along its first column and @var{L}@code{.jmax}
## along its last, however fine the grid and however it is turned.
##
## @example
## @group
## ## A ripple 20 across, made a skin 1 thick centred on it
## [x, y] = meshgrid (-10:0.5:10);
## S = solid.surface (x, y, cosd (72 * hypot (x, y)), [0.5, 0.5]);
## @end group
## @end example
##
## @seealso{solid.polyhedron, solid.extrude, solid.Shape}
## @end deftypefn

function S = surface (X, Y, Z, H, varargin)

  ## Input validation
  if (nargin < 4)
    error ("solid.surface: invalid number of input arguments.");
  endif
  if (! (isgrid (X) && isgrid (Y) && isgrid (Z))
      || ! isequal (size (X), size (Y), size (Z)) || any (size (X) < 2))
    error (strcat ("solid.surface: X, Y and Z must be real finite", ...
                   " matrices of one size, at least 2 by 2."));
  endif
  if (! isfloat (H) || ! isreal (H) || ! isvector (H) || numel (H) > 2
      || ! all (isfinite (H)) || any (H == 0)
      || (numel (H) == 2 && any (H < 0)))
    error (strcat ("solid.surface: H must be a nonzero finite real", ...
                   " scalar, or two positive ones for both sides."));
  endif
  X = double (X);
  Y = double (Y);
  Z = double (Z);
  gap = @(d) sqrt (d(X) .^ 2 + d(Y) .^ 2 + d(Z) .^ 2);
  tol = 1e-7;
  down = gap (@(A) diff (A, 1, 1));
  across = gap (@(A) diff (A, 1, 2));
  if (any (down(:) < tol) || any (across(:) < tol))
    error ("solid.surface: neighbouring points of the grid must not coincide.");
  endif
  if (all (gap (@(A) A(:,1) - A(:,end)) < tol)
      || all (gap (@(A) A(1,:) - A(end,:)) < tol))
    error (strcat ("solid.surface: the grid must be open, but its first", ...
                   " and last rows or columns meet."));
  endif

  if (mod (numel (varargin), 2) != 0)
    error ("solid.surface: Name/Value arguments must come in pairs.");
  endif
  label = '';
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("solid.surface: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'label'
        label = val;
        if (! (ischar (val) && isrow (val)
               && (isvarname (val) || iskeyword (val))))
          error (strcat ("solid.surface: Label must be a valid Octave", ...
                         " identifier or keyword."));
        endif
      otherwise
        error ("solid.surface: unknown option '%s'.", name);
    endswitch
  endfor

  ## H1 along the normal and H2 against it
  H = double (H);
  if (isscalar (H))
    H = [max(H, 0), max(-H, 0)];
  endif
  S = solid.Shape (__occt__ ('surface', 'solid.surface', X, Y, Z, H(1), ...
                             H(2), label));

endfunction

## Whether A can hold one coordinate of a grid
function TF = isgrid (A)

  TF = isfloat (A) && isreal (A) && ismatrix (A) && all (isfinite (A(:)));

endfunction

## A grid on a cylinder of radius 2 about an axis below it, and a flat one
%!function [X, Y, Z] = arch ()
%!  [X, Y] = meshgrid (linspace (-1.5, 1.5, 13), 0:2:8);
%!  Z = sqrt (4 - X .^ 2);
%!endfunction
%!function [X, Y, Z] = flat ()
%!  [X, Y] = meshgrid (0:2:10, 0:2:8);
%!  Z = zeros (size (X));
%!endfunction

%!test  # a flat grid thickened covers the grid, the thickness high
%! [X, Y, Z] = flat ();
%! assert_equal (bbox (solid.surface (X, Y, Z, 1)), [0, 0, 0, 10, 8, 1], 1e-6);
%!test  # a grid of 2 by 2 makes a solid
%! S = solid.surface ([0, 3; 0, 3], [0, 0; 2, 2], zeros (2), 1);
%! assert_equal (bbox (S), [0, 0, 0, 3, 2, 1], 1e-6);
%!test  # a positive thickness grows from the surface along the normal
%! [X, Y, Z] = arch ();
%! B = bbox (solid.surface (X, Y, Z, 1));
%! assert_equal (B(3), min (Z(:)), 1e-3);
%!test  # a negative one grows against it, the surface on top
%! [X, Y, Z] = arch ();
%! B = bbox (solid.surface (X, Y, Z, -1));
%! assert_equal (B(6), 2, 1e-3);
%!test  # transposing the grid turns the normal round
%! [X, Y, Z] = flat ();
%! B = bbox (solid.surface (X', Y', Z', 1));
%! assert_equal (B([3, 6]), [-1, 0], 1e-6);
%!test  # two thicknesses lie along the normal and against it
%! [X, Y, Z] = flat ();
%! B = bbox (solid.surface (X, Y, Z, [0.2, 0.8]));
%! assert_equal (B([3, 6]), [-0.8, 0.2], 1e-6);
%!test  # a curved skin is one valid solid
%! [X, Y, Z] = arch ();
%! S = solid.surface (X, Y, Z, [0.5, 0.5]);
%! assert_equal ([numsolids(S), isvalid(S)], [1, true]);
%!test  # its volume is that of the shell between radii 1.5 and 2.5
%! [X, Y, Z] = arch ();
%! S = solid.surface (X, Y, Z, [0.5, 0.5]);
%! assert_equal (volume (S), asin (0.75) * (2.5 ^ 2 - 1.5 ^ 2) * 8, -1e-4);

%!test  # the large faces start and end, whichever way H goes
%! [X, Y, Z] = flat ();   # its faces splines, so found by place, not normal
%! S = solid.surface (X, Y, Z, 1, 'Label', 'skin');
%! assert_equal (faces (S, 'Label', 'skin.start'), ...
%!               faces (S, 'Within', [0, 0, 0, 10, 8, 0]));
%! assert_equal (faces (S, 'Label', 'skin.end'), ...
%!               faces (S, 'Within', [0, 0, 1, 10, 8, 1]));
%! S = solid.surface (X, Y, Z, -1, 'Label', 'skin');
%! assert_equal (faces (S, 'Label', 'skin.start'), ...
%!               faces (S, 'Within', [0, 0, -1, 10, 8, -1]));
%! S = solid.surface (X, Y, Z, [0.2, 0.8], 'Label', 'skin');
%! assert_equal (faces (S, 'Label', 'skin.end'), ...
%!               faces (S, 'Within', [0, 0, 0.2, 10, 8, 0.2]));
%!test  # the rim walls named by the row or column they stand on
%! [X, Y, Z] = flat ();   # rows along y from 0 to 8, columns along x to 10
%! S = solid.surface (X, Y, Z, 1, 'Label', 'skin');
%! assert_equal (faces (S, 'Label', 'skin.imin'), ...
%!               faces (S, 'Normal', [0, -1, 0]));
%! assert_equal (faces (S, 'Label', 'skin.imax'), ...
%!               faces (S, 'Normal', [0, 1, 0]));
%! assert_equal (faces (S, 'Label', 'skin.jmin'), ...
%!               faces (S, 'Normal', [-1, 0, 0]));
%! assert_equal (faces (S, 'Label', 'skin.jmax'), ...
%!               faces (S, 'Normal', [1, 0, 0]));
%!test  # a transposed grid swaps rows and columns with the normal
%! [X, Y, Z] = flat ();
%! S = solid.surface (X', Y', Z', 1, 'Label', 'skin');
%! assert_equal (faces (S, 'Label', 'skin.imin'), ...
%!               faces (S, 'Normal', [-1, 0, 0]));
%! assert_equal (faces (S, 'Label', 'skin.start'), ...
%!               faces (S, 'Within', [0, 0, 0, 10, 8, 0]));
%!test  # a curved skin thickened both ways
%! [X, Y, Z] = arch ();
%! S = solid.surface (X, Y, Z, [0.5, 0.5], 'Label', 'vault');
%! assert_equal (numel (faces (S, 'Label', 'vault')), 6);
%! assert_equal (numel (faces (S, 'Label', 'vault.imin')), 1);

%!error<solid.surface: the surface curves more tightly than the thickness against its normal allows; its tightest radius on that side is 1.97.> ...
%! [X, Y, Z] = arch ();
%! solid.surface (X, Y, Z, -3)
%!error<solid.surface: the surface curves more tightly than the thickness along its normal allows; its tightest radius on that side is 1.97.> ...
%! [X, Y, Z] = arch ();
%! solid.surface (X, Y, -Z, 3)
%!error<solid.surface: invalid number of input arguments.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2))
%!error<solid.surface: Name/Value arguments must come in pairs.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 1, 'Label')
%!error<solid.surface: unknown option 'Closed'.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 1, 'Closed', true)
%!error<solid.surface: Label must be a valid Octave identifier or keyword.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 1, 'Label', 'a.b')
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface ('ab', [0, 0; 1, 1], zeros (2), 1)
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2) + 1i, 1)
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], [0, NaN; 0, 0], 1)
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2, 3), 1)
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface ([0, 1, 2], [0, 0, 0], [0, 0, 0], 1)
%!error<solid.surface: X, Y and Z must be real finite matrices of one size, at least 2 by 2.> ...
%! solid.surface (zeros (2, 2, 2), zeros (2, 2, 2), zeros (2, 2, 2), 1)
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 0)
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), [1, 0])
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), [-1, 2])
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), [1, 2, 3])
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), Inf)
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 'a')
%!error<solid.surface: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.surface ([0, 1; 0, 1], [0, 0; 1, 1], zeros (2), 1i)
%!error<solid.surface: neighbouring points of the grid must not coincide.> ...
%! [X, Y] = meshgrid ([0, 1, 1, 2], [0, 1]);
%! solid.surface (X, Y, zeros (size (X)), 1)
%!error<solid.surface: the grid must be open, but its first and last rows or columns meet.> ...
%! [t, Z] = meshgrid (0:90:360, [0, 1]);
%! solid.surface (cosd (t), sind (t), Z, 1)
