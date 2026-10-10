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
## @deftypefn  {drafting} {@var{T} =} solid.threadspec (@var{NAME})
## @deftypefnx {drafting} {@var{T} =} solid.threadspec (@var{NAME}, 'Custom', @var{TF})
##
## The dimensions of a metric screw thread, read from its name.
##
## @code{@var{T} = solid.threadspec (@var{NAME})} reads @var{NAME} as a
## drawing names a thread, @qcode{'M6'} for a coarse thread by its nominal
## diameter and @qcode{'M10x1.25'} for a fine one with its pitch, and
## returns the numbers @code{solid.Shape.hole} and @code{solid.Shape.thread}
## cut it by, as a struct with the fields:
##
## @multitable @columnfractions 0.12 0.88
## @item @code{name} @tab @var{NAME} as given.
## @item @code{d} @tab The nominal diameter in millimetres.
## @item @code{P} @tab The pitch in millimetres.
## @item @code{coarse} @tab True for the coarse pitch of ISO 261, false for
## a fine or a custom one.
## @item @code{custom} @tab True for a thread outside ISO 261, taken with
## @qcode{'Custom'}.
## @item @code{minor} @tab The 6H band of the minor diameter of the
## internal thread, @code{[@var{min}, @var{max}]}, from ISO 965-1.
## @item @code{drill} @tab The tapping drill @code{solid.Shape.hole} takes
## without @qcode{'Material'} or @qcode{'Engagement'}: the one ISO 2306
## lists, or the nominal diameter less the pitch for a thread it does not
## list.  For a custom thread, the step of 0.05 inside the band nearest the
## nominal diameter less the pitch, empty when the band holds none.
## @item @code{major} @tab The largest major diameter of the external
## thread in class 6g, from ISO 965-1, which @code{solid.Shape.thread} turns
## a rod at the nominal diameter down to.
## @end multitable
##
## The names are those of ISO 261, table 2, from M1 to M64, all three of
## its columns.  A diameter with no coarse pitch is named with its pitch, as
## @qcode{'M15x1.5'}.
##
## @code{@var{T} = solid.threadspec (@var{NAME}, 'Custom', @var{TF})} with
## @var{TF} true takes a thread of any diameter and pitch, named with its
## pitch, as @qcode{'M16x0.8'} cut on a lathe or @qcode{'M6.35x1.27'} for
## 1/4-20 UNC; its pitch and minor diameter must be positive.  Without it a
## name outside ISO 261 is refused, so that a mistyped name is caught.
##
## Where each number comes from, and how it is computed, is set out on the
## Standards page of the guide.
##
## @example
## @group
## ## The tapping drill and the 6H band of M8
## T = solid.threadspec ('M8');
## T.drill
## @result{} 6.8000
## T.minor
## @result{} 6.6468   6.9118
## @end group
## @end example
##
## @seealso{solid.Shape.hole, solid.Shape.thread}
## @end deftypefn

