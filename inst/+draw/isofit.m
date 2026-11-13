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
## @deftypefn {drafting} {@var{DEV} =} draw.isofit (@var{SIZE}, @var{CLASS})
##
## Limit deviations of an ISO 286 tolerance class.
##
## @code{@var{DEV} = draw.isofit (@var{SIZE}, @var{CLASS})} returns the lower
## and upper limit deviations, in millimetres, of the tolerance class
## @var{CLASS} at the basic size @var{SIZE}, as the row
## @code{[@var{LOWER}, @var{UPPER}]}.  @code{@var{SIZE} + @var{DEV}} is then
## the smallest and the largest size the feature may have.
##
## @var{CLASS} is a fundamental deviation followed by a standard tolerance
## grade, as written on a drawing: capital letters for a hole, small letters
## for a shaft, such as @qcode{'H7'}, @qcode{'g6'}, @qcode{'JS9'} or
## @qcode{'zc11'}.  The letters are @code{A} to @code{ZC} (without @code{I},
## @code{L}, @code{O}, @code{Q} and @code{W}, and with @code{CD}, @code{EF},
## @code{FG}, @code{JS}, @code{ZA} and @code{ZB}), and the grades
## @code{01}, @code{0} and @code{1} to @code{18}.  @var{SIZE} is in
## millimetres, above 0 and at most 3150.  A size on the boundary of two size
## steps belongs to the lower one, as the standard counts them ("above 18 up
## to and including 30").
##
## The values are those of ISO 286-1: the standard tolerances of its table 1
## and annex A, and the fundamental deviations of its tables 2 and 3, with the
## delta values for @code{K}, @code{M} and @code{N} up to grade 8 and for
## @code{P} to @code{ZC} up to grade 7, and the special case of
## @code{M6} from 250 to 315 mm.  ISO 286-2 tabulates a selection of these
## classes; every class ISO 286-1 defines is returned.  @code{JS} and
## @code{js} are exactly half the tolerance either side of the basic size, so
## an odd tolerance in micrometres gives a deviation ending in 0.5.
##
## A class the standard does not define at @var{SIZE} is an error: a
## fundamental deviation outside the sizes its table covers, @code{J} and
## @code{j} beyond the grades their tables give, @code{K} above grade 8 for
## sizes above 3 mm, the grades @code{01} and @code{0} above 500 mm, and a
## class needing a delta value below grade 3, for which the standard gives
## none.  Sizes of 1 mm and less refuse @code{A}, @code{B}, @code{a},
## @code{b}, the grades 14 to 18, and @code{N} above grade 8, as the standard
## asks.  The grades 1 to 5 above 500 mm are given, which ISO 286-1 includes
## for experimental use.
##
## @example
## @group
## draw.isofit (25, 'H7')
## @result{} [0, 0.021]
## draw.isofit (25, 'g6')
## @result{} [-0.020, -0.007]
## @end group
## @end example
##
## @seealso{draw.Drawing.dim, draw.Drawing.diam}
## @end deftypefn

