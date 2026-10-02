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
## @deftypefn  {drafting} {} solid.write (@var{FILE}, @var{S})
## @deftypefnx {drafting} {} solid.write (@var{FILE}, @var{S}, @qcode{'Tolerance'}, @var{TOL})
##
## Write a solid to a STEP or STL file.
##
## @code{solid.write (@var{FILE}, @var{S})} writes the @code{solid.Shape}
## @var{S} in the format named by the extension of @var{FILE}, in either case:
##
## @table @asis
## @item @file{.step}, @file{.stp}
## STEP (ISO 10303-21, application protocol 214), in millimetres.  The exact
## geometry is kept, so this is the file to send to a CAD program or to
## another manufacturer.  The part is named after the base name of
## @var{FILE}.
##
## @item @file{.stl}
## Binary STL, a mesh of triangles in millimetres, which is what a slicer
## prints from.  The facets approximate every curved surface; their vertices
## lie on it.
## @end table
##
## @code{solid.write (@dots{}, @qcode{'Tolerance'}, @var{TOL})} sets, for an
## STL file, the largest distance in millimetres between a facet and the true
## surface.  It is 0.01 by default, well below what a printer resolves; a
## larger value gives a smaller file.  No facet spans more than 20 degrees of
## a curved surface, whatever @var{TOL}.  A STEP file is exact and takes no
## tolerance.
##
## @seealso{solid.read, solid.Shape}
## @end deftypefn

function write (FILE, S, varargin)

  ## Input validation
  if (nargin < 2)
    error ("solid.write: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("solid.write: FILE must be a non-empty character vector.");
  endif
  if (! isa (S, 'solid.Shape') || ! isscalar (S))
    error ("solid.write: S must be a solid.Shape object.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("solid.write: Name/Value arguments must come in pairs.");
  endif
  opt = struct ('Tolerance', []);
  known = fieldnames (opt);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      error ("solid.write: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  [folder, base, ext] = fileparts (FILE);
  isstep = any (strcmpi (ext, {'.step', '.stp'}));
  if (! isstep && ! strcmpi (ext, '.stl'))
    error ("solid.write: FILE must end in .step, .stp or .stl.");
  endif
  if (isstep && ! isempty (opt.Tolerance))
    error ("solid.write: Tolerance applies to STL files only.");
  endif
  if (isempty (opt.Tolerance))
    opt.Tolerance = 0.01;
  endif
  errmsg = solid.__checkpos__ (opt.Tolerance, 'Tolerance');
  if (! isempty (errmsg))
    error ("solid.write: %s", errmsg);
  endif
  if (! isempty (folder) && ! isfolder (folder))
    error ("solid.write: folder '%s' does not exist.", folder);
  endif
  if (isempty (S))
    error ("solid.write: S is empty, so there is nothing to write.");
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.write: %s", errmsg);
  endif

  if (isstep)
    __occt__ ('writestep', 'solid.write', S.Data, FILE, base);
  else
    __occt__ ('writestl', 'solid.write', S.Data, FILE, ...
              double (opt.Tolerance), 20);
  endif

endfunction

## The vertices of a binary STL file, three rows per facet
%!function V = stlvertices (f)
%!  fid = fopen (f, 'r', 'ieee-le');
%!  fread (fid, 80, 'uint8');
%!  n = fread (fid, 1, 'uint32');
%!  V = zeros (3 * n, 3);
%!  for k = 1:n
%!    fread (fid, 3, 'single');
%!    V(3*k-2:3*k,:) = fread (fid, [3, 3], 'single')';
%!    fread (fid, 1, 'uint16');
%!  endfor
%!  fclose (fid);
%!endfunction

%!testif ; exist ('__occt__') == 3  # STEP keeps the exact surfaces
%! f = [tempname(), '.step'];
%! unwind_protect
%!   solid.write (f, solid.cylinder (4, 12));
%!   txt = fileread (f);
%!   assert_equal (isempty (strfind (txt, 'CYLINDRICAL_SURFACE')), false);
%!   assert_equal (isempty (strfind (txt, "'GNU Octave drafting package'")), ...
%!                 false);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # the product is named after the file
%! f = [tempname(), '.stp'];
%! [~, base] = fileparts (f);
%! unwind_protect
%!   solid.write (f, solid.box (1, 2, 3));
%!   txt = fileread (f);
%!   assert_equal (isempty (strfind (txt, ["PRODUCT('", base])), false);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # STL: a box is twelve triangles
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   solid.write (f, solid.box (10, 20, 30));
%!   V = stlvertices (f);
%!   assert_equal (rows (V), 36);
%!   assert_equal (min (V), [0, 0, 0]);
%!   assert_equal (max (V), [10, 20, 30]);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # facets stay within the tolerance
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   solid.write (f, solid.cylinder (4, 12), 'Tolerance', 0.05);
%!   V = stlvertices (f);
%!   assert_equal (max (abs (hypot (V(:,1), V(:,2)) - 4)) < 1e-5, true);
%!   ## Gap at the midpoint of every edge of a facet on the curved side; the
%!   ## flat ends are left out, their facets having no curve to follow
%!   A = V(1:3:end,:);
%!   B = V(2:3:end,:);
%!   C = V(3:3:end,:);
%!   side = ! (A(:,3) == B(:,3) & B(:,3) == C(:,3));
%!   M = ([A(side,1:2); B(side,1:2); C(side,1:2)] ...
%!        + [B(side,1:2); C(side,1:2); A(side,1:2)]) / 2;
%!   gap = 4 - hypot (M(:,1), M(:,2));
%!   assert_equal (max (gap) <= 0.05 + 1e-5, true);
%!   assert_equal (max (gap) > 0.01, true);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # a finer tolerance gives more facets
%! f1 = [tempname(), '.stl'];
%! f2 = [tempname(), '.stl'];
%! unwind_protect
%!   solid.write (f1, solid.sphere (20), 'Tolerance', 0.5);
%!   solid.write (f2, solid.sphere (20), 'Tolerance', 0.01);
%!   assert_equal (rows (stlvertices (f2)) > rows (stlvertices (f1)), true);
%! unwind_protect_cleanup
%!   unlink (f1);
%!   unlink (f2);
%! end_unwind_protect

%!error<solid.write: invalid number of input arguments.> solid.write ('a.stl')
%!error<solid.write: FILE must be a non-empty character vector.> ...
%! solid.write ('', solid.Shape ())
%!error<solid.write: S must be a solid.Shape object.> solid.write ('a.stl', 1)
%!error<solid.write: Name/Value arguments must come in pairs.> ...
%! solid.write ('a.stl', solid.Shape (), 'Tolerance')
%!error<solid.write: unknown parameter.> ...
%! solid.write ('a.stl', solid.Shape (), 'Angle', 5)
%!error<solid.write: FILE must end in .step, .stp or .stl.> ...
%! solid.write ('a.dxf', solid.Shape ())
%!error<solid.write: Tolerance applies to STL files only.> ...
%! solid.write ('a.step', solid.Shape (), 'Tolerance', 0.1)
%!error<solid.write: Tolerance must be a positive and finite real scalar.> ...
%! solid.write ('a.stl', solid.Shape (), 'Tolerance', 0)
%!error<solid.write: folder 'no_such_folder_9f2c' does not exist.> ...
%! solid.write (fullfile ('no_such_folder_9f2c', 'a.stl'), solid.Shape ())
%!error<solid.write: S is empty, so there is nothing to write.> ...
%! solid.write ('a.stl', solid.Shape ())
