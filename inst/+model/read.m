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
## @deftypefn {drafting} {@var{A} =} model.read (@var{FILE})
##
## Read an assembly from a STEP file.
##
## @code{@var{A} = model.read (@var{FILE})} returns the product the STEP file
## @var{FILE} holds as a @code{model.Assembly}, in millimetres whatever unit
## the file was written in: its parts with their names and the colours of
## their solids, placed where the file places them and named as it names the
## placements, and its sub-assemblies the same way.  A part the file places
## several times is one part placed several times.  Several products at the
## top of the file are placed where they are in one assembly, and a file of
## a single part gives an assembly placing it once; either is named after
## the base name of @var{FILE}.
##
## @code{solid.read} reads the same file as one shape, its parts the solids
## of it.
##
## @seealso{model.Assembly, solid.read}
## @end deftypefn

function A = read (FILE)

  ## Input validation
  if (nargin != 1)
    error ("model.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("model.read: FILE must be a non-empty character vector.");
  endif
  [~, base, ext] = fileparts (FILE);
  if (! any (strcmpi (ext, {'.step', '.stp'})))
    error ("model.read: FILE must end in .step or .stp.");
  endif
  if (! isfile (FILE))
    error ("model.read: cannot find file '%s'.", FILE);
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("model.read: %s", errmsg);
  endif

  T = __occt__ ('readassembly', 'model.read', FILE, base);
  A = model.Assembly.__fromtree__ (T, base);

endfunction

## The assembly A written to a STEP file and read back
%!function R = ringstep (A)
%!  f = [tempname(), '.step'];
%!  unwind_protect
%!    write (A, f);
%!    R = model.read (f);
%!  unwind_protect_cleanup
%!    unlink (f);
%!  end_unwind_protect
%!endfunction

%!testif ; exist ('__occt__') == 3  # names, placements and colours come back
%! pin = solid.cylinder (2, 12);
%! pin.Colour = [0.8, 0.2, 0.2];
%! A = model.Assembly ('ring');
%! A = add (A, 'plate', solid.box (60, 60, 4), ...
%!          geom.UCS ([0, 0, 1], [-30, -30, -4]));
%! A = add (A, 'pin', pin, geom.UCS ([0, 0, 1], [20, 0, 0]));
%! A = add (A, 'pin', [], geom.UCS ([1, 0, 0], [0, 20, 6]), 'Name', 'lying');
%! R = ringstep (A);
%! assert_equal (R.Name, 'ring');
%! assert_equal ({R.Parts.name}, {'plate', 'pin'});
%! assert_equal ({R.Instances.name}, {'plate', 'pin', 'lying'});
%! assert_equal ({R.Instances.part}, {'plate', 'pin', 'pin'});
%! assert_equal (R.Instances(3).placement == A.Instances(3).placement, true);
%! assert_equal (R.Parts(2).item.Colour, [0.8, 0.2, 0.2], 1e-6);

%!testif ; exist ('__occt__') == 3  # a sub-assembly placed twice, once defined
%! A = add (model.Assembly ('stage'), 'pin', solid.cylinder (2, 12), ...
%!          geom.UCS ());
%! B = add (model.Assembly ('top'), 'stage', A, geom.UCS ());
%! B = add (B, 'stage', [], geom.UCS ([0, 0, 1], [0, 0, 50]));
%! R = ringstep (B);
%! assert_equal ([numparts(R), numinstances(R)], [1, 2]);
%! assert_equal (class (R.Parts(1).item), 'model.Assembly');

%!testif ; exist ('__occt__') == 3  # a single part, placed once, named by file
%! f = [tempname(), '.step'];
%! [~, base] = fileparts (f);
%! unwind_protect
%!   solid.write (f, solid.box (1, 2, 3));
%!   R = model.read (f);
%!   assert_equal (R.Name, base);
%!   assert_equal ([numparts(R), numinstances(R)], [1, 1]);
%!   assert_equal (volume (shape (R)), 6, -1e-12);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!error<model.read: invalid number of input arguments.> model.read ()
%!error<model.read: FILE must be a non-empty character vector.> model.read (1)
%!error<model.read: FILE must end in .step or .stp.> model.read ('a.stl')
%!error<model.read: cannot find file 'no_such_part_7e1a.step'.> ...
%! model.read ('no_such_part_7e1a.step')
