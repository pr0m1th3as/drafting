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
## Read an assembly from a STEP or 3MF file.
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
## @code{@var{A} = model.read (@var{FILE})} reads a 3MF file, @file{.3mf},
## the same way: each object a @code{polymesh.Mesh} part, in the colours
## of its triangles, each object made of others an assembly of them, and
## the build an assembly named after @var{FILE}, unless it is one assembly
## placed as it is.  An object without a name is named after its number,
## and a name used twice is made distinct.  3MF may place an object scaled
## or mirrored, which a @code{geom.UCS} cannot: such an object is placed as
## a copy of it, made so, at the origin, named after it with
## @qcode{' (placed)'}.
##
## @code{solid.read} reads a STEP file as one shape, its parts the solids
## of it, and @code{polymesh.read} a 3MF file as one mesh.
##
## @seealso{model.Assembly, solid.read, polymesh.read}
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
  if (! any (strcmpi (ext, {'.step', '.stp', '.3mf'})))
    error ("model.read: FILE must end in .step, .stp or .3mf.");
  endif
  if (! isfile (FILE))
    error ("model.read: cannot find file '%s'.", FILE);
  endif
  if (strcmpi (ext, '.3mf'))
    T = __mesh__ ('read3mftree', 'model.read', FILE, base);
    A = model.Assembly.__from3mf__ (T);
    return;
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
%!   write (solid.box (1, 2, 3), f);
%!   R = model.read (f);
%!   assert_equal (R.Name, base);
%!   assert_equal ([numparts(R), numinstances(R)], [1, 1]);
%!   assert_equal (volume (shape (R)), 6, -1e-12);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

## A 3MF package of the model MODEL, zipped, its file NAME of the text TEXT
## put under the folder D
%!function zippart (d, name, text)
%!  folder = fileparts (fullfile (d, name));
%!  if (! isfolder (folder))
%!    mkdir (folder);
%!  endif
%!  fid = fopen (fullfile (d, name), 'w');
%!  fputs (fid, text);
%!  fclose (fid);
%!endfunction
%!function f = zip3mf (model)
%!  d = tempname ();
%!  mkdir (d);
%!  rels = ['<?xml version="1.0" encoding="UTF-8"?><Relationships ', ...
%!          'xmlns="http://schemas.openxmlformats.org/package/2006/', ...
%!          'relationships"><Relationship Target="/3D/3dmodel.model" ', ...
%!          'Id="rel0" Type="http://schemas.microsoft.com/', ...
%!          '3dmanufacturing/2013/01/3dmodel"/></Relationships>'];
%!  zippart (d, '_rels/.rels', rels);
%!  zippart (d, '3D/3dmodel.model', model);
%!  f = [tempname(), '.3mf'];
%!  zip (f, {'_rels/.rels', '3D/3dmodel.model'}, d);
%!  confirm_recursive_rmdir (false, 'local');
%!  rmdir (d, 's');
%!endfunction

%!test  # 3MF: an assembly of mesh parts comes back as it was written
%! T = polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1], ...
%!                    [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4]);
%! A = add (model.Assembly ('pair'), 'tet', T, geom.UCS ());
%! A = add (A, 'tet', [], geom.UCS ([1, 0, 0], [5, 0, 0]));
%! f = [tempname(), '.3mf'];
%! unwind_protect
%!   write (A, f);
%!   R = model.read (f);
%!   assert_equal (R.Name, 'pair');
%!   assert_equal ({R.Parts.name}, {'tet'});
%!   assert_equal ({R.Instances.name}, {'tet', 'tet:2'});
%!   assert_equal (R.Instances(2).placement == A.Instances(2).placement, true);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: a scaled placement becomes a copy of its part, made so
%! o = ['<object id="1" type="model" name="tet"><mesh><vertices>', ...
%!      '<vertex x="0" y="0" z="0"/><vertex x="1" y="0" z="0"/>', ...
%!      '<vertex x="0" y="1" z="0"/><vertex x="0" y="0" z="1"/>', ...
%!      '</vertices><triangles><triangle v1="0" v2="2" v3="1"/>', ...
%!      '<triangle v1="0" v2="1" v3="3"/><triangle v1="1" v2="2" v3="3"/>', ...
%!      '<triangle v1="2" v2="0" v3="3"/></triangles></mesh></object>'];
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources>', o, '</resources>', ...
%!      '<build><item objectid="1"/>', ...
%!      '<item objectid="1" transform="2 0 0 0 2 0 0 0 2 10 0 0"/>', ...
%!      '</build></model>'];
%! f = zip3mf (m);
%! unwind_protect
%!   [~, base] = fileparts (f);
%!   R = model.read (f);
%!   assert_equal (R.Name, base);
%!   assert_equal ({R.Parts.name}, {'tet', 'tet (placed)'});
%!   assert_equal (max (R.Parts(2).item.Vertices), [12, 2, 2]);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: objects without names, or with one name, named apart
%! o = @(id, nm) sprintf (['<object id="%d" type="model"%s><mesh>', ...
%!                         '<vertices><vertex x="0" y="0" z="0"/>', ...
%!                         '<vertex x="1" y="0" z="0"/>', ...
%!                         '<vertex x="0" y="1" z="0"/></vertices>', ...
%!                         '<triangles><triangle v1="0" v2="1" v3="2"/>', ...
%!                         '</triangles></mesh></object>'], id, nm);
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources>', o(3, ''), ...
%!      o(4, ' name="a"'), o(5, ' name="a"'), '</resources><build>', ...
%!      '<item objectid="3"/><item objectid="4"/><item objectid="5"/>', ...
%!      '</build></model>'];
%! f = zip3mf (m);
%! unwind_protect
%!   R = model.read (f);
%!   assert_equal ({R.Parts.name}, {'object3', 'a', 'a_2'});
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!error<model.read: invalid number of input arguments.> model.read ()
%!error<model.read: FILE must be a non-empty character vector.> model.read (1)
%!error<model.read: FILE must end in .step, .stp or .3mf.> model.read ('a.stl')
%!error<model.read: cannot find file 'no_such_part_7e1a.step'.> ...
%! model.read ('no_such_part_7e1a.step')
