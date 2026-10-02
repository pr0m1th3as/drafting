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
## @deftypefn {drafting} {@var{S} =} solid.read (@var{FILE})
##
## Read a solid from a STEP file.
##
## @code{@var{S} = solid.read (@var{FILE})} returns the shapes held by the
## STEP file @var{FILE} as one @code{solid.Shape}, in millimetres whatever
## unit the file was written in.  A file holding several parts returns them
## together, and @code{solid.Shape.numsolids} counts them.
##
## STEP (ISO 10303-21) is the format every mechanical CAD program exchanges
## solids in, and it keeps their exact geometry: a hole read from it is a true
## cylinder, as it was modelled.  @var{FILE} must end in @file{.step} or
## @file{.stp}, in either case.
##
## @seealso{solid.write, solid.Shape}
## @end deftypefn

function S = read (FILE)

  ## Input validation
  if (nargin != 1)
    error ("solid.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("solid.read: FILE must be a non-empty character vector.");
  endif
  [~, ~, ext] = fileparts (FILE);
  if (! any (strcmpi (ext, {'.step', '.stp'})))
    error ("solid.read: FILE must end in .step or .stp.");
  endif
  if (! isfile (FILE))
    error ("solid.read: cannot find file '%s'.", FILE);
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.read: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('readstep', 'solid.read', FILE));

endfunction

%!testif ; exist ('__occt__') == 3  # a round trip keeps the exact geometry
%! A = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! f = [tempname(), '.step'];
%! unwind_protect
%!   solid.write (f, A);
%!   S = solid.read (f);
%!   assert_equal (volume (S), 38400 - 192 * pi, 1e-9);
%!   assert_equal (numfaces (S), 7);
%!   assert_equal (isvalid (S), true);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # the extension in upper case
%! f = [tempname(), '.STP'];
%! unwind_protect
%!   solid.write (f, solid.sphere (5));
%!   assert_equal (volume (solid.read (f)), 4 / 3 * pi * 125, 1e-9);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # several parts come back together
%! A = solid.box (10, 10, 10);
%! f = [tempname(), '.step'];
%! unwind_protect
%!   solid.write (f, union (A, translate (A, [20, 0, 0])));
%!   assert_equal (numsolids (solid.read (f)), 2);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

## A file that is not STEP can only be told apart by Open CASCADE, and %!error
## takes no run-time condition, so this error is caught in a conditional test.
%!testif ; exist ('__occt__') == 3
%! f = [tempname(), '.step'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "not a STEP file\n");
%! fclose (fid);
%! unwind_protect
%!   try
%!     solid.read (f);
%!     msg = '';
%!   catch err
%!     msg = err.message;
%!   end_try_catch
%!   assert_equal (msg, sprintf (strcat ("solid.read: cannot read '%s'", ...
%!                                       " as a STEP file."), f));
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!error<solid.read: invalid number of input arguments.> solid.read ()
%!error<solid.read: FILE must be a non-empty character vector.> solid.read ('')
%!error<solid.read: FILE must be a non-empty character vector.> solid.read (1)
%!error<solid.read: FILE must end in .step or .stp.> solid.read ('part.stl')
%!error<solid.read: FILE must end in .step or .stp.> solid.read ('part')
%!error<solid.read: cannot find file 'no_such_part_9f2c.step'.> ...
%! solid.read ('no_such_part_9f2c.step')
