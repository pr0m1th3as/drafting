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
## @deftypefn  {drafting} {@var{D} =} draw.coordtable (@var{P}, @var{ORIGIN})
## @deftypefnx {drafting} {@var{D} =} draw.coordtable (@dots{}, @var{Name}, @var{Value})
##
## A table of point coordinates, for a shape that cannot be dimensioned.
##
## @code{@var{D} = draw.coordtable (@var{P}, @var{ORIGIN})} returns a drawing
## holding a ruled table of the points @var{P}, one row each, with its top left
## corner at @var{ORIGIN}.  Merge it onto the sheet beside the view it belongs
## to.
##
## @subheading Why a table and not dimensions
##
## Some profiles cannot be dimensioned at all.  A cycloidal lobe, a cam, an
## aerofoil and a involute flank have no centres to measure from and no radii
## that mean anything, so a drawing of one carries a datum, a table of
## coordinates and the statement that the two together define the part.  That
## is how such a shape is inspected: the machine goes to each coordinate and the
## measurement is compared against the column.
##
## The table is therefore the dimension, and the profile in the view is
## illustrative.  Which is worth saying on the drawing, because a reader who
## scales the view instead will be wrong by whatever the plotter did.
##
## @subheading Name/Value pairs
##
## @multitable @columnfractions 0.16 0.16 0.68
## @headitem Name @tab Default @tab Meaning
## @item @qcode{'Height'} @tab 3.5 @tab text height
## @item @qcode{'Decimals'} @tab 3 @tab figures after the point
## @item @qcode{'Labels'} @tab numbers @tab cell array of row labels
## @item @qcode{'Heading'} @tab @qcode{'PT'}, @qcode{'X'}, @qcode{'Y'} @tab
## the three column headings
## @end multitable
##
## Points are written to @var{Decimals} places whatever their value, so a column
## reads as a column and a trailing zero is not silently dropped.  Three places
## is a micron in millimetres, which is finer than anything this package's own
## output is accurate to and about right for an inspection table.
##
## @seealso{draw.titleblock, draw.Drawing, geom.resample}
## @end deftypefn