function T = threadspec (NAME, varargin)

  ## Input validation
  if (nargin != 1 && nargin != 3)
    error ("solid.threadspec: invalid number of input arguments.");
  endif
  cflag = false;
  if (nargin > 1)
    if (strcmpi (varargin{1}, 'custom'))
      cflag = varargin{2};
      if (! (islogical (cflag) && isscalar (cflag)))
        error ("solid.threadspec: 'Custom' must be either true or false.");
      endif
    else
      error ("solid.threadspec: second input argument must be 'Custom'.");
    endif
  endif
  if (! ischar (NAME))
    error (strcat ("solid.threadspec: NAME must be the name of an ISO", ...
                   " metric thread such as 'M6' or 'M10x1.25'."));
  endif

  ## The thread NAME as a struct of its name, its nominal diameter d, its
  ## pitch P, whether the pitch is the coarse one of ISO 261 and whether the
  ## thread is a custom one
  tok = {};
  if (isrow (NAME))
    tok = regexp (NAME, '^M(\d+(?:\.\d+)?)(?:x(\d+(?:\.\d+)?))?$', ...
                  'tokens', 'once');
  endif
  if (isempty (tok))
    error (strcat ("solid.threadspec: '%s' is not the name of an ISO", ...
                   " metric thread."), NAME);
  endif
  if (numel (tok) < 2)
    tok{2} = '';
  endif
  d = str2double (tok{1});
  p = str2double (tok{2});
  [coarse, fine] = isothreads (d);
  iso = ! isempty (coarse);
  if (iso && isempty (tok{2}) && ! isnan (coarse))
    T = struct ('name', NAME, 'd', d, 'P', coarse, 'coarse', true, ...
                'custom', false);
  elseif (iso && (p == coarse || any (fine == p)))
    T = struct ('name', NAME, 'd', d, 'P', p, 'coarse', p == coarse, ...
                'custom', false);
  elseif (isempty (tok{2}) && (iso || cflag))
    error (strcat ("solid.threadspec: '%s' has no coarse pitch,", ...
                   " so its name must give the pitch."), NAME);
  elseif (! cflag)
    error ("solid.threadspec: '%s' is not an ISO 261 thread.", NAME);
  elseif (! (p > 0) || ! (d - 1.25 * sqrt (3) / 2 * p > 0))
    error (strcat ("solid.threadspec: '%s' needs a positive", ...
                   " pitch and a positive minor diameter."), NAME);
  else
    T = struct ('name', NAME, 'd', d, 'P', p, 'coarse', false, 'custom', true);
  endif

  ## The 6H band of the minor diameter, ISO 965-1
  [lo, hi] = minorband (T);
  T.minor = [lo, hi];

  ## The tapping drill, ISO 2306 or a step of 0.05 for a custom thread
  if (T.custom)
    ## The steps of 0.05 in the band, the one nearest the nominal diameter
    ## less the pitch, rounded to 0.05, the drill; none when the band holds
    ## no step
    C = (ceil (20 * lo - 1e-6):floor (20 * hi + 1e-6)) / 20;
    [~, k] = min (abs (C - round (20 * (T.d - T.P)) / 20));
    T.drill = C(k);
  else
    T.drill = iso2306 (T);
  endif

  ## The largest major diameter of class 6g, ISO 965-1
  T.major = T.d + gdeviation (T.P) / 1000;

endfunction

## The pitches ISO 261:1998, table 2, gives the nominal diameter D, from M1
## to M64: its coarse pitch, NaN where it has none, and its fine pitches;
## both empty for a diameter the table does not list
function [coarse, fine] = isothreads (D)

  T = {1, 0.25, 0.2; 1.1, 0.25, 0.2; 1.2, 0.25, 0.2; 1.4, 0.3, 0.2;
       1.6, 0.35, 0.2; 1.8, 0.35, 0.2; 2, 0.4, 0.25; 2.2, 0.45, 0.25;
       2.5, 0.45, 0.35; 3, 0.5, 0.35; 3.5, 0.6, 0.35; 4, 0.7, 0.5;
       4.5, 0.75, 0.5; 5, 0.8, 0.5; 5.5, NaN, 0.5; 6, 1, 0.75; 7, 1, 0.75;
       8, 1.25, [1, 0.75]; 9, 1.25, [1, 0.75]; 10, 1.5, [1.25, 1, 0.75];
       11, 1.5, [1, 0.75]; 12, 1.75, [1.5, 1.25, 1];
       14, 2, [1.5, 1.25, 1]; 15, NaN, [1.5, 1]; 16, 2, [1.5, 1];
       17, NaN, [1.5, 1]; 18, 2.5, [2, 1.5, 1]; 20, 2.5, [2, 1.5, 1];
       22, 2.5, [2, 1.5, 1]; 24, 3, [2, 1.5, 1]; 25, NaN, [2, 1.5, 1];
       26, NaN, 1.5; 27, 3, [2, 1.5, 1]; 28, NaN, [2, 1.5, 1];
       30, 3.5, [3, 2, 1.5, 1]; 32, NaN, [2, 1.5]; 33, 3.5, [3, 2, 1.5];
       35, NaN, 1.5; 36, 4, [3, 2, 1.5]; 38, NaN, 1.5; 39, 4, [3, 2, 1.5];
       40, NaN, [3, 2, 1.5]; 42, 4.5, [4, 3, 2, 1.5];
       45, 4.5, [4, 3, 2, 1.5]; 48, 5, [4, 3, 2, 1.5];
       50, NaN, [3, 2, 1.5]; 52, 5, [4, 3, 2, 1.5];
       55, NaN, [4, 3, 2, 1.5]; 56, 5.5, [4, 3, 2, 1.5];
       58, NaN, [4, 3, 2, 1.5]; 60, 5.5, [4, 3, 2, 1.5];
       62, NaN, [4, 3, 2, 1.5]; 64, 6, [4, 3, 2, 1.5]};
  k = find ([T{:,1}] == D);
  coarse = [];
  fine = [];
  if (! isempty (k))
    coarse = T{k,2};
    fine = T{k,3};
  endif

endfunction

