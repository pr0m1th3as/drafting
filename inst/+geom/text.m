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
## @deftypefn  {drafting} {@var{R} =} geom.text (@var{STR})
## @deftypefnx {drafting} {@var{R} =} geom.text (@var{STR}, @var{Name}, @var{Value}, @dots{})
##
## The outlines of text, as regions.
##
## @code{@var{R} = geom.text (@var{STR})} returns the shapes of the letters
## of the character vector @var{STR}, in UTF-8, as a 1-by-@math{N} cell array
## of @code{geom.Region} objects, one for each separate piece of ink, largest
## first, or the empty @code{cell (1, 0)} when there is none.  A letter with a
## counter, such as @qcode{o} or @qcode{A}, is a region with a hole; one in
## pieces, such as @qcode{i}, is several regions.  The outlines are the
## font's own curves, straight lines and splines, so the text is as smooth at
## any size.  A newline in @var{STR} starts a new line.  This is OpenSCAD's
## @code{text}, ready to be extruded, engraved or embossed.
##
## By default the text stands on the @math{x} axis of the world @math{xy}
## plane, starting at the origin, its capitals 10 millimetres high.
##
## Name/Value pairs:
##
## @table @asis
## @item @qcode{'Height'}
## The height of a capital letter in millimetres, as text is sized on a
## technical drawing, 10 by default.  Lower case, ascenders and descenders
## follow the font.
##
## @item @qcode{'Font'}
## The name of an installed font family, such as @qcode{'DejaVu Sans'};
## @qcode{'sans-serif'}, @qcode{'serif'} and @qcode{'monospace'} name the
## system's own.  The default is @qcode{'sans-serif'}.  A font that is not
## installed is an error.
##
## @item @qcode{'Style'}
## @qcode{'regular'}, the default, @qcode{'bold'}, @qcode{'italic'} or
## @qcode{'bold italic'}.
##
## @item @qcode{'HAlign'}
## Which part of the text lies on the origin across: @qcode{'left'}, the
## default, @qcode{'center'} or @qcode{'right'}, by the box round the ink.
##
## @item @qcode{'VAlign'}
## Which part lies on the origin upwards: @qcode{'baseline'}, the default,
## the line the letters stand on, or @qcode{'bottom'}, @qcode{'center'} or
## @qcode{'top'} of the box round the ink.
##
## @item @qcode{'UCS'}
## The @code{geom.UCS} the text is laid in, the world @math{xy} plane by
## default.
## @end table
##
## @example
## @group
## ## A plate with its name raised 1 on its top face
## P = solid.box (60, 20, 4);
## R = geom.text ('DRAFTING', 'Height', 8, 'HAlign', 'center', ...
##                'VAlign', 'center', 'UCS', geom.UCS ([0, 0, 1], [30, 10, 4]));
## for k = 1:numel (R)
##   P = union (P, solid.extrude (R@{k@}, 1));
## endfor
## @end group
## @end example
##
## Open CASCADE builds the outlines from the font.
##
## @seealso{geom.Region, solid.extrude, geom.Region.offset}
## @end deftypefn

