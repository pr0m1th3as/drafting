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
## @deftypefn  {drafting} {@var{H} =} solid.holespec (@var{NAME})
## @deftypefnx {drafting} {@var{H} =} solid.holespec (@var{NAME}, @var{Name}, @var{Value}, @dots{})
##
## The dimensions of the hole for a metric screw, read from its thread.
##
## @code{@var{H} = solid.holespec (@var{NAME})} returns the hole
## @code{solid.Shape.hole} drills for the thread @var{NAME}, as
## @code{solid.threadspec} reads it, and @code{@var{H} = solid.holespec
## (@var{NAME}, @var{Name}, @var{Value}, @dots{})} the hole the same
## options give @code{solid.Shape.hole}, so that a hole can be laid out
## from its numbers before it is drilled.  @var{H} is a struct with the
## fields:
##
## @multitable @columnfractions 0.16 0.84
## @item @code{name} @tab @var{NAME} as given.
## @item @code{clearance} @tab The series of the clearance hole,
## @qcode{'fine'}, @qcode{'medium'} or @qcode{'coarse'}, empty for a hole
## tapped for the thread.
## @item @code{drill} @tab The diameter of the hole in millimetres: the
## clearance hole of ISO 273, or the drill for tapping the thread.
## @item @code{counterbore} @tab @code{[@var{CD}, @var{CDEPTH}]}, the
## diameter and the depth of the counterbore, empty when there is none.
## @item @code{countersink} @tab @code{[@var{CD}, @var{ANGLE},
## @var{CDEPTH}]}, the diameter of the countersink at the surface, its
## included angle in degrees and the depth of the cylinder of diameter
## @var{CD} above the cone, empty when there is none.
## @end multitable
##
## Without @qcode{'Clearance'} the hole is drilled for tapping the thread:
## the drill of ISO 2306, or the one @qcode{'Material'} or
## @qcode{'Engagement'} chooses inside the 6H band of its minor diameter,
## as @code{solid.Shape.hole} describes.  With @qcode{'Clearance'} it is
## the clearance hole for a screw of that thread, and only then can it take
## a counterbore or a countersink.
##
## Name/Value pairs:
##
## @table @asis
## @item @qcode{'Clearance'}
## The series of the clearance hole of ISO 273:1979, @qcode{'fine'},
## @qcode{'medium'} or @qcode{'coarse'}: 5.3, 5.5 and 5.8 for M5, 6.4, 6.6
## and 7 for M6.  The table is read by the nominal diameter, from M1 to
## M64; a diameter it does not list, as M5.5, is an error.
##
## @item @qcode{'Counterbore'}
## True for the counterbore of IS 3406 (Part 2):1986, type K, for a
## socket head cap screw of ISO 4762 from M1.6 to M36: 11 wide and 6.8 deep
## for M6.  @qcode{'washer'} for its type K2, for the same screw on a plain
## washer, from M3 to M36: 13 wide and 8.5 deep for M6.  Or
## @code{[@var{CD}, @var{CDEPTH}]}, taken as given.  Both standard ones are
## for a fine or a medium clearance hole.
##
## @item @qcode{'Countersink'}
## True for the countersink of IS 3406 (Part 1):1986, type A, for the
## countersunk heads of ISO 7721, as on ISO 2009, ISO 7046, ISO 14581 and
## their raised kinds, from M1 to M20.  @qcode{'socket'} for its type B,
## for the hexagon socket countersunk screws of ISO 10642, from M3 to M24.
## Type A has a medium and a fine series, chosen by @qcode{'Clearance'}:
## a plain cone in the medium series, 12.4 wide at the surface for M6, and
## in the fine series a cone below a short cylinder of the same width, 11.5
## wide and 0.45 deep for M6.  Type B is in the fine series only.  Or
## @var{CD}, @code{[@var{CD}, @var{ANGLE}]} or @code{[@var{CD},
## @var{ANGLE}, @var{CDEPTH}]}, taken as given, with an angle of 90 and no
## cylinder by default.
##
## @item @qcode{'Material'}
## @itemx @qcode{'Engagement'}
## The material tapped, or the thread engagement, which choose the drill of
## a tapped hole as in @code{solid.Shape.hole}.
##
## @item @qcode{'Custom'}
## True to take a thread of any diameter and pitch, as in
## @code{solid.threadspec}.
## @end table
##
## A counterbore and a countersink cannot both be given.  False for either
## is the same as leaving it out.
##
## IS 3406 was prepared from DIN 74, parts 1 and 2, of 1980, the forerunners
## of ISO 15065 and DIN 974-1, whose current editions were not read.  Where
## each number comes from is set out on the Standards page of the guide.
##
## @example
## @group
## ## The hole for an M6 cap screw, its head sunk in a counterbore
## H = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', true);
## H.drill
## @result{} 6.6000
## H.counterbore
## @result{} 11.0000    6.8000
## @end group
## @end example
##
## @seealso{solid.Shape.hole, solid.threadspec}
## @end deftypefn