function DEV = isofit (SIZE, CLASS)

  if (nargin != 2)
    error ("draw.isofit: invalid number of input arguments.");
  endif
  if (! (isfloat (SIZE) && isreal (SIZE) && isscalar (SIZE) && SIZE > 0
         && SIZE <= 3150))
    error (strcat ("draw.isofit: SIZE must be a real scalar above 0 and", ...
                   " at most 3150."));
  endif
  if (! (ischar (CLASS) && isrow (CLASS)))
    error ("draw.isofit: CLASS must be a character vector.");
  endif
  tok = regexp (CLASS, '^([A-Za-z]{1,2})(01|0|1[0-8]|[1-9])$', 'tokens', ...
                'once');
  letters = {'a', 'b', 'c', 'cd', 'd', 'e', 'ef', 'f', 'fg', 'g', 'h', ...
             'js', 'j', 'k', 'm', 'n', 'p', 'r', 's', 't', 'u', 'v', 'x', ...
             'y', 'z', 'za', 'zb', 'zc'};
  if (isempty (tok) || ! any (strcmp (lower (tok{1}), letters))
      || ! (strcmp (tok{1}, lower (tok{1}))
            || strcmp (tok{1}, upper (tok{1}))))
    error ("draw.isofit: '%s' is not an ISO 286 tolerance class.", CLASS);
  endif
  L = lower (tok{1});
  hole = ! strcmp (tok{1}, L);
  if (strcmp (tok{2}, '01'))
    g = -1;
  else
    g = str2double (tok{2});
  endif
  undefined = sprintf (strcat ("draw.isofit: ISO 286 defines no %s for a", ...
                               " size of %g mm."), CLASS, SIZE);

  ## The size steps of the standard tolerances, and the finer ones of the
  ## fundamental deviations
  main = [3, 6, 10, 18, 30, 50, 80, 120, 180, 250, 315, 400, 500, 630, ...
          800, 1000, 1250, 1600, 2000, 2500, 3150];
  fine = [3, 6, 10, 14, 18, 24, 30, 40, 50, 65, 80, 100, 120, 140, 160, ...
          180, 200, 225, 250, 280, 315, 355, 400, 450, 500, 560, 630, 710, ...
          800, 900, 1000, 1120, 1250, 1400, 1600, 1800, 2000, 2240, 2500, ...
          2800, 3150];
  mi = find (SIZE <= main, 1);
  fi = find (SIZE <= fine, 1);
  T = ittable ();
  it = T(g + 2, mi);
  if (isnan (it)
      || (SIZE <= 1 && (g >= 14 || any (strcmp (L, {'a', 'b'}))
                        || (hole && strcmp (L, 'n') && g > 8))))
    error (undefined);
  endif
  S = deviationtable ();

  switch (L)
    case 'js'
      dev = [-it, it] / 2;
    case 'j'
      if (hole)
        name = sprintf ('J%d', g);
      elseif (any (g == [5, 6]))
        name = 'j5';
      else
        name = sprintf ('j%d', g);
      endif
      if (! isfield (S, name) || isnan (S.(name)(fi)))
        error (undefined);
      endif
      if (hole)
        dev = S.(name)(fi) - [it, 0];
      else
        dev = S.(name)(fi) + [0, it];
      endif
    case {'a', 'b', 'c', 'cd', 'd', 'e', 'ef', 'f', 'fg', 'g', 'h'}
      ## The upper deviation of the shaft, the lower of the hole
      es = S.(L)(fi);
      if (isnan (es))
        error (undefined);
      endif
      if (hole)
        dev = -es + [0, it];
      else
        dev = es - [it, 0];
      endif
    otherwise
      ## The lower deviation of the shaft; k differs between grades
      if (strcmp (L, 'k'))
        ei = S.k(fi) * (g >= 4 && g <= 7);
      else
        ei = S.(L)(fi);
      endif
      if (isnan (ei))
        error (undefined);
      endif
      if (! hole)
        dev = ei + [0, it];
      else
        ## The upper deviation of the hole mirrors the shaft's lower one,
        ## raised by delta in the finer grades, where ISO 286-1 tabulates it
        ## for grades 3 to 8 up to 500 mm
        withdelta = (any (strcmp (L, {'k', 'm', 'n'})) && g <= 8) || g <= 7;
        if (strcmp (L, 'k'))
          ES = -S.k(fi);
          if (! withdelta && SIZE > 3)
            error (undefined);
          endif
        elseif (strcmp (L, 'n') && ! withdelta && SIZE > 3 && SIZE <= 500)
          ES = 0;
        else
          ES = -ei;
        endif
        if (withdelta && SIZE <= 500)
          if (g < 3)
            error (undefined);
          endif
          ES += T(g + 2, mi) - T(g + 1, mi);
        endif
        if (strcmp (L, 'm') && g == 6 && SIZE > 250 && SIZE <= 315)
          ES = -9;
        endif
        dev = ES - [it, 0];
      endif
  endswitch
  ## Adding zero turns the -0 of a negated zero deviation into 0
  DEV = dev / 1000 + 0;

endfunction

