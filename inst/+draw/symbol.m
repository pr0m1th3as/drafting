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
## @deftypefn  {drafting} {@var{CODE} =} draw.symbol (@var{NAME})
## @deftypefnx {drafting} {@var{NAMES} =} draw.symbol ()
##
## The code that stands for a drawing symbol in a text string.
##
## @code{@var{CODE} = draw.symbol (@var{NAME})} returns the sequence that means
## one of the symbols a drawing needs but a plain character set has no letter
## for.  Put it in any text --- a dimension label, a note, a title block field
## --- and each backend renders it as the symbol.
##
## @code{@var{NAMES} = draw.symbol ()} lists the names.
##
## @multitable @columnfractions 0.16 0.14 0.70
## @headitem Name @tab Code @tab
## @item @qcode{'diameter'} @tab @code{%%c} @tab before a diameter figure
## @item @qcode{'degree'} @tab @code{%%d} @tab after an angle
## @item @qcode{'plusminus'} @tab @code{%%p} @tab before a symmetric tolerance
## @item @qcode{'percent'} @tab @code{%%%} @tab a literal per cent sign
## @end multitable
##
## @subheading Why a code and not the character
##
## The three symbols cannot simply be written into the text, because the
## backends disagree about how to carry them and none of them takes a bare
## Unicode character reliably.  The DXF revision this package writes has no
## encoding declaration at all, so a byte above 127 in a file is at the mercy of
## whatever the recipient assumes; a LaTeX backend needs a control sequence, not
## a character; and a figure renders whatever glyph its font happens to hold.
##
## These codes are the ones AutoCAD has used for the same purpose since before
## any of that was settled, so a DXF file carries them @emph{verbatim} and
## correctly, and only the other backends have to translate.  A CAD user already
## knows them, and a drawing typed by hand with @code{%%c} in a label works
## without this function ever being called.
##
## @subheading What each backend does
##
## @multitable @columnfractions 0.20 0.80
## @item @code{dxf.write} @tab writes the code unchanged; CAD renders it
## @item @code{tikz} @tab translates to LaTeX needing no extra package
## @item @code{plot} @tab substitutes a character the figure font holds
## @end multitable
##
## @seealso{draw.Drawing, draw.Drawing.tikz, draw.Drawing.plot}
## @end deftypefn

function OUT = symbol (varargin)

  ## Input validation
  if (numel (varargin) > 1)
    error ("draw.symbol: invalid number of input arguments.");
  endif

  T = {'diameter',  '%%c'; ...
       'degree',    '%%d'; ...
       'plusminus', '%%p'; ...
       'percent',   '%%%'};

  if (numel (varargin) == 0)
    OUT = T(:,1)';
    return;
  endif

  NAME = varargin{1};
  if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
    error ("draw.symbol: NAME must be a non-empty character vector.");
  endif
  k = find (strcmpi (NAME, T(:,1)), 1);
  if (isempty (k))
    error (strcat ("draw.symbol: '%s' is not a known symbol; use", ...
                   " draw.symbol () for the list."), NAME);
  endif
  OUT = T{k,2};

endfunction

%!demo
%! ## The symbols a drawing needs but a plain character set has no letter for.
%! ## Put the code in any text and each backend renders it.
%!
%! draw.symbol ()
%! draw.symbol ('diameter')
%!
%! label = [draw.symbol('diameter'), '25 ', draw.symbol('plusminus'), '0.05']

%!demo
%! ## They may be typed directly, which is what a CAD user already does.  Here
%! ## all three appear on one drawing.
%!
%! D = draw.Drawing ().circle ([0, 0], 12.5);
%! D = D.diam ([0, 0], 12.5, 135);
%! D = D.text ([-20, -25], 'BORE %%c25 %%p0.02', 3.5);
%! D = D.text ([-20, -32], 'DRAFT ANGLE 3%%d', 3.5);
%! D = D.text ([-20, -39], 'SHRINKAGE 2%%%', 3.5);
%! plot (D);
%! title ('the diameter, plus-minus and degree signs');

%!test  # the codes are AutoCAD's own
%! assert_equal (draw.symbol ('diameter'), '%%c');
%! assert_equal (draw.symbol ('degree'), '%%d');
%! assert_equal (draw.symbol ('plusminus'), '%%p');

%!test  # the list names every symbol
%! N = draw.symbol ();
%! assert_equal (iscellstr (N), true);
%! assert_equal (numel (N), 4);

%!test  # every listed name resolves
%! for n = draw.symbol ()
%!   assert_equal (ischar (draw.symbol (n{1})), true);
%! endfor

%!test  # names are matched without regard to case
%! assert_equal (draw.symbol ('DIAMETER'), draw.symbol ('diameter'));

%!test  # a code reaches a DXF file unchanged, which is the point of using it
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   D = draw.Drawing ().text ([0, 0], [draw.symbol('diameter'), '25'], 3);
%!   dxf.write (fn, entities (D));
%!   assert_equal (! isempty (strfind (fileread (fn), '%%c25')), true);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<draw.symbol: invalid number of input arguments.> ...
%! draw.symbol ('degree', 1)
%!error<draw.symbol: 'squiggle' is not a known symbol; use draw.symbol \(\) for the list.> ...
%! draw.symbol ('squiggle')
%!error<draw.symbol: NAME must be a non-empty character vector.> draw.symbol (42)
