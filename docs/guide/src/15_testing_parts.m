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

## # Testing parts
##
## A part written as code can be checked by code. Octave keeps the tests of a
## function in the function's own file, in blocks after its code, and `test`
## runs them. This package is tested that way, and a part is too: its volume
## is the one intended, it fits the parts around it, and a size that cannot
## be made is refused.
##
## ## Tests in the file
##
## The bracket of the previous tutorial, unchanged, with five tests after its
## code. Every line of a test starts with `%!`, so Octave reads them as
## comments when it runs the function.

#: file bracket.m
function B = bracket (W, N = 2)
  ## B = bracket (W, N): an angle bracket W millimetres wide, its base and
  ## wall 6 thick and 40 deep, with N holes for M6 screws through the base,
  ## spaced evenly along it, 2 unless N is given.
  if (! (isscalar (N) && N == fix (N) && N >= 1))
    error ("bracket: N must be a positive whole number.");
  endif
  if (W / N < 12)
    error ("bracket: %d holes do not fit in a width of %g mm.", N, W);
  endif
  base = solid.box (W, 40, 6);
  wall = solid.box (W, 6, 40);
  B = union (base, wall);
  x = W * ((1:N)' - 0.5) / N;
  P = [x, 23 * ones(N, 1), 6 * ones(N, 1)];
  B = hole (B, P, 6.6, Inf);
endfunction

%!test  # base and wall, where they overlap counted once, less two holes
%! B = bracket (60);
%! V = 60 * (240 + 240 - 36) - 2 * pi * 3.3 ^ 2 * 6;
%! assert_equal (volume (B), V, -1e-9);

%!test  # one hole for each screw
%! B = bracket (120, 4);
%! assert_equal (numel (faces (B, 'Type', 'cylinder')), 4);

%!test  # one valid solid, whatever the size
%! B = bracket (120, 4);
%! assert (numsolids (B) == 1 && isvalid (B));

%!test  # an M6 screw passes through every hole without touching it
%! B = bracket (120, 4);
%! S = rectarray (translate (solid.cylinder (3, 20), [15, 23, -5]), ...
%!                [4, 1, 1], [30, 0, 0]);
%! assert_equal (volume (intersect (B, S)), 0, 1e-6);

%!error <bracket: 6 holes do not fit in a width of 60 mm.> bracket (60, 6)
#: end

## Each `%!test` block is a small script of its own: it builds what it needs
## and checks it. The text after `#` on its first line says what it checks,
## and a failure report shows it with the block. `%!error` passes only when the
## call after it raises an error whose message matches the one between the
## angle brackets.
##
## ## Two ways to check
##
## `assert (COND)` passes when a condition is true, which suits a plain yes
## or no: the bracket is one solid, and a valid one.
##
## `assert_equal (OBSERVED, EXPECTED)`, new in Octave 11, compares a value
## with the one expected: their class, their size and their values, which
## must match exactly. That suits a count, such as the four holes of the wide
## bracket. `assert_equal (OBSERVED, EXPECTED, TOL)` allows the values a
## tolerance, which a computed length, area or volume needs. A negative
## tolerance is relative: `-1e-9` allows a difference of one part in a
## thousand million of the expected value. A positive one is absolute, in the
## units of the value: `1e-6` allows a difference of a millionth.
##
## A failed comparison says what it found against what it expected. Had the
## holes been forgotten in the expected volume:

assert_equal (volume (bracket (60)), ...
              60 * (240 + 240 - 36), -1e-9);  #: error

## ## Running them
##
## `test` with the name of the function runs every test in its file:

test ('bracket')

## Run them after every change to the part. A change that moves a hole into
## the wall, or makes the screws foul the base, fails a test at once, long
## before anything reaches the printer.
##
## ## Parts that meet
##
## The screw test is the pattern for any two parts that must fit together:
## the volume they share is zero when they only touch, and the volume of the
## overlap when they clash. Gears that should mesh, a lid on its box or a pin
## in its bore are checked the same way:

assert_equal (volume (intersect (gear1, gear2)), 0, 1e-6);  #: not run

## A test fails as soon as one of them is turned the wrong way or put out of
## place.