## The drill ISO 2306:1972 gives for the thread T in its table 1, coarse, and
## table 2, fine; for a thread it does not list, the rule it states, the
## nominal diameter less the pitch
function D = iso2306 (T)

  D = T.d - T.P;
  if (T.coarse)
    C = [1, 0.75; 1.1, 0.85; 1.2, 0.95; 1.4, 1.1; 1.6, 1.25; 1.8, 1.45;
         2, 1.6; 2.2, 1.75; 2.5, 2.05; 3, 2.5; 3.5, 2.9; 4, 3.3; 4.5, 3.7;
         5, 4.2; 6, 5; 7, 6; 8, 6.8; 9, 7.8; 10, 8.5; 11, 9.5; 12, 10.2;
         14, 12; 16, 14; 18, 15.5; 20, 17.5; 22, 19.5; 24, 21; 27, 24;
         30, 26.5; 33, 29.5; 36, 32; 39, 35; 42, 37.5; 45, 40.5; 48, 43;
         52, 47; 56, 50.5];
    k = find (C(:,1) == T.d);
    if (! isempty (k))
      D = C(k,2);
    endif
  else
    ## Each fine pitch with the nominal diameters listed for it, and the
    ## amount every one of their drills is less than the nominal diameter
    F = {0.35, [2.5, 3, 3.5], 0.35;
         0.5, [4, 4.5, 5, 5.5], 0.5;
         0.75, [6, 7, 8, 9, 10, 11], 0.8;
         1, [8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 20, 22, 24, 25, 27, ...
             28, 30], 1;
         1.25, [10, 12, 14], 1.2;
         1.5, [12, 14, 15, 16, 17, 18, 20, 22, 24, 25, 26, 27, 28, 30, ...
               32, 33, 35, 36, 38, 39, 40, 42, 45, 48, 50, 52], 1.5;
         2, [18, 20, 22, 24, 25, 27, 28, 30, 32, 33, 36, 39, 40, 42, 45, ...
             48, 50, 52], 2;
         3, [30, 33, 36, 39, 40, 42, 45, 48, 50, 52], 3;
         4, [42, 45, 48, 52], 4};
    k = find ([F{:,1}] == T.P);
    if (! isempty (k) && any (F{k,2} == T.d))
      D = T.d - F{k,3};
    endif
  endif

endfunction

## The 6H band of the minor diameter of the thread T, from D1 to D1 plus
## the tolerance TD1, in millimetres
function [lo, hi] = minorband (T)

  lo = T.d - 1.25 * sqrt (3) / 2 * T.P;
  hi = lo + minortol (T.P) / 1000;

endfunction

## The tolerance TD1 of the minor diameter of an internal thread of pitch P,
## in micrometres, grade 6 or, at the pitches 0.25 and 0.2 where ISO
## 965-1:1998 has no grade 6, grades 5 and 4: the formulae of 13.3.2 rounded
## as table 3 is, with the values of table 3 the rounding does not reach
function T = minortol (P)

  if (P < 1)
    T6 = 433 * P - 190 * P ^ 1.22;
  else
    T6 = 230 * P ^ 0.7;
  endif
  if (P == 0.2)
    T = r40 (0.63 * T6);
  elseif (P == 0.25)
    T = 56;
  else
    X = [0.5, 140; 1, 236; 2.5, 450];
    k = find (X(:,1) == P);
    if (isempty (k))
      T = r40 (T6);
    else
      T = X(k,2);
    endif
  endif

endfunction

## The fundamental deviation es of position g for an external thread of
## pitch P, in micrometres: -(15 + 11 P) of ISO 965-1:1998, 13.1, rounded as
## table 1 is, with its one value the rounding does not reach
function es = gdeviation (P)

  if (P == 0.75)
    es = -22;
  else
    es = -r40 (15 + 11 * P);
  endif

endfunction

## X rounded as ISO 965-1 rounds its tables: to the nearest value of the
## R 40 series of preferred numbers (ISO 3), then to a whole number.  A half
## goes to the even number, which is how the tables round it.
function v = r40 (X)

  R = [100, 106, 112, 118, 125, 132, 140, 150, 160, 170, 180, 190, 200, ...
       212, 224, 236, 250, 265, 280, 300, 315, 335, 355, 375, 400, 425, ...
       450, 475, 500, 530, 560, 600, 630, 670, 710, 750, 800, 850, 900, 950];
  S = [R / 100, R / 10, R, R * 10];
  [~, k] = min (abs (S - X));
  v = S(k);
  if (mod (v, 1) == 0.5)
    v = 2 * round (v / 2);
  else
    v = round (v);
  endif