function D = coordtable (P, ORIGIN, varargin)

  ## Input validation
  if (nargin < 2)
    error ("draw.coordtable: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("draw.coordtable: %s", errmsg);
  endif
  if (! isnumeric (ORIGIN) || ! isreal (ORIGIN) ...
      || ! isequal (size (ORIGIN), [1, 2]) || ! all (isfinite (ORIGIN)))
    error ("draw.coordtable: ORIGIN must be a 1-by-2 real finite point.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("draw.coordtable: Name/Value arguments must come in pairs.");
  endif

  opt = struct ('Height', 3.5, 'Decimals', 3, 'Labels', {{}}, ...
                'Heading', {{'PT', 'X', 'Y'}});
  known = fieldnames (opt);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      error ("draw.coordtable: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  if (! isnumeric (opt.Height) || ! isscalar (opt.Height) || opt.Height <= 0)
    error ("draw.coordtable: Height must be a positive scalar.");
  endif
  if (! isnumeric (opt.Decimals) || ! isscalar (opt.Decimals) ...
      || opt.Decimals < 0 || opt.Decimals != fix (opt.Decimals))
    error ("draw.coordtable: Decimals must be a non-negative integer.");
  endif
  if (! iscellstr (opt.Heading) || numel (opt.Heading) != 3)
    error ("draw.coordtable: Heading must be three character vectors.");
  endif
  n = rows (P);
  if (! isempty (opt.Labels) ...
      && (! iscellstr (opt.Labels) || numel (opt.Labels) != n))
    error (strcat ("draw.coordtable: Labels must be a cell array with one", ...
                   " entry per point."));
  endif
  if (isempty (opt.Labels))
    opt.Labels = arrayfun (@(k) sprintf ('%d', k), 1:n, 'UniformOutput', false);
  endif

  h = opt.Height;
  rowh = 1.8 * h;
  colw = [4 * h, 9 * h, 9 * h];
  W = sum (colw);

  D = draw.Drawing ('coordinate table');
  D.Layer = 'TABLE';

  ## Frame, one rule per row, one per column boundary
  top = ORIGIN(2);
  bot = top - (n + 1) * rowh;
  D = D.polyline ([ORIGIN(1), bot; ORIGIN(1) + W, bot; ...
                   ORIGIN(1) + W, top; ORIGIN(1), top], true);
  for r = 1:n
    y = top - r * rowh;
    D = D.line ([ORIGIN(1), y], [ORIGIN(1) + W, y]);
  endfor
  x = ORIGIN(1);
  for c = 1:2
    x += colw(c);
    D = D.line ([x, bot], [x, top]);
  endfor

  fmt = sprintf ('%%.%df', opt.Decimals);
  cellx = ORIGIN(1) + [0.4 * h, colw(1) + 0.4 * h, colw(1) + colw(2) + 0.4 * h];

  for c = 1:3
    D = D.text ([cellx(c), top - rowh + 0.5 * h], opt.Heading{c}, h);
  endfor
  for r = 1:n
    y = top - (r + 1) * rowh + 0.5 * h;
    D = D.text ([cellx(1), y], opt.Labels{r}, h);
    D = D.text ([cellx(2), y], sprintf (fmt, P(r,1)), h);
    D = D.text ([cellx(3), y], sprintf (fmt, P(r,2)), h);
  endfor

endfunction

%!demo
%! ## Some profiles cannot be dimensioned: a cam, an aerofoil or a cycloidal
%! ## lobe has no centres to measure from.  Such a drawing carries a datum and
%! ## a table of coordinates, and the two together define the part.
%!
%! t = linspace (0, 2*pi, 361)(1:360)';
%! P = (30 + 4 * cos (7 * t)) .* [cos(t), sin(t)];
%! pts = geom.resample (P, 10, true);
%!
%! D = draw.Drawing ().polyline (P, true);
%! D.Colour = 'red';
%! for k = 1:rows (pts)
%!   D = D.circle (pts(k,:), 1);
%!   D = D.text (pts(k,:) + [2, 2], sprintf ('%d', k), 2.5);
%! endfor
%! D = D.merge (draw.coordtable (pts, [55, 35], 'Decimals', 2));
%! plot (D, 'FontSize', 6);
%! title ('the table is the dimension; the view is illustrative');

%!test  # a table of three points has a heading row and three more
%! D = draw.coordtable ([0, 0; 1, 2; 3, 4], [0, 0]);
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (numel (txt), 12);

%!test  # the headings come first and are the defaults
%! D = draw.coordtable ([1, 2], [0, 0]);
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (txt(1:3), {'PT', 'X', 'Y'});

%!test  # coordinates are written to the stated number of places
%! D = draw.coordtable ([1.5, 2], [0, 0], 'Decimals', 2);
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (any (strcmp (txt, '1.50')), true);
%! assert_equal (any (strcmp (txt, '2.00')), true);

%!test  # a trailing zero is kept, so a column reads as a column
%! D = draw.coordtable ([10, 20], [0, 0], 'Decimals', 3);
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (any (strcmp (txt, '10.000')), true);

%!test  # rows are numbered unless labels are given
%! D = draw.coordtable ([0, 0; 1, 1], [0, 0]);
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (any (strcmp (txt, '1')) && any (strcmp (txt, '2')), true);

%!test  # labels replace the numbers
%! D = draw.coordtable ([0, 0; 1, 1], [0, 0], 'Labels', {'A', 'B'});
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (any (strcmp (txt, 'A')) && any (strcmp (txt, 'B')), true);

%!test  # the table sits on its own layer, so it can be moved or dropped
%! D = draw.coordtable ([0, 0], [0, 0]);
%! assert_equal (D.layers (), {'TABLE'});

%!test  # it grows downward from the origin given
%! D = draw.coordtable ([0, 0; 1, 1], [100, 200]);
%! [B, W, H] = bbox (D);
%! assert_equal (B(4), 200, 1e-9);
%! assert_equal (B(2) < 200, true);

%!test  # a longer table is taller, by one row per point
%! [~, ~, H2] = bbox (draw.coordtable (zeros (2, 2), [0, 0]));
%! [~, ~, H8] = bbox (draw.coordtable (zeros (8, 2), [0, 0]));
%! assert_equal (H8 > H2, true);

%!test  # it merges onto a sheet like anything else
%! t = linspace (0, 2*pi, 9)(1:8)';
%! P = 20 * [cos(t), sin(t)];
%! sheet = draw.titleblock ('A4');
%! sheet = sheet.merge (draw.coordtable (P, [40, 190]));
%! assert_equal (any (strcmp (sheet.layers (), 'TABLE')), true);

%!error<draw.coordtable: invalid number of input arguments.> ...
%! draw.coordtable ([0, 0])
%!error<draw.coordtable: ORIGIN must be a 1-by-2 real finite point.> ...
%! draw.coordtable ([0, 0], [0, 0, 0])
%!error<draw.coordtable: Decimals must be a non-negative integer.> ...
%! draw.coordtable ([0, 0], [0, 0], 'Decimals', 1.5)
%!error<draw.coordtable: Labels must be a cell array with one entry per point.> ...
%! draw.coordtable ([0, 0; 1, 1], [0, 0], 'Labels', {'A'})
%!error<draw.coordtable: unknown parameter.> ...
%! draw.coordtable ([0, 0], [0, 0], 'Columns', 3)
%!error<draw.coordtable: P must be a real numeric matrix.> ...
%! draw.coordtable ({1, 2}, [0, 0])
%!error<draw.coordtable: P must be an N-by-2 matrix of point coordinates.> ...
%! draw.coordtable (ones (3, 3), [0, 0])
%!error<draw.coordtable: P must contain at least one point.> ...
%! draw.coordtable (zeros (0, 2), [0, 0])
%!error<draw.coordtable: P must not contain NaN or Inf values.> ...
%! draw.coordtable ([0, 0; 1, 1; 2, 2; NaN, 3], [0, 0])
