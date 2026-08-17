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
## @deftypefn  {drafting} {@var{N} =} draw.colour (@var{NAME})
## @deftypefnx {drafting} {@var{RGB} =} draw.colour (@var{N})
## @deftypefnx {drafting} {@var{NAMES} =} draw.colour ()
##
## Convert between colour names, drawing colour numbers and RGB.
##
## @code{@var{N} = draw.colour (@var{NAME})} returns the colour number of a
## named colour, for storing on an entity.
##
## @code{@var{RGB} = draw.colour (@var{N})} returns the colour number rendered
## as a 1-by-3 vector of red, green and blue in @math{[0, 1]}, which is what a
## backend drawing to a screen or to LaTeX needs.
##
## @code{@var{NAMES} = draw.colour ()} lists the names that have one.
##
## @subheading Colours are numbers, and the number is what is stored
##
## Entities carry a colour @emph{index}, not a triple.  That is the model DXF
## uses and it is the one this package stores, so that a drawing written and
## read back is unchanged.  Index 256 means @qcode{'byLayer'} --- take the
## layer's colour --- and 0 means @qcode{'byBlock'}.  Both are carried through
## the file faithfully.
##
## @multitable @columnfractions 0.10 0.20 0.70
## @headitem N @tab Name @tab
## @item 1 @tab @qcode{'red'} @tab
## @item 2 @tab @qcode{'yellow'} @tab
## @item 3 @tab @qcode{'green'} @tab
## @item 4 @tab @qcode{'cyan'} @tab
## @item 5 @tab @qcode{'blue'} @tab
## @item 6 @tab @qcode{'magenta'} @tab
## @item 7 @tab @qcode{'white'} @tab drawn black on white paper
## @item 8 @tab @qcode{'grey'} @tab
## @item 0 @tab @qcode{'byBlock'} @tab
## @item 256 @tab @qcode{'byLayer'} @tab the default
## @end multitable
##
## Indices from 9 to 255 are valid and are carried through, but only the ten
## above have names and known renderings.  An unnamed index renders as a mid
## grey rather than raising, so that a file from elsewhere still draws.
##
## @strong{No true colour.}  The DXF revision this package writes carries an
## index and nothing else, so an arbitrary RGB triple cannot be represented.
## That is a limit of the format, not of this function, and it is why the index
## is what gets stored.
##
## @seealso{draw.Drawing, draw.linetype, dxf.write}
## @end deftypefn

function OUT = colour (varargin)

  ## Input validation
  if (numel (varargin) > 1)
    error ("draw.colour: invalid number of input arguments.");
  endif
  nin = numel (varargin);

  T = {'byBlock', 0,   [0.0, 0.0, 0.0]; ...
       'red',     1,   [1.0, 0.0, 0.0]; ...
       'yellow',  2,   [1.0, 1.0, 0.0]; ...
       'green',   3,   [0.0, 1.0, 0.0]; ...
       'cyan',    4,   [0.0, 1.0, 1.0]; ...
       'blue',    5,   [0.0, 0.0, 1.0]; ...
       'magenta', 6,   [1.0, 0.0, 1.0]; ...
       'white',   7,   [0.0, 0.0, 0.0]; ...
       'grey',    8,   [0.5, 0.5, 0.5]; ...
       'byLayer', 256, [0.0, 0.0, 0.0]};

  if (nin == 0)
    OUT = T(:,1)';
    return;
  endif
  ARG = varargin{1};

  if (ischar (ARG) && isrow (ARG) && ! isempty (ARG))
    k = find (strcmpi (ARG, T(:,1)), 1);
    if (isempty (k))
      error (strcat ("draw.colour: '%s' is not a named colour; use", ...
                     " draw.colour () for the list."), ARG);
    endif
    OUT = T{k,2};
    return;
  endif

  if (isnumeric (ARG) && isreal (ARG) && isscalar (ARG) && isfinite (ARG) ...
      && ARG == fix (ARG) && ARG >= 0 && ARG <= 256)
    k = find (ARG == [T{:,2}], 1);
    if (isempty (k))
      OUT = [0.5, 0.5, 0.5];       # valid but unnamed: render, do not raise
    else
      OUT = T{k,3};
    endif
    return;
  endif

  error (strcat ("draw.colour: ARG must be a colour name or an integer", ...
                 " index from 0 to 256."));

endfunction

%!test  # names map to their indices
%! assert_equal (draw.colour ('red'), 1);
%! assert_equal (draw.colour ('byLayer'), 256);
%! assert_equal (draw.colour ('byBlock'), 0);

%!test  # indices render as RGB in the unit interval
%! rgb = draw.colour (1);
%! assert_equal (rgb, [1, 0, 0]);
%! assert_equal (all (rgb >= 0 & rgb <= 1), true);

%!test  # white is drawn black, because paper is white
%! assert_equal (draw.colour (7), [0, 0, 0]);

%!test  # the list is every named colour
%! N = draw.colour ();
%! assert_equal (iscellstr (N), true);
%! assert_equal (numel (N), 10);

%!test  # every name round-trips to a renderable index
%! for n = draw.colour ()
%!   rgb = draw.colour (draw.colour (n{1}));
%!   assert_equal (numel (rgb), 3);
%! endfor

%!test  # names are matched without regard to case
%! assert_equal (draw.colour ('RED'), draw.colour ('red'));

%!test  # a valid but unnamed index renders rather than raising
%! assert_equal (draw.colour (137), [0.5, 0.5, 0.5]);

%!error<draw.colour: invalid number of input arguments.> draw.colour (1, 2)
%!error<draw.colour: 'puce' is not a named colour; use draw.colour \(\) for the list.> ...
%! draw.colour ('puce')
%!error<draw.colour: ARG must be a colour name or an integer index from 0 to 256.> ...
%! draw.colour (257)
%!error<draw.colour: ARG must be a colour name or an integer index from 0 to 256.> ...
%! draw.colour (2.5)
%!error<draw.colour: ARG must be a colour name or an integer index from 0 to 256.> ...
%! draw.colour ({1})