## Standard tolerances in micrometres, ISO 286-1 table 1 and annex A table 5:
## a row for each grade from IT01 to IT18, a column for each main size step
function T = ittable ()

  T = [0.3, 0.4, 0.4, 0.5, 0.6, 0.6, 0.8, 1, 1.2, 2, 2.5, 3, 4, ...
       NaN(1, 8);
       0.5, 0.6, 0.6, 0.8, 1, 1, 1.2, 1.5, 2, 3, 4, 5, 6, NaN(1, 8);
       0.8, 1, 1, 1.2, 1.5, 1.5, 2, 2.5, 3.5, 4.5, 6, 7, 8, 9, 10, 11, ...
       13, 15, 18, 22, 26;
       1.2, 1.5, 1.5, 2, 2.5, 2.5, 3, 4, 5, 7, 8, 9, 10, 11, 13, 15, 18, ...
       21, 25, 30, 36;
       2, 2.5, 2.5, 3, 4, 4, 5, 6, 8, 10, 12, 13, 15, 16, 18, 21, 24, 29, ...
       35, 41, 50;
       3, 4, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 22, 25, 28, 33, 39, ...
       46, 55, 68;
       4, 5, 6, 8, 9, 11, 13, 15, 18, 20, 23, 25, 27, 32, 36, 40, 47, 55, ...
       65, 78, 96;
       6, 8, 9, 11, 13, 16, 19, 22, 25, 29, 32, 36, 40, 44, 50, 56, 66, ...
       78, 92, 110, 135;
       10, 12, 15, 18, 21, 25, 30, 35, 40, 46, 52, 57, 63, 70, 80, 90, ...
       105, 125, 150, 175, 210;
       14, 18, 22, 27, 33, 39, 46, 54, 63, 72, 81, 89, 97, 110, 125, 140, ...
       165, 195, 230, 280, 330;
       25, 30, 36, 43, 52, 62, 74, 87, 100, 115, 130, 140, 155, 175, 200, ...
       230, 260, 310, 370, 440, 540;
       40, 48, 58, 70, 84, 100, 120, 140, 160, 185, 210, 230, 250, 280, ...
       320, 360, 420, 500, 600, 700, 860;
       60, 75, 90, 110, 130, 160, 190, 220, 250, 290, 320, 360, 400, 440, ...
       500, 560, 660, 780, 920, 1100, 1350];
  ## From IT12 on, each grade is ten times the grade five below it, which is
  ## how table 1 itself is built
  T = [T; 10 * T(end-4:end,:)];
  T = [T; 10 * T(end-4:end,:)];
  T = T(1:20,:);

endfunction