endfunction

%!test
%! T = solid.threadspec ('M6');
%! assert_equal (fieldnames (T), {'name'; 'd'; 'P'; 'coarse'; 'custom'; ...
%!                                'minor'; 'drill'; 'major'});
%! assert_equal ([T.d, T.P, T.coarse, T.custom], [6, 1, 1, 0]);
%! assert_equal (T.minor, [4.917468, 5.153468], 1e-6);
%! assert_equal (T.drill, 5);
%! assert_equal (T.major, 5.974, 1e-12);

%!test  # a fine thread
%! T = solid.threadspec ('M10x1.25');
%! assert_equal ([T.d, T.P, T.coarse], [10, 1.25, 0]);
%! assert_equal (T.drill, 8.8, 1e-12);
%! assert_equal (T.major, 9.972, 1e-12);

%!test  # a thread ISO 2306 does not list: the nominal diameter less the pitch
%! T = solid.threadspec ('M64');
%! assert_equal (T.drill, 58);

%!test  # pitch 0.25, where ISO 965-1 has no grade 6: grade 5
%! T = solid.threadspec ('M1');
%! assert_equal (T.minor, [0.729367, 0.785367], 1e-6);

%!test  # a diameter with no coarse pitch, named with its pitch
%! T = solid.threadspec ('M15x1.5');
%! assert_equal ([T.coarse, T.drill], [0, 13.5]);

%!test  # a custom thread
%! T = solid.threadspec ('M16x0.8', 'Custom', true);
%! assert_equal ([T.custom, T.drill], [1, 15.2]);
%! assert_equal (T.minor, [15.133975, 15.333975], 1e-6);

%!test  # 1/4-20 UNC as a custom thread
%! T = solid.threadspec ('M6.35x1.27', 'Custom', true);
%! assert_equal (T.drill, 5.1, 1e-12);
%! assert_equal (T.major, 6.322, 1e-12);

%!test  # a band too narrow to hold a step of 0.05
%! T = solid.threadspec ('M1.97x0.2', 'Custom', true);
%! assert_equal (isempty (T.drill), true);

%!test  # an ISO thread stays one with Custom
%! T = solid.threadspec ('M6', 'Custom', true);
%! assert_equal ([T.custom, T.drill], [0, 5]);

## Test input validation
%!error<solid.threadspec: invalid number of input arguments.> ...
%! solid.threadspec ()
%!error<solid.threadspec: NAME must be the name of an ISO metric thread such as 'M6' or 'M10x1.25'.> ...
%! solid.threadspec (6)
%!error<solid.threadspec: invalid number of input arguments.> ...
%! solid.threadspec ('M6', 'Custom')
%!error<solid.threadspec: second input argument must be 'Custom'.> ...
%! solid.threadspec ('M6', 1, true)
%!error<solid.threadspec: second input argument must be 'Custom'.> ...
%! solid.threadspec ('M6', 'Pitch', 1)
%!error<solid.threadspec: 'Custom' must be either true or false.> ...
%! solid.threadspec ('M6', 'Custom', 2)
%!error<solid.threadspec: 'Custom' must be either true or false.> ...
%! solid.threadspec ('M6', 'Custom', 1)
%!error<solid.threadspec: 'm6' is not the name of an ISO metric thread.> ...
%! solid.threadspec ('m6')
%!error<solid.threadspec: 'M6x' is not the name of an ISO metric thread.> ...
%! solid.threadspec ('M6x')
%!error<solid.threadspec: 'M7.5' is not an ISO 261 thread.> ...
%! solid.threadspec ('M7.5')
%!error<solid.threadspec: 'M10x2' is not an ISO 261 thread.> ...
%! solid.threadspec ('M10x2')
%!error<solid.threadspec: 'M16x0.8' is not an ISO 261 thread.> ...
%! solid.threadspec ('M16x0.8')
%!error<solid.threadspec: 'M15' has no coarse pitch, so its name must give the pitch.> ...
%! solid.threadspec ('M15')
%!error<solid.threadspec: 'M13' has no coarse pitch, so its name must give the pitch.> ...
%! solid.threadspec ('M13', 'Custom', true)
%!error<solid.threadspec: 'M2x2' needs a positive pitch and a positive minor diameter.> ...
%! solid.threadspec ('M2x2', 'Custom', true)
%!error<solid.threadspec: 'M2x0' needs a positive pitch and a positive minor diameter.> ...
%! solid.threadspec ('M2x0', 'Custom', true)