function R = text (STR, varargin)

  ## Input validation
  if (nargin < 1)
    error ("geom.text: invalid number of input arguments.");
  endif
  if (! ischar (STR) || ! (isrow (STR) || isempty (STR)))
    error ("geom.text: STR must be a character vector.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("geom.text: Name/Value arguments must come in pairs.");
  endif
  opt = struct ('Height', 10, 'Font', '', 'Style', 'regular', ...
                'HAlign', 'left', 'VAlign', 'baseline', 'UCS', geom.UCS ());
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("geom.text: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'height'
        opt.Height = val;
      case 'font'
        opt.Font = val;
      case 'style'
        opt.Style = val;
      case 'halign'
        opt.HAlign = val;
      case 'valign'
        opt.VAlign = val;
      case 'ucs'
        opt.UCS = val;
      otherwise
        error ("geom.text: unknown option '%s'.", name);
    endswitch
  endfor
  H = opt.Height;
  if (! isnumeric (H) || ! isreal (H) || ! isscalar (H) || ! isfinite (H)
      || ! (H > 0))
    error ("geom.text: Height must be a positive and finite real scalar.");
  endif
  if (! ischar (opt.Font) || ! (isrow (opt.Font) || isempty (opt.Font)))
    error ("geom.text: Font must be a character vector.");
  endif
  styles = {'regular', 'bold', 'italic', 'bold italic'};
  style = find (strcmp (opt.Style, styles));
  if (! ischar (opt.Style) || isempty (style))
    error (strcat ("geom.text: Style must be 'regular', 'bold', 'italic'", ...
                   " or 'bold italic'."));
  endif
  ha = {'left', 'center', 'right'};
  if (! ischar (opt.HAlign) || ! any (strcmp (opt.HAlign, ha)))
    error ("geom.text: HAlign must be 'left', 'center' or 'right'.");
  endif
  va = {'baseline', 'bottom', 'center', 'top'};
  if (! ischar (opt.VAlign) || ! any (strcmp (opt.VAlign, va)))
    error (strcat ("geom.text: VAlign must be 'baseline', 'bottom',", ...
                   " 'center' or 'top'."));
  endif
  if (! isa (opt.UCS, 'geom.UCS') || ! isscalar (opt.UCS))
    error ("geom.text: UCS must be a geom.UCS object.");
  endif

  font = opt.Font;
  strict = ! isempty (font);
  if (! strict)
    font = 'sans-serif';
  endif
  [D, B] = __occtfont__ ('geom.text', STR, font, style - 1, double (H), ...
                         strict);
  R = cell (1, 0);
  if (isempty (D))
    return;
  endif

  ## The point of the text that lies on the origin
  x = [B(1), (B(1) + B(3)) / 2, B(3)](strcmp (opt.HAlign, ha));
  y = [0, B(2), (B(2) + B(4)) / 2, B(4)](strcmp (opt.VAlign, va));
  F = __occt__ ('faces2d', 'geom.text', D, ...
                [x, y, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1], true);
  R = geom.Region.__faces__ (F, opt.UCS);

endfunction

## The box round the ink of the regions R, in their UCS
%!function B = inkbox (R)
%!  Q = cell2mat (cellfun (@(r) __sample__ (r.Outline)(:,1:2), R(:), ...
%!                         'UniformOutput', false));
%!  B = [min(Q, [], 1), max(Q, [], 1)];
%!endfunction

%!test
%! ## A capital is the height asked, on the baseline, from the origin
%! R = geom.text ('H', 'Height', 7);
%! assert_equal (numel (R), 1);
%! B = inkbox (R);
%! assert_equal (B([2, 4]), [0, 7], 1e-6);
%! assert_equal (B(1) >= 0, true);

%!test
%! ## A counter is a hole, a dotted letter two pieces, a descender below
%! R = geom.text ('o');
%! assert_equal (numel (R{1}.Holes), 1);
%! assert_equal (numel (geom.text ('i')), 2);
%! B = inkbox (geom.text ('g'));
%! assert_equal (B(2) < 0, true);
%! assert_equal (geom.text (''), cell (1, 0));
%! assert_equal (geom.text ('   '), cell (1, 0));

%!test
%! ## Aligned on the origin by the box round the ink
%! R = geom.text ('HELLO', 'HAlign', 'center', 'VAlign', 'center');
%! B = inkbox (R);
%! assert_equal ((B(1) + B(3)) / 2, 0, 1e-6);
%! assert_equal ((B(2) + B(4)) / 2, 0, 1e-6);
%! B = inkbox (geom.text ('HELLO', 'HAlign', 'right', 'VAlign', 'top'));
%! assert_equal (B([3, 4]), [0, 0], 1e-6);

%!test
%! ## Laid in a UCS, and bold wider than regular
%! U = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! R = geom.text ('A', 'UCS', U);
%! assert_equal (R{1}.UCS, U);
%! B1 = inkbox (geom.text ('W'));
%! B2 = inkbox (geom.text ('W', 'Style', 'bold'));
%! assert_equal (B2(3) - B2(1) > B1(3) - B1(1), true);

%!test
%! ## Extruded into a valid solid
%! R = geom.text ('A');
%! S = solid.extrude (R{1}, 2);
%! assert_equal (isvalid (S), true);
%! assert_equal (volume (S), 2 * (__area__ (R{1}.Outline) ...
%!                                + __area__ (R{1}.Holes{1})), -1e-9);

%!error<geom.text: invalid number of input arguments.> geom.text ()
%!error<geom.text: STR must be a character vector.> geom.text (5)
%!error<geom.text: Name/Value arguments must come in pairs.> ...
%! geom.text ('A', 'Height')
%!error<geom.text: unknown option 'Size'.> geom.text ('A', 'Size', 5)
%!error<geom.text: option names must be character vectors.> geom.text ('A', 1, 5)
%!test  # option names ignore case
%! T1 = geom.text ('H', 'height', 5);
%! T2 = geom.text ('H', 'Height', 5);
%! assert_equal (isequal (solid.extrude (T1{1}, 1), ...
%!                       solid.extrude (T2{1}, 1)), true);
%!error<geom.text: Height must be a positive and finite real scalar.> ...
%! geom.text ('A', 'Height', 0)
%!error<geom.text: Font must be a character vector.> ...
%! geom.text ('A', 'Font', 3)
%!error<geom.text: Style must be 'regular', 'bold', 'italic' or 'bold italic'.> ...
%! geom.text ('A', 'Style', 'heavy')
%!error<geom.text: HAlign must be 'left', 'center' or 'right'.> ...
%! geom.text ('A', 'HAlign', 'middle')
%!error<geom.text: VAlign must be 'baseline', 'bottom', 'center' or 'top'.> ...
%! geom.text ('A', 'VAlign', 'middle')
%!error<geom.text: UCS must be a geom.UCS object.> ...
%! geom.text ('A', 'UCS', 1)
%!error<geom.text: the font 'No Such Font Anywhere' is not installed.> ...
%! geom.text ('A', 'Font', 'No Such Font Anywhere')