## Fundamental deviations in micrometres, ISO 286-1 tables 2 and 3, one value
## for each fine size step, NaN where the table gives none: the upper
## deviation es of the shafts a to h, the lower deviation ei of k (for grades
## 4 to 7) and m to zc, ei of j5 and j6, j7 and j8, and the upper deviation
## ES of the holes J6, J7 and J8
function S = deviationtable ()

  n16 = NaN (1, 16);
  n38 = NaN (1, 38);
  S.a = [-270, -270, -280, -290, -290, -300, -300, -310, -320, -340, ...
         -360, -380, -410, -460, -520, -580, -660, -740, -820, -920, ...
         -1050, -1200, -1350, -1500, -1650, n16];
  S.b = [-140, -140, -150, -150, -150, -160, -160, -170, -180, -190, ...
         -200, -220, -240, -260, -280, -310, -340, -380, -420, -480, ...
         -540, -600, -680, -760, -840, n16];
  S.c = [-60, -70, -80, -95, -95, -110, -110, -120, -130, -140, -150, ...
         -170, -180, -200, -210, -230, -240, -260, -280, -300, -330, ...
         -360, -400, -440, -480, n16];
  S.cd = [-34, -46, -56, n38];
  S.d = [-20, -30, -40, -50, -50, -65, -65, -80, -80, -100, -100, -120, ...
         -120, -145, -145, -145, -170, -170, -170, -190, -190, -210, ...
         -210, -230, -230, -260, -260, -290, -290, -320, -320, -350, ...
         -350, -390, -390, -430, -430, -480, -480, -520, -520];
  S.e = [-14, -20, -25, -32, -32, -40, -40, -50, -50, -60, -60, -72, ...
         -72, -85, -85, -85, -100, -100, -100, -110, -110, -125, -125, ...
         -135, -135, -145, -145, -160, -160, -170, -170, -195, -195, ...
         -220, -220, -240, -240, -260, -260, -290, -290];
  S.ef = [-10, -14, -18, n38];
  S.f = [-6, -10, -13, -16, -16, -20, -20, -25, -25, -30, -30, -36, ...
         -36, -43, -43, -43, -50, -50, -50, -56, -56, -62, -62, -68, -68, ...
         -76, -76, -80, -80, -86, -86, -98, -98, -110, -110, -120, -120, ...
         -130, -130, -145, -145];
  S.fg = [-4, -6, -8, n38];
  S.g = [-2, -4, -5, -6, -6, -7, -7, -9, -9, -10, -10, -12, -12, -14, ...
         -14, -14, -15, -15, -15, -17, -17, -18, -18, -20, -20, -22, -22, ...
         -24, -24, -26, -26, -28, -28, -30, -30, -32, -32, -34, -34, ...
         -38, -38];
  S.h = zeros (1, 41);
  S.k = [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, ...
         4, 4, 5, 5, zeros(1, 16)];
  S.m = [2, 4, 6, 7, 7, 8, 8, 9, 9, 11, 11, 13, 13, 15, 15, 15, 17, 17, ...
         17, 20, 20, 21, 21, 23, 23, 26, 26, 30, 30, 34, 34, 40, 40, 48, ...
         48, 58, 58, 68, 68, 76, 76];
  S.n = [4, 8, 10, 12, 12, 15, 15, 17, 17, 20, 20, 23, 23, 27, 27, 27, ...
         31, 31, 31, 34, 34, 37, 37, 40, 40, 44, 44, 50, 50, 56, 56, 66, ...
         66, 78, 78, 92, 92, 110, 110, 135, 135];
  S.p = [6, 12, 15, 18, 18, 22, 22, 26, 26, 32, 32, 37, 37, 43, 43, 43, ...
         50, 50, 50, 56, 56, 62, 62, 68, 68, 78, 78, 88, 88, 100, 100, ...
         120, 120, 140, 140, 170, 170, 195, 195, 240, 240];
  S.r = [10, 15, 19, 23, 23, 28, 28, 34, 34, 41, 43, 51, 54, 63, 65, 68, ...
         77, 80, 84, 94, 98, 108, 114, 126, 132, 150, 155, 175, 185, 210, ...
         220, 250, 260, 300, 330, 370, 400, 440, 460, 550, 580];
  S.s = [14, 19, 23, 28, 28, 35, 35, 43, 43, 53, 59, 71, 79, 92, 100, ...
         108, 122, 130, 140, 158, 170, 190, 208, 232, 252, 280, 310, 340, ...
         380, 430, 470, 520, 580, 640, 720, 820, 920, 1000, 1100, 1250, ...
         1400];
  S.t = [NaN(1, 6), 41, 48, 54, 66, 75, 91, 104, 122, 134, 146, 166, ...
         180, 196, 218, 240, 268, 294, 330, 360, 400, 450, 500, 560, 620, ...
         680, 780, 840, 960, 1050, 1200, 1350, 1500, 1650, 1900, 2100];
  S.u = [18, 23, 28, 33, 33, 41, 48, 60, 70, 87, 102, 124, 144, 170, 190, ...
         210, 236, 258, 284, 315, 350, 390, 435, 490, 540, 600, 660, 740, ...
         840, 940, 1050, 1150, 1300, 1450, 1600, 1850, 2000, 2300, 2500, ...
         2900, 3200];
  S.v = [NaN(1, 4), 39, 47, 55, 68, 81, 102, 120, 146, 172, 202, 228, ...
         252, 284, 310, 340, 385, 425, 475, 530, 595, 660, n16];
  S.x = [20, 28, 34, 40, 45, 54, 64, 80, 97, 122, 146, 178, 210, 248, ...
         280, 310, 350, 385, 425, 475, 525, 590, 660, 740, 820, n16];
  S.y = [NaN(1, 5), 63, 75, 94, 114, 144, 174, 214, 254, 300, 340, 380, ...
         425, 470, 520, 580, 650, 730, 820, 920, 1000, n16];
  S.z = [26, 35, 42, 50, 60, 73, 88, 112, 136, 172, 210, 258, 310, 365, ...
         415, 465, 520, 575, 640, 710, 790, 900, 1000, 1100, 1250, n16];
  S.za = [32, 42, 52, 64, 77, 98, 118, 148, 180, 226, 274, 335, 400, 470, ...
          535, 600, 670, 740, 820, 920, 1000, 1150, 1300, 1450, 1600, n16];
  S.zb = [40, 50, 67, 90, 108, 136, 160, 200, 242, 300, 360, 445, 525, ...
          620, 700, 780, 880, 960, 1050, 1200, 1300, 1500, 1650, 1850, ...
          2100, n16];
  S.zc = [60, 80, 97, 130, 150, 188, 218, 274, 325, 405, 480, 585, 690, ...
          800, 900, 1000, 1150, 1250, 1350, 1550, 1700, 1900, 2100, 2400, ...
          2600, n16];
  S.j5 = [-2, -2, -2, -3, -3, -4, -4, -5, -5, -7, -7, -9, -9, -11, -11, ...
          -11, -13, -13, -13, -16, -16, -18, -18, -20, -20, n16];
  S.j7 = [-4, -4, -5, -6, -6, -8, -8, -10, -10, -12, -12, -15, -15, -18, ...
          -18, -18, -21, -21, -21, -26, -26, -28, -28, -32, -32, n16];
  S.j8 = [-6, NaN(1, 40)];
  S.J6 = [2, 5, 5, 6, 6, 8, 8, 10, 10, 13, 13, 16, 16, 18, 18, 18, 22, ...
          22, 22, 25, 25, 29, 29, 33, 33, n16];
  S.J7 = [4, 6, 8, 10, 10, 12, 12, 14, 14, 18, 18, 22, 22, 26, 26, 26, ...
          30, 30, 30, 36, 36, 39, 39, 43, 43, n16];
  S.J8 = [6, 10, 12, 15, 15, 20, 20, 24, 24, 28, 28, 34, 34, 41, 41, 41, ...
          47, 47, 47, 55, 55, 60, 60, 66, 66, n16];

