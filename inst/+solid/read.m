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
## together, and @code{solid.Shape.numsolids} counts them.  The colour the
## file gives a solid, or failing that the first of its faces with one, is
## its row of @code{solid.Shape.Colour}.
##
## STEP (ISO 10303-21) is the format every mechanical CAD program exchanges
## solids in, and it keeps their exact geometry: a hole read from it is a true
## cylinder, as it was modelled.  A STEP file must end in @file{.step} or
## @file{.stp}, in either case, and open with the keyword
## @qcode{ISO-10303-21;}, which may follow white space and comments.
##
## @code{model.read} reads the same file as a @code{model.Assembly}, its
## parts named and placed as the file has them.  A triangle mesh, from an
## STL, OBJ or PLY file, is read by @code{polymesh.read} and made a solid by
## @code{solid.polyhedron}.
##
## @seealso{solid.Shape.write, solid.Shape, model.read, polymesh.read}
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
  if (! isstep (FILE))
    error ("solid.read: FILE is not a readable STEP file.");
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.read: %s", errmsg);
  endif

  c = __occt__ ('readstep', 'solid.read', FILE);
  S = solid.Shape (c{1});
  S.Colour = c{2};

endfunction

## Check that FILE opens with the keyword of ISO 10303-21
function TF = isstep (FILE)

  TF = false;
  fid = fopen (FILE, 'r');
  if (fid < 0)
    return;
  endif
  head = fread (fid, [1, 65536], 'uint8=>char');
  fclose (fid);

  ## Skip white space and comments
  while (true)
    k = find (! isspace (head), 1);
    if (isempty (k))
      return;
    endif
    head = head(k:end);
    if (! strncmp (head, '/*', 2))
      break;
    endif
    k = strfind (head(3:end), '*/');
    if (isempty (k))
      return;
    endif
    head = head(k(1)+4:end);
  endwhile
  TF = strncmpi (head, 'ISO-10303-21;', 13);

endfunction

%!testif ; exist ('__occt__') == 3  # a round trip keeps the exact geometry
%! A = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (A, f);
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
%!   write (solid.sphere (5), f);
%!   assert_equal (volume (solid.read (f)), 4 / 3 * pi * 125, 1e-9);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # several parts come back together
%! A = solid.box (10, 10, 10);
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (union (A, translate (A, [20, 0, 0])), f);
%!   assert_equal (numsolids (solid.read (f)), 2);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # a comment before the keyword
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (solid.box (1, 2, 3), f);
%!   txt = fileread (f);
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "/* exported */\n%s", txt);
%!   fclose (fid);
%!   assert_equal (volume (solid.read (f)), 6, 1e-12);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # the colours of the solids come back
%! B = solid.box (10, 10, 10);
%! U = union (B, translate (B, [20, 0, 0]));
%! U.Colour = [1, 0, 0; 0, 0.5, 1];
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (U, f);
%!   R = solid.read (f);
%!   assert_equal (R.Colour, U.Colour, 1e-6);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # a solid without a colour comes back bare
%! B = solid.box (10, 10, 10);
%! U = union (B, translate (B, [20, 0, 0]));
%! U.Colour = [NaN, NaN, NaN; 0, 1, 0];
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (U, f);
%!   R = solid.read (f);
%!   assert_equal (R.Colour, U.Colour, 1e-6);
%!   write (B, f);
%!   R = solid.read (f);
%!   assert_equal (R.Colour, []);
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
%!error<solid.read: FILE is not a readable STEP file.>
%! f = [tempname(), '.step'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "not a STEP file\n");
%! fclose (fid);
%! unwind_protect
%!   solid.read (f);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect
