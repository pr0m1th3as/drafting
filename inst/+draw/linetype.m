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
## @deftypefn  {drafting} {@var{NAMES} =} draw.linetype ()
## @deftypefnx {drafting} {@var{PATTERN} =} draw.linetype (@var{NAME})
## @deftypefnx {drafting} {[@var{PATTERN}, @var{DESCR}] =} draw.linetype (@var{NAME})
##
## Dash patterns of the standard line types.
##
## @code{@var{NAMES} = draw.linetype ()} returns the names of every line type
## the package defines, as a cell array of character vectors.
##
## @code{@var{PATTERN} = draw.linetype (@var{NAME})} returns the dash pattern of
## one of them, as a row vector in millimetres.  A positive element is a drawn
## dash, a negative element a gap, and a zero a dot.  @code{'CONTINUOUS'} has an
## empty pattern.
##
## @code{[@var{PATTERN}, @var{DESCR}] = draw.linetype (@var{NAME})} also returns
## a human-readable description, which is what a DXF line-type table carries.
##
## @subheading The set
##
## @multitable @columnfractions 0.18 0.82
## @item @qcode{'CONTINUOUS'} @tab unbroken; visible edges
## @item @qcode{'HIDDEN'} @tab short dashes; edges concealed by the body
## @item @qcode{'CENTER'} @tab long-short-long; axes of symmetry, pitch circles
## @item @qcode{'PHANTOM'} @tab long-short-short; alternate positions, adjacent parts
## @item @qcode{'DASHED'} @tab even dashes
## @item @qcode{'DASHDOT'} @tab dash and dot
## @item @qcode{'DOT'} @tab dots only
## @end multitable
##
## The names follow the CAD convention rather than the ISO 128 line-type
## numbering, because they are what a DXF file and every CAD program expect to
## see.
##
## The lengths are @strong{paper-space}: they are the size the dashes should
## appear on the page, not model dimensions to be scaled with the geometry.  A
## centre line has to read as a centre line whether its view is drawn at 1:1 or
## at 1:50, and scaling the pattern down with the drawing would make it vanish.
## The rendering backends emit them at nominal size for that reason; CAD applies
## its own line-type scale factor to the same effect.
##
## @subheading Line types are names, not an enumeration
##
## Nothing in this package restricts an entity to these seven.  A name it does
## not recognise is carried through to the output unchanged, so a drawing may
## use a line type defined by the receiving CAD installation or by a company
## standard.  Only the ones listed here can have their pattern written into a
## DXF line-type table; an unknown name is emitted by name alone, which is
## exactly how a CAD file refers to a line type its recipient already has.
##
## @seealso{draw.Drawing, draw.colour, dxf.write}
## @end deftypefn

function [PATTERN, DESCR] = linetype (varargin)

  ## Input validation
  if (numel (varargin) > 1)
    error ("draw.linetype: invalid number of input arguments.");
  endif
  nin = numel (varargin);

  ## Pattern elements in millimetres at 1:1; positive draws, negative skips
  T = {'CONTINUOUS', [],                                    'Solid line'; ...
       'HIDDEN',     [0.25, -0.125],                        'Hidden ______ ______'; ...
       'CENTER',     [1.25, -0.25, 0.25, -0.25],            'Center ____ _ ____'; ...
       'PHANTOM',    [1.25, -0.25, 0.25, -0.25, 0.25, -0.25], 'Phantom ____ _ _ ____'; ...
       'DASHED',     [0.5, -0.25],                          'Dashed __ __ __'; ...
       'DASHDOT',    [0.5, -0.25, 0, -0.25],                'Dash dot __ . __ .'; ...
       'DOT',        [0, -0.25],                            'Dot . . . . .'};

  if (nin == 0)
    PATTERN = T(:,1)';
    return;
  endif
  NAME = varargin{1};

  if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
    error ("draw.linetype: NAME must be a non-empty character vector.");
  endif

  k = find (strcmpi (NAME, T(:,1)), 1);
  if (isempty (k))
    error (strcat ("draw.linetype: '%s' is not a defined line type; use", ...
                   " draw.linetype () for the list."), NAME);
  endif
  PATTERN = T{k,2};
  if (nargout > 1)
    DESCR = T{k,3};
  endif

endfunction

%!test  # the list names every defined type
%! N = draw.linetype ();
%! assert_equal (iscellstr (N), true);
%! assert_equal (numel (N), 7);
%! assert_equal (any (strcmp ('CENTER', N)), true);

%!test  # a solid line has no pattern
%! assert_equal (draw.linetype ('CONTINUOUS'), []);

%!test  # a centre line is long-short-long
%! P = draw.linetype ('CENTER');
%! assert_equal (P, [1.25, -0.25, 0.25, -0.25]);

%!test  # every listed type resolves, and its pattern alternates in sign
%! for n = draw.linetype ()
%!   P = draw.linetype (n{1});
%!   assert_equal (isempty (P) || all (P(1:2:end) >= 0), true);
%!   assert_equal (isempty (P) || all (P(2:2:end) < 0), true);
%! endfor

%!test  # names are matched without regard to case
%! assert_equal (draw.linetype ('hidden'), draw.linetype ('HIDDEN'));

%!test  # a description comes back for the line-type table
%! [P, D] = draw.linetype ('DASHED');
%! assert_equal (ischar (D) && ! isempty (D), true);

%!test  # a dot is a zero-length dash
%! P = draw.linetype ('DOT');
%! assert_equal (P(1), 0);

%!error<draw.linetype: invalid number of input arguments.> ...
%! draw.linetype ('DASHED', 1)
%!error<draw.linetype: NAME must be a non-empty character vector.> ...
%! draw.linetype (42)
%!error<draw.linetype: 'WIGGLY' is not a defined line type; use draw.linetype \(\) for the list.> ...
%! draw.linetype ('WIGGLY')