endfunction

%!demo
%! ## A 25 mm shaft running in a bore: H7 for the hole, g6 for the shaft,
%! ## in micrometres, as the tables of ISO 286-2 give them.  The clearance
%! ## runs from the smallest hole on the largest shaft to the largest hole on
%! ## the smallest shaft; it never closes, so the shaft runs freely.
%!
%! hole = 1000 * draw.isofit (25, 'H7')
%! shaft = 1000 * draw.isofit (25, 'g6')
%! clearance = [hole(1) - shaft(2), hole(2) - shaft(1)]

## Expected values from the tables of ISO 286-2 (IS 919-2:1993)
%!test  # H7 at 25 mm, the hole of the hole-basis system
%! assert_equal (draw.isofit (25, 'H7'), [0, 0.021], 1e-12);

%!test  # g6 at 25 mm
%! assert_equal (draw.isofit (25, 'g6'), [-0.020, -0.007], 1e-12);

%!test  # f7 at 30 mm, the example of ISO 406
%! assert_equal (draw.isofit (30, 'f7'), [-0.041, -0.020], 1e-12);

%!test  # a size on a step boundary belongs to the lower step
%! assert_equal (draw.isofit (30, 'H7'), [0, 0.021], 1e-12);

%!test  # just above it, the next step
%! assert_equal (draw.isofit (30.001, 'H7'), [0, 0.025], 1e-12);

%!test  # A9 from 18 to 30 mm
%! assert_equal (draw.isofit (20, 'A9'), [0.300, 0.352], 1e-12);

%!test  # B12 from 225 to 250 mm
%! assert_equal (draw.isofit (240, 'B12'), [0.420, 0.880], 1e-12);

%!test  # C13 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'C13'), [0.480, 1.450], 1e-12);

%!test  # CD10 from 6 to 10 mm
%! assert_equal (draw.isofit (8, 'CD10'), [0.056, 0.114], 1e-12);

%!test  # D13 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'D13'), [0.520, 3.820], 1e-12);

%!test  # E5 up to 3 mm
%! assert_equal (draw.isofit (2, 'E5'), [0.014, 0.018], 1e-12);

%!test  # EF3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'EF3'), [0.014, 0.0165], 1e-12);

%!test  # F9 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'F9'), [0.145, 0.685], 1e-12);

%!test  # FG3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'FG3'), [0.006, 0.0085], 1e-12);

%!test  # G6 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'G6'), [0.038, 0.173], 1e-12);

%!test  # H18 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'H18'), [0, 1.8], 1e-12);

%!test  # H1 from 400 to 500 mm
%! assert_equal (draw.isofit (450, 'H1'), [0, 0.008], 1e-12);

%!test  # JS9 from 500 to 630 mm, exactly half the tolerance
%! assert_equal (draw.isofit (600, 'JS9'), [-0.0875, 0.0875], 1e-12);