function H = holespec (NAME, varargin)

  ## Input validation
  if (nargin < 1 || mod (nargin, 2) != 1)
    error ("solid.holespec: invalid number of input arguments.");
  endif
  clearance = '';
  counterbore = [];
  countersink = [];
  material = '';
  engagement = [];
  custom = {};
  for i = 1:2:numel (varargin)
    name = varargin{i};
    value = varargin{i+1};
    if (! ischar (name) || ! isrow (name))
      error ("solid.holespec: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'clearance'
        if (! ischar (value)
            || ! any (strcmpi (value, {'fine', 'medium', 'coarse'})))
          error (strcat ("solid.holespec: 'Clearance' must be 'fine',", ...
                         " 'medium' or 'coarse'."));
        endif
        clearance = lower (value);
      case 'counterbore'
        if (islogical (value) && isscalar (value))
          if (value)
            counterbore = true;
          endif
        elseif (ischar (value) && strcmpi (value, 'washer'))
          counterbore = 'washer';
        elseif (isnumeric (value) && isreal (value) && numel (value) == 2
                && all (isfinite (value)) && all (value > 0))
          counterbore = double (value(:)');
        else
          error (strcat ("solid.holespec: 'Counterbore' must be true,", ...
                         " false, 'washer' or [CD, CDEPTH]."));
        endif
      case 'countersink'
        if (islogical (value) && isscalar (value))
          if (value)
            countersink = true;
          endif
        elseif (ischar (value) && strcmpi (value, 'socket'))
          countersink = 'socket';
        elseif (isnumeric (value) && isreal (value) && isvector (value)
                && numel (value) <= 3 && all (isfinite (value)))
          countersink = [double(value(:)'), 90, 0](1:3);
          if (numel (value) == 2)
            countersink(3) = 0;
          endif
          if (! (countersink(1) > 0) || ! (countersink(2) > 0)
              || ! (countersink(2) < 180) || ! (countersink(3) >= 0))
            error (strcat ("solid.holespec: 'Countersink' must be true,", ...
                           " false, 'socket', CD, [CD, ANGLE] or", ...
                           " [CD, ANGLE, CDEPTH]."));
          endif
        else
          error (strcat ("solid.holespec: 'Countersink' must be true,", ...
                         " false, 'socket', CD, [CD, ANGLE] or", ...
                         " [CD, ANGLE, CDEPTH]."));
        endif
      case 'material'
        if (! ischar (value) || ! isrow (value))
          error ("solid.holespec: 'Material' must be a character vector.");
        endif
        material = value;
      case 'engagement'
        if (! isnumeric (value) || ! isreal (value) || ! isscalar (value)
            || ! isfinite (value))
          error (strcat ("solid.holespec: 'Engagement' must be a real", ...
                         " and finite scalar."));
        endif
        engagement = value;
      case 'custom'
        custom = {'Custom', value};
      otherwise
        error ("solid.holespec: unknown option '%s'.", name);
    endswitch
  endfor
  if (! isempty (counterbore) && ! isempty (countersink))
    error (strcat ("solid.holespec: 'Counterbore' and 'Countersink'", ...
                   " cannot both be given."));
  endif
  if (isempty (clearance) && (! isempty (counterbore)
                              || ! isempty (countersink)))
    error (strcat ("solid.holespec: 'Counterbore' and 'Countersink'", ...
                   " apply only to a clearance hole."));
  endif
  if (! isempty (clearance) && (! isempty (material)
                                || ! isempty (engagement)))
    error (strcat ("solid.holespec: 'Material' and 'Engagement' apply", ...
                   " only to a tapped hole."));
  endif
  if (! isempty (material) && ! isempty (engagement))
    error (strcat ("solid.holespec: 'Material' and 'Engagement' cannot", ...
                   " both be given."));
  endif
  T = solid.threadspec (NAME, custom{:});

  ## The hole: for tapping, the drill of the thread or the one MATERIAL or
  ## ENGAGEMENT chooses inside the 6H band; else the clearance hole, ISO 273
  if (isempty (clearance))
    lo = T.minor(1);
    hi = T.minor(2);
    drill = T.drill;
    if (T.custom)
      if (isempty (drill))
        error (strcat ("solid.holespec: %s: no drill of a 0.05 step lies", ...
                       " in the 6H band of its minor diameter."), NAME);
      endif
      ## The steps of 0.05 in the band
      C = (ceil (20 * lo - 1e-6):floor (20 * hi + 1e-6)) / 20;
    else
      ## The drills a maker sells, and the ISO 2306 one, in the band
      C = [drillsizes(), drill];
      C = C(C >= lo - 1e-9 & C <= hi + 1e-9);
    endif
    if (! isempty (material))
      switch (lower (material))
        case {'stainless', 'nickel'}
          drill = max (C);
        case {'steel', 'aluminium', 'brass', 'castiron', 'plastic'}
        otherwise
          error ("solid.holespec: unknown material '%s'.", material);
      endswitch
    elseif (! isempty (engagement))
      h = 1.25 * sqrt (3) / 2 * T.P;
      e0 = (T.d - hi) / h * 100;
      if (engagement > 100 + 1e-9 || engagement < e0 - 1e-9)
        error (strcat ("solid.holespec: %s: engagement must lie between", ...
                       " %.1f and 100 %%."), NAME, e0);
      endif
      [~, k] = min (abs (C - (T.d - h * engagement / 100)));
      drill = C(k);
    endif
  else
    drill = iso273 (T.d, clearance);
    if (isempty (drill))
      error ("solid.holespec: ISO 273 gives no clearance hole for %s.", ...
             NAME);
    endif
  endif

  ## The standard counterbore, IS 3406 (Part 2), type K or K2
  if (islogical (counterbore) || ischar (counterbore))
    washer = ischar (counterbore);
    counterbore = [];
    if (! strcmp (clearance, 'coarse'))
      counterbore = cbore (T.d, washer);
    endif
    if (isempty (counterbore))
      error (strcat ("solid.holespec: IS 3406 gives no counterbore for", ...
                     " a %s clearance hole for %s."), clearance, NAME);
    endif
  endif

  ## The standard countersink, IS 3406 (Part 1), type A or B
  if (islogical (countersink) || ischar (countersink))
    socket = ischar (countersink);
    countersink = [];
    if (! strcmp (clearance, 'coarse'))
      countersink = csink (T.d, socket, strcmp (clearance, 'fine'));
    endif
    if (isempty (countersink))
      error (strcat ("solid.holespec: IS 3406 gives no countersink for", ...
                     " a %s clearance hole for %s."), clearance, NAME);
    endif
  endif

  H = struct ('name', NAME, 'clearance', clearance, 'drill', drill, ...
              'counterbore', counterbore, 'countersink', countersink);

endfunction

## The clearance hole ISO 273:1979 gives the nominal diameter D in the
## SERIES 'fine', 'medium' or 'coarse', read in IS 1821:1987; empty for a
## diameter it does not list
function dh = iso273 (D, SERIES)

  T = [1, 1.1, 1.2, 1.3; 1.2, 1.3, 1.4, 1.5; 1.4, 1.5, 1.6, 1.8;
       1.6, 1.7, 1.8, 2; 1.8, 2, 2.1, 2.2; 2, 2.2, 2.4, 2.6;
       2.5, 2.7, 2.9, 3.1; 3, 3.2, 3.4, 3.6; 3.5, 3.7, 3.9, 4.2;
       4, 4.3, 4.5, 4.8; 4.5, 4.8, 5, 5.3; 5, 5.3, 5.5, 5.8;
       6, 6.4, 6.6, 7; 7, 7.4, 7.6, 8; 8, 8.4, 9, 10;
       10, 10.5, 11, 12; 12, 13, 13.5, 14.5; 14, 15, 15.5, 16.5;
       16, 17, 17.5, 18.5; 18, 19, 20, 21; 20, 21, 22, 24;
       22, 23, 24, 26; 24, 25, 26, 28; 27, 28, 30, 32;
       30, 31, 33, 35; 33, 34, 36, 38; 36, 37, 39, 42;
       39, 40, 42, 45; 42, 43, 45, 48; 45, 46, 48, 52;
       48, 50, 52, 56; 52, 54, 56, 62; 56, 58, 62, 66;
       60, 62, 66, 70; 64, 66, 70, 74];
  dh = T(T(:,1) == D, 1 + find (strcmp (SERIES, {'fine', 'medium', ...
                                                  'coarse'})));

endfunction

## The counterbore [CD, CDEPTH] IS 3406 (Part 2):1986 gives the nominal
## diameter D: type K, d2 and t1, for a socket head cap screw, or with
## WASHER type K2, d4 and t2, for one on a plain washer; empty for a
## diameter it does not give.  The depth of type K at M5 is the 5.7 of
## amendment 1 (1987).
function cb = cbore (D, WASHER)

  ## Nominal diameter, d2, t1 of type K, d4 of type K2, t2; NaN where the
  ## table has none
  T = [1.6, 3.3, 1.8, NaN, NaN; 2, 4.3, 2.3, 6, NaN;
       2.5, 5, 2.9, 8, NaN; 3, 6, 3.4, 9, 4.3; 4, 8, 4.6, 10, 5.5;
       5, 10, 5.7, 13, 7; 6, 11, 6.8, 13, 8.5; 8, 15, 9, 20, 11;
       10, 18, 11, 24, 13.5; 12, 20, 13, 26, 16; 14, 24, 15, 30, 18.5;
       16, 26, 17.5, 33, 21; 18, 30, 19.5, 36, 23; 20, 33, 21.5, 40, 25.5;
       22, 36, 23.5, 43, 27.5; 24, 40, 25.5, 46, 30.5;
       27, 43, 28.5, 53, 33.5; 30, 48, 32, 61, 38; 33, 53, 35, 63, 41;
       36, 57, 38, 71, 44];
  cb = T(T(:,1) == D, [2, 3] + 2 * WASHER);
  if (any (isnan (cb)))
    cb = [];
  endif

endfunction

## The countersink [CD, ANGLE, CDEPTH] IS 3406 (Part 1):1986 gives the
## nominal diameter D: type A for the heads of ISO 7721, medium, d2, or with
## FINE fine, d3 and t2; or with SOCKET type B for ISO 10642, fine only, d3
## and t2; empty for a diameter or a series it does not give
function cs = csink (D, SOCKET, FINE)

  if (SOCKET)
    ## Nominal diameter, d3, t2 of type B
    T = [3, 6.3, 0.2; 4, 8.3, 0.3; 5, 10.4, 0.3; 6, 12.4, 0.3;
         8, 16.5, 0.4; 10, 20.5, 0.5; 12, 25, 0.5; 14, 28, 0.5;
         16, 31, 0.5; 18, 34, 0.5; 20, 37, 0.5; 22, 48.2, 1; 24, 52, 1];
    k = find (T(:,1) == D);
    cs = [];
    if (FINE && ! isempty (k))
      cs = [T(k,2), 90, T(k,3)];
    endif
  else
    ## Nominal diameter, d2 of the medium series, d3 and t2 of the fine
    T = [1, 2.4, 2, 0.2; 1.2, 2.8, 2.5, 0.15; 1.4, 3.3, 2.8, 0.15;
         1.6, 3.7, 3.3, 0.2; 1.8, 4.1, 3.8, 0.2; 2, 4.6, 4.3, 0.15;
         2.5, 5.7, 5, 0.35; 3, 6.5, 6, 0.25; 3.5, 7.6, 7, 0.3;
         4, 8.6, 8, 0.3; 4.5, 9.5, 9, 0.3; 5, 10.4, 10, 0.2;
         6, 12.4, 11.5, 0.45; 8, 16.4, 15, 0.7; 10, 20.4, 19, 0.7;
         12, 23.9, 23, 0.7; 14, 26.9, 26, 0.7; 16, 31.9, 30, 1.2;
         18, 36.4, 34, 1.2; 20, 40.4, 37, 1.7];
    k = find (T(:,1) == D);
    cs = [];
    if (! isempty (k) && FINE)
      cs = [T(k,3), 90, T(k,4)];
    elseif (! isempty (k))
      cs = [T(k,2), 90, 0];
    endif
  endif

endfunction

## The diameters of the twist drills in RUKO's catalogue, chapter 1.01
## Twist drills (2014): DIN 338 type N, HSS ground, article 214, pages 54
## to 56, and DIN 345 type N, HSS, article 204, pages 78 and 79
function D = drillsizes ()

  q = [1.25, 1.75, 2.25, 2.75, 3.25, 3.75, 4.25, 4.75, 5.25, 5.75, 6.25, ...
       6.75, 7.25, 7.75, 8.25, 8.75, 9.25, 9.75];
  D = unique ([(3:130) / 10, q, (27:40) / 2, (41:100) / 2, 51:60]);

endfunction

%!test
%! H = solid.holespec ('M6');
%! assert_equal (fieldnames (H), {'name'; 'clearance'; 'drill'; ...
%!                                'counterbore'; 'countersink'});
%! assert_equal (H.clearance, '');
%! assert_equal (H.drill, 5);
%! assert_equal ([H.counterbore, H.countersink], []);

%!test  # a tapped hole in a tough material, and at full engagement
%! H = solid.holespec ('M8', 'Material', 'stainless');
%! assert_equal (H.drill, 6.9, 1e-12);
%! H = solid.holespec ('M8', 'Engagement', 100);
%! assert_equal (H.drill, 6.7, 1e-12);

%!test  # a custom thread drills a step of 0.05 in its band
%! H = solid.holespec ('M16x0.8', 'Custom', true, 'Material', 'stainless');
%! assert_equal (H.drill, 15.3, 1e-12);

%!test  # the three series of ISO 273
%! H = solid.holespec ('M6', 'Clearance', 'fine');
%! assert_equal (H.drill, 6.4, 1e-12);
%! H = solid.holespec ('M6', 'Clearance', 'medium');
%! assert_equal (H.drill, 6.6, 1e-12);
%! H = solid.holespec ('M6', 'Clearance', 'Coarse');
%! assert_equal (H.drill, 7);
%! assert_equal (H.clearance, 'coarse');

%!test  # the largest diameter of ISO 273 in the range of ISO 261
%! H = solid.holespec ('M64', 'Clearance', 'coarse');
%! assert_equal (H.drill, 74);

%!test  # the counterbore of type K
%! H = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', true);
%! assert_equal (H.counterbore, [11, 6.8], 1e-12);

%!test  # the depth of type K at M5, as amendment 1 corrects it
%! H = solid.holespec ('M5', 'Clearance', 'fine', 'Counterbore', true);
%! assert_equal (H.counterbore, [10, 5.7], 1e-12);

%!test  # the counterbore of type K2, over a plain washer
%! H = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', 'washer');
%! assert_equal (H.counterbore, [13, 8.5], 1e-12);

%!test  # the largest counterbore of type K
%! H = solid.holespec ('M36', 'Clearance', 'medium', 'Counterbore', true);
%! assert_equal (H.counterbore, [57, 38]);

%!test  # a counterbore given by numbers, in any series
%! H = solid.holespec ('M6', 'Clearance', 'coarse', 'Counterbore', [12, 8]);
%! assert_equal (H.counterbore, [12, 8]);

%!test  # false is no counterbore
%! H = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', false);
%! assert_equal (H.counterbore, []);

%!test  # the countersink of type A, medium: a plain cone
%! H = solid.holespec ('M6', 'Clearance', 'medium', 'Countersink', true);
%! assert_equal (H.countersink, [12.4, 90, 0], 1e-12);

%!test  # the countersink of type A, fine: a cone below a cylinder
%! H = solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', true);
%! assert_equal (H.countersink, [11.5, 90, 0.45], 1e-12);

%!test  # the countersink of type B, for a hexagon socket screw
%! H = solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', 'socket');
%! assert_equal (H.countersink, [12.4, 90, 0.3], 1e-12);

%!test  # the largest countersink of type B
%! H = solid.holespec ('M24', 'Clearance', 'fine', 'Countersink', 'socket');
%! assert_equal (H.countersink, [52, 90, 1]);

%!test  # a countersink given by numbers, completed to three
%! H = solid.holespec ('M6', 'Clearance', 'coarse', 'Countersink', 13);
%! assert_equal (H.countersink, [13, 90, 0]);
%! H = solid.holespec ('M6', 'Clearance', 'coarse', 'Countersink', [13, 82]);
%! assert_equal (H.countersink, [13, 82, 0]);

## Test input validation
%!error<solid.holespec: invalid number of input arguments.> ...
%! solid.holespec ()
%!error<solid.holespec: invalid number of input arguments.> ...
%! solid.holespec ('M6', 'Clearance')
%!error<solid.holespec: option names must be character vectors.> ...
%! solid.holespec ('M6', 1, 2)
%!error<solid.holespec: unknown option 'Depth'.> ...
%! solid.holespec ('M6', 'Depth', 2)
%!error<solid.holespec: 'Clearance' must be 'fine', 'medium' or 'coarse'.> ...
%! solid.holespec ('M6', 'Clearance', 'loose')
%!error<solid.holespec: 'Counterbore' must be true, false, 'washer' or \[CD, CDEPTH\].> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Counterbore', 'yes')
%!error<solid.holespec: 'Counterbore' must be true, false, 'washer' or \[CD, CDEPTH\].> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Counterbore', [11, 6, 1])
%!error<solid.holespec: 'Countersink' must be true, false, 'socket', CD, \[CD, ANGLE\] or \[CD, ANGLE, CDEPTH\].> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', 'cone')
%!error<solid.holespec: 'Countersink' must be true, false, 'socket', CD, \[CD, ANGLE\] or \[CD, ANGLE, CDEPTH\].> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', [12, 180])
%!error<solid.holespec: 'Material' must be a character vector.> ...
%! solid.holespec ('M6', 'Material', 1)
%!error<solid.holespec: 'Engagement' must be a real and finite scalar.> ...
%! solid.holespec ('M6', 'Engagement', Inf)
%!error<solid.holespec: 'Counterbore' and 'Countersink' cannot both be given.> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Counterbore', true, ...
%!                 'Countersink', true)
%!error<solid.holespec: 'Counterbore' and 'Countersink' apply only to a clearance hole.> ...
%! solid.holespec ('M6', 'Counterbore', true)
%!error<solid.holespec: 'Material' and 'Engagement' apply only to a tapped hole.> ...
%! solid.holespec ('M6', 'Clearance', 'fine', 'Material', 'steel')
%!error<solid.holespec: 'Material' and 'Engagement' cannot both be given.> ...
%! solid.holespec ('M6', 'Material', 'steel', 'Engagement', 90)
%!error<solid.holespec: unknown material 'wood'.> ...
%! solid.holespec ('M6', 'Material', 'wood')
%!error<solid.holespec: M6: engagement must lie between 78.2 and 100 %.> ...
%! solid.holespec ('M6', 'Engagement', 75)
%!error<solid.holespec: M1.97x0.2: no drill of a 0.05 step lies in the 6H band of its minor diameter.> ...
%! solid.holespec ('M1.97x0.2', 'Custom', true)
%!error<solid.holespec: ISO 273 gives no clearance hole for M5.5x0.5.> ...
%! solid.holespec ('M5.5x0.5', 'Clearance', 'medium')
%!error<solid.holespec: IS 3406 gives no counterbore for a coarse clearance hole for M6.> ...
%! solid.holespec ('M6', 'Clearance', 'coarse', 'Counterbore', true)
%!error<solid.holespec: IS 3406 gives no counterbore for a medium clearance hole for M2.> ...
%! solid.holespec ('M2', 'Clearance', 'medium', 'Counterbore', 'washer')
%!error<solid.holespec: IS 3406 gives no countersink for a medium clearance hole for M6.> ...
%! solid.holespec ('M6', 'Clearance', 'medium', 'Countersink', 'socket')
%!error<solid.holespec: IS 3406 gives no countersink for a medium clearance hole for M24.> ...
%! solid.holespec ('M24', 'Clearance', 'medium', 'Countersink', true)
