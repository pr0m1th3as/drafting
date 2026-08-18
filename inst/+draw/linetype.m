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
## @item @qcode{'PHANTOM'} @tab long-short-short; alternate positions
## @item @qcode{'DASHED'} @tab even dashes
## @item @qcode{'DASHDOT'} @tab dash and dot
## @item @qcode{'DOT'} @tab dots only
## @end multitable
##
## The names follow the CAD convention rather than the ISO 128 line-type
## numbering, because they are what a DXF file and every CAD program expect to
## see.
##
## @subheading One rule for the lengths, everywhere
##
## The lengths are @strong{model} dimensions, multiplied by a line-type scale
## factor.  That is the rule CAD uses --- its @code{LTSCALE} --- and it is the
## rule every backend here follows, because a DXF line-type table defines the
## lengths that way and the file backend has no choice.
##
## Each backend defaults the factor to whatever makes its own medium sensible,
## and each lets a caller say otherwise:
##
## @multitable @columnfractions 0.24 0.24 0.52
## @headitem Backend @tab Default @tab
## @item @code{plot} @tab 1 @tab on screen at 1:1 the pattern is already
## the right size
## @item @code{tikz} @tab the drawing scale @tab cancels the reduction, so
## dashes reach the page at nominal size
## @item @code{dxf.write} @tab 1 @tab written into the file as
## @code{$LTSCALE}, so the recipient's CAD does not supply its own
## @end multitable
##
## A centre line therefore reads as a centre line whether its view is drawn at
## 1:1 or at 1:50, without the package having to hold two contradictory ideas of
## what a dash length means.
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
  T = {'CONTINUOUS', [], ...
                                            'Solid line'; ...
       'HIDDEN',     [0.25, -0.125], ...
                                            'Hidden ______ ______'; ...
       'CENTER',     [1.25, -0.25, 0.25, -0.25], ...
                                            'Center ____ _ ____'; ...
       'PHANTOM',    [1.25, -0.25, 0.25, -0.25, 0.25, -0.25], ...
                                            'Phantom ____ _ _ ____'; ...
       'DASHED',     [0.5, -0.25], ...
                                            'Dashed __ __ __'; ...
       'DASHDOT',    [0.5, -0.25, 0, -0.25], ...
                                            'Dash dot __ . __ .'; ...
       'DOT',        [0, -0.25], ...
                                            'Dot . . . . .'};

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

%!demo
%! ## The seven standard line types, by name, with the dash pattern each
%! ## carries.  A positive element draws, a negative one skips, a zero is a dot.
%!
%! draw.linetype ()
%! draw.linetype ('CENTER')
%! [pat, descr] = draw.linetype ('PHANTOM')

%!demo
%! ## What each one is for, drawn.  A centre line marks an axis, a hidden line
%! ## an edge concealed by the body, a phantom line an alternate position.
%!
%! D = draw.Drawing ();
%! D = D.polyline ([0, 0; 60, 0; 60, 30; 0, 30], true);
%! D.Linetype = 'HIDDEN';
%! D = D.line ([20, 0], [20, 30]).line ([40, 0], [40, 30]);
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! D = D.line ([-6, 15], [66, 15]);
%! D.Linetype = 'PHANTOM';
%! D.Colour = 'blue';
%! D = D.polyline ([0, 36; 60, 36; 60, 60; 0, 60], true);
%! plot (D);
%! title ('visible, hidden, centre and phantom');

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