%!test  # J6 from 400 to 500 mm
%! assert_equal (draw.isofit (450, 'J6'), [-0.007, 0.033], 1e-12);

%!test  # J7 from 3 to 6 mm, the same as JS7
%! assert_equal (draw.isofit (4, 'J7'), [-0.006, 0.006], 1e-12);

%!test  # J8 from 6 to 10 mm
%! assert_equal (draw.isofit (8, 'J8'), [-0.010, 0.012], 1e-12);

%!test  # K3 from 3 to 6 mm, delta included
%! assert_equal (draw.isofit (5, 'K3'), [-0.0025, 0], 1e-12);

%!test  # K4 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'K4'), [-0.0035, 0.0005], 1e-12);

%!test  # K7 from 18 to 30 mm, the example of ISO 286-1
%! assert_equal (draw.isofit (20, 'K7'), [-0.015, 0.006], 1e-12);

%!test  # K8 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'K8'), [-0.330, 0], 1e-12);

%!test  # K9 up to 3 mm
%! assert_equal (draw.isofit (2, 'K9'), [-0.025, 0], 1e-12);

%!test  # M3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'M3'), [-0.0055, -0.003], 1e-12);

%!test  # M6 from 250 to 315 mm, the special case
%! assert_equal (draw.isofit (300, 'M6'), [-0.041, -0.009], 1e-12);

%!test  # M8 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'M8'), [-0.016, 0.002], 1e-12);

%!test  # M9 from 3 to 6 mm, no delta above grade 8
%! assert_equal (draw.isofit (5, 'M9'), [-0.034, -0.004], 1e-12);

%!test  # M7 from 500 to 630 mm
%! assert_equal (draw.isofit (600, 'M7'), [-0.096, -0.026], 1e-12);

%!test  # N4 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'N4'), [-0.0105, -0.0065], 1e-12);

%!test  # N9 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'N9'), [-0.030, 0], 1e-12);

%!test  # N11 up to 3 mm
%! assert_equal (draw.isofit (2, 'N11'), [-0.064, -0.004], 1e-12);

%!test  # N9 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'N9'), [-0.675, -0.135], 1e-12);

%!test  # P3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'P3'), [-0.0135, -0.011], 1e-12);

%!test  # P6 from 500 to 630 mm, no delta above 500 mm
%! assert_equal (draw.isofit (600, 'P6'), [-0.122, -0.078], 1e-12);

%!test  # P9 from 400 to 500 mm
%! assert_equal (draw.isofit (450, 'P9'), [-0.223, -0.068], 1e-12);

%!test  # R7 from 2500 to 2800 mm
%! assert_equal (draw.isofit (2600, 'R7'), [-0.760, -0.550], 1e-12);

%!test  # S5 from 315 to 355 mm
%! assert_equal (draw.isofit (330, 'S5'), [-0.208, -0.183], 1e-12);

%!test  # S6 from 18 to 30 mm, the example of ISO 286-1
%! D = draw.isofit (20, 'S6');
%! assert_equal (D(2), -0.031, 1e-12);

%!test  # T6 from 24 to 30 mm
%! assert_equal (draw.isofit (27, 'T6'), [-0.050, -0.037], 1e-12);

%!test  # U6 from 2500 to 2800 mm
%! assert_equal (draw.isofit (2600, 'U6'), [-3.035, -2.900], 1e-12);

%!test  # V8 from 14 to 18 mm
%! assert_equal (draw.isofit (16, 'V8'), [-0.066, -0.039], 1e-12);

%!test  # X8 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'X8'), [-0.046, -0.028], 1e-12);

%!test  # Y10 from 40 to 50 mm
%! assert_equal (draw.isofit (45, 'Y10'), [-0.214, -0.114], 1e-12);

%!test  # Z7 from 6 to 10 mm
%! assert_equal (draw.isofit (8, 'Z7'), [-0.051, -0.036], 1e-12);

%!test  # ZA6 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'ZA6'), [-0.047, -0.039], 1e-12);

%!test  # ZB9 from 100 to 120 mm
%! assert_equal (draw.isofit (110, 'ZB9'), [-0.612, -0.525], 1e-12);

%!test  # ZC11 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'ZC11'), [-3.000, -2.600], 1e-12);

%!test  # a13 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'a13'), [-2.620, -1.650], 1e-12);

%!test  # b8 up to 3 mm
%! assert_equal (draw.isofit (2, 'b8'), [-0.154, -0.140], 1e-12);

%!test  # c12 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'c12'), [-1.110, -0.480], 1e-12);

%!test  # cd10 from 6 to 10 mm
%! assert_equal (draw.isofit (8, 'cd10'), [-0.114, -0.056], 1e-12);

%!test  # d11 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'd11'), [-1.870, -0.520], 1e-12);

%!test  # e10 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'e10'), [-1.150, -0.290], 1e-12);

%!test  # ef3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'ef3'), [-0.0165, -0.014], 1e-12);

%!test  # fg10 from 6 to 10 mm
%! assert_equal (draw.isofit (8, 'fg10'), [-0.066, -0.008], 1e-12);

%!test  # g8 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'g8'), [-0.368, -0.038], 1e-12);

%!test  # h7 from 18 to 30 mm
%! assert_equal (draw.isofit (20, 'h7'), [-0.021, 0], 1e-12);

%!test  # js18 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'js18'), [-16.5, 16.5], 1e-12);

%!test  # js7 from 18 to 30 mm
%! assert_equal (draw.isofit (20, 'js7'), [-0.0105, 0.0105], 1e-12);

%!test  # j5 up to 3 mm
%! assert_equal (draw.isofit (2, 'j5'), [-0.002, 0.002], 1e-12);

%!test  # j6 from 250 to 315 mm
%! assert_equal (draw.isofit (300, 'j6'), [-0.016, 0.016], 1e-12);

%!test  # j7 from 250 to 315 mm
%! assert_equal (draw.isofit (300, 'j7'), [-0.026, 0.026], 1e-12);

%!test  # j8 up to 3 mm
%! assert_equal (draw.isofit (2, 'j8'), [-0.006, 0.008], 1e-12);

%!test  # k3 from 3 to 6 mm, no fundamental deviation in grade 3
%! assert_equal (draw.isofit (5, 'k3'), [0, 0.0025], 1e-12);

%!test  # k4 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'k4'), [0.001, 0.005], 1e-12);

%!test  # k8 from 18 to 30 mm
%! assert_equal (draw.isofit (20, 'k8'), [0, 0.033], 1e-12);

%!test  # m7 from 2500 to 3150 mm
%! assert_equal (draw.isofit (3000, 'm7'), [0.076, 0.286], 1e-12);

%!test  # n9 from 30 to 50 mm
%! assert_equal (draw.isofit (40, 'n9'), [0.017, 0.079], 1e-12);

%!test  # p3 from 3 to 6 mm
%! assert_equal (draw.isofit (5, 'p3'), [0.012, 0.0145], 1e-12);

%!test  # r8 from 2800 to 3150 mm
%! assert_equal (draw.isofit (3000, 'r8'), [0.580, 0.910], 1e-12);

%!test  # s3 from 18 to 30 mm
%! assert_equal (draw.isofit (20, 's3'), [0.035, 0.039], 1e-12);

%!test  # t7 from 2800 to 3150 mm
%! assert_equal (draw.isofit (3000, 't7'), [2.100, 2.310], 1e-12);

%!test  # u9 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'u9'), [0.540, 0.695], 1e-12);

%!test  # v5 from 14 to 18 mm
%! assert_equal (draw.isofit (16, 'v5'), [0.039, 0.047], 1e-12);

%!test  # x10 up to 3 mm
%! assert_equal (draw.isofit (2, 'x10'), [0.020, 0.060], 1e-12);

%!test  # y10 from 40 to 50 mm
%! assert_equal (draw.isofit (45, 'y10'), [0.114, 0.214], 1e-12);

%!test  # z11 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'z11'), [1.250, 1.650], 1e-12);

%!test  # za9 from 40 to 50 mm
%! assert_equal (draw.isofit (45, 'za9'), [0.180, 0.242], 1e-12);

%!test  # zb10 from 225 to 250 mm
%! assert_equal (draw.isofit (240, 'zb10'), [1.050, 1.235], 1e-12);

%!test  # zc11 from 450 to 500 mm
%! assert_equal (draw.isofit (475, 'zc11'), [2.600, 3.000], 1e-12);

%!test  # IT01 and IT0 come from annex A of ISO 286-1
%! assert_equal (draw.isofit (450, 'h01'), [-0.004, 0], 1e-12);

%!test  # IT0 up to 3 mm
%! assert_equal (draw.isofit (2, 'H0'), [0, 0.0005], 1e-12);

%!test  # IT1 above 500 mm, given for experimental use
%! assert_equal (draw.isofit (3000, 'h1'), [-0.026, 0], 1e-12);

%!test  # a zero deviation is 0, not -0
%! D = draw.isofit (3000, 'K8');
%! assert_equal (1 / D(2), Inf);

%!error<draw.isofit: invalid number of input arguments.> draw.isofit (25)
%!error<draw.isofit: SIZE must be a real scalar above 0 and at most 3150.> ...
%! draw.isofit (0, 'H7')
%!error<draw.isofit: SIZE must be a real scalar above 0 and at most 3150.> ...
%! draw.isofit (3150.5, 'H7')
%!error<draw.isofit: SIZE must be a real scalar above 0 and at most 3150.> ...
%! draw.isofit ([10, 20], 'H7')
%!error<draw.isofit: SIZE must be a real scalar above 0 and at most 3150.> ...
%! draw.isofit ('25', 'H7')
%!error<draw.isofit: SIZE must be a real scalar above 0 and at most 3150.> ...
%! draw.isofit (25i, 'H7')
%!error<draw.isofit: CLASS must be a character vector.> draw.isofit (25, 7)
%!error<draw.isofit: CLASS must be a character vector.> ...
%! draw.isofit (25, {'H7'})
%!error<draw.isofit: 'Q7' is not an ISO 286 tolerance class.> ...
%! draw.isofit (25, 'Q7')
%!error<draw.isofit: 'H19' is not an ISO 286 tolerance class.> ...
%! draw.isofit (25, 'H19')
%!error<draw.isofit: 'H' is not an ISO 286 tolerance class.> ...
%! draw.isofit (25, 'H')
%!error<draw.isofit: 'Js7' is not an ISO 286 tolerance class.> ...
%! draw.isofit (25, 'Js7')
%!error<draw.isofit: 'H 7' is not an ISO 286 tolerance class.> ...
%! draw.isofit (25, 'H 7')
%!error<draw.isofit: ISO 286 defines no a9 for a size of 1 mm.> ...
%! draw.isofit (1, 'a9')
%!error<draw.isofit: ISO 286 defines no B9 for a size of 0.5 mm.> ...
%! draw.isofit (0.5, 'B9')
%!error<draw.isofit: ISO 286 defines no h14 for a size of 1 mm.> ...
%! draw.isofit (1, 'h14')
%!error<draw.isofit: ISO 286 defines no N9 for a size of 1 mm.> ...
%! draw.isofit (1, 'N9')
%!error<draw.isofit: ISO 286 defines no h01 for a size of 600 mm.> ...
%! draw.isofit (600, 'h01')
%!error<draw.isofit: ISO 286 defines no c9 for a size of 600 mm.> ...
%! draw.isofit (600, 'c9')
%!error<draw.isofit: ISO 286 defines no cd7 for a size of 12 mm.> ...
%! draw.isofit (12, 'cd7')
%!error<draw.isofit: ISO 286 defines no t7 for a size of 20 mm.> ...
%! draw.isofit (20, 't7')
%!error<draw.isofit: ISO 286 defines no V7 for a size of 12 mm.> ...
%! draw.isofit (12, 'V7')
%!error<draw.isofit: ISO 286 defines no j9 for a size of 20 mm.> ...
%! draw.isofit (20, 'j9')
%!error<draw.isofit: ISO 286 defines no j8 for a size of 20 mm.> ...
%! draw.isofit (20, 'j8')
%!error<draw.isofit: ISO 286 defines no J5 for a size of 20 mm.> ...
%! draw.isofit (20, 'J5')
%!error<draw.isofit: ISO 286 defines no J7 for a size of 600 mm.> ...
%! draw.isofit (600, 'J7')
%!error<draw.isofit: ISO 286 defines no K9 for a size of 5 mm.> ...
%! draw.isofit (5, 'K9')
%!error<draw.isofit: ISO 286 defines no P2 for a size of 20 mm.> ...
%! draw.isofit (20, 'P2')
%!error<draw.isofit: ISO 286 defines no M01 for a size of 2 mm.> ...
%! draw.isofit (2, 'M01')
