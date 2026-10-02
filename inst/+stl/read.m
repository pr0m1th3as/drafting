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
## @deftypefn  {drafting} {@var{M} =} stl.read (@var{FILE})
## @deftypefnx {drafting} {@var{M} =} stl.read (@var{FILE}, @qcode{'Tolerance'}, @var{T})
##
## Read a triangle mesh from an STL file.
##
## @code{@var{M} = stl.read (@var{FILE})} reads the binary or ASCII STL file
## @var{FILE} and returns its mesh as a struct with the fields
## @code{vertices}, an @math{N}-by-3 matrix of points, and @code{faces}, a
## @math{K}-by-3 matrix of the indices of each triangle's corners in
## @code{vertices}.  That is the form @code{patch} takes, and the form
## @code{stl.section} cuts.
##
## An STL file repeats every corner for every triangle that has it.  The
## corners are welded into vertices, each shared by every triangle that meets
## there, and a triangle two of whose corners become one is dropped.  The
## coordinates are taken as they are written; an STL file has no units, and
## most are in millimetres.
##
## @code{@var{M} = stl.read (@var{FILE}, @qcode{'Tolerance'}, @var{T})} welds
## corners that lie within @var{T} of one another, not only those that are
## equal, which closes the hairline gaps some programs leave in a mesh.  The
## default @var{T} is 0.
##
## The format is told from the file: a binary file is exactly as long as the
## number of triangles it declares makes it, and anything else is read as
## ASCII, the three numbers after each @qcode{vertex}, whatever the case and
## spacing.
##
## @seealso{stl.section, stl.write, solid.polyhedron}
## @end deftypefn

function M = read (FILE, varargin)

  ## Input validation
  if (nargin != 1 && nargin != 3)
    error ("stl.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE))
    error ("stl.read: FILE must be a character vector.");
  endif
  [~, ~, ext] = fileparts (FILE);
  if (! strcmpi (ext, '.stl'))
    error ("stl.read: FILE must end in .stl.");
  endif
  T = 0;
  if (nargin == 3)
    if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Tolerance'))
      error ("stl.read: unknown parameter.");
    endif
    T = varargin{2};
    if (! isnumeric (T) || ! isreal (T) || ! isscalar (T) || ! isfinite (T) ...
        || T < 0)
      error ("stl.read: Tolerance must be a non-negative finite real scalar.");
    endif
  endif
  if (! isfile (FILE))
    error ("stl.read: FILE is not a readable STL file.");
  endif

  [V, F] = __mesh__ ('read', 'stl.read', FILE, double (T));
  M = struct ('vertices', V, 'faces', F);

endfunction

## A unit cube written as STL, binary or ASCII, its triangles turned outwards,
## for the tests
%!function V = cube ()
%!  P = [0, 0, 0; 1, 0, 0; 1, 1, 0; 0, 1, 0; ...
%!       0, 0, 1; 1, 0, 1; 1, 1, 1; 0, 1, 1];
%!  F = [1, 3, 2; 1, 4, 3; 5, 6, 7; 5, 7, 8; 1, 2, 6; 1, 6, 5; ...
%!       2, 3, 7; 2, 7, 6; 3, 4, 8; 3, 8, 7; 4, 1, 5; 4, 5, 8];
%!  V = P(F',:);
%!endfunction
%!function writebinary (file, V)
%!  fid = fopen (file, 'w');
%!  fwrite (fid, zeros (1, 80), 'uint8');
%!  fwrite (fid, rows (V) / 3, 'uint32');
%!  for t = 1:rows (V) / 3
%!    fwrite (fid, [0, 0, 0, reshape(V(3*t-2:3*t,:)', 1, [])], 'single');
%!    fwrite (fid, 0, 'uint16');
%!  endfor
%!  fclose (fid);
%!endfunction

%!test  # binary: the corners welded into eight vertices
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   writebinary (f, cube ());
%!   M = stl.read (f);
%!   assert_equal (size (M.vertices), [8, 3]);
%!   assert_equal (size (M.faces), [12, 3]);
%!   assert_equal (sortrows (M.vertices), [0, 0, 0; 0, 0, 1; 0, 1, 0; ...
%!                 0, 1, 1; 1, 0, 0; 1, 0, 1; 1, 1, 0; 1, 1, 1]);
%!   V = cube ();
%!   assert_equal (M.vertices(M.faces',:), V);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # ASCII, whatever the case and the spacing
%! f = [tempname(), '.STL'];
%! unwind_protect
%!   V = cube ();
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "solid  cube\n");
%!   for t = 1:12
%!     fprintf (fid, "  facet  NORMAL 0 0 0\n   outer loop\n");
%!     fprintf (fid, "\tVertex %g %g %g\n", V(3*t-2:3*t,:)');
%!     fprintf (fid, "   endloop\n  endfacet\n");
%!   endfor
%!   fprintf (fid, "endsolid cube\n");
%!   fclose (fid);
%!   M = stl.read (f);
%!   assert_equal (size (M.vertices), [8, 3]);
%!   assert_equal (M.vertices(M.faces',:), V);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # a corner a hair away, welded within a tolerance
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   V = cube ();
%!   V(end,:) += 1e-7;
%!   writebinary (f, V);
%!   M = stl.read (f);
%!   assert_equal (rows (M.vertices), 9);
%!   M = stl.read (f, 'Tolerance', 1e-5);
%!   assert_equal (rows (M.vertices), 8);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # a triangle that collapses is dropped; an empty file is empty
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   writebinary (f, [cube(); 0, 0, 0; 0, 0, 0; 1, 1, 1]);
%!   M = stl.read (f);
%!   assert_equal (rows (M.faces), 12);
%!   writebinary (f, zeros (0, 3));
%!   M = stl.read (f);
%!   assert_equal (size (M.vertices), [0, 3]);
%!   assert_equal (size (M.faces), [0, 3]);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!error<stl.read: invalid number of input arguments.> stl.read ()
%!error<stl.read: invalid number of input arguments.> stl.read ('a.stl', 1)
%!error<stl.read: FILE must be a character vector.> stl.read (1)
%!error<stl.read: FILE must end in .stl.> stl.read ('part.step')
%!error<stl.read: unknown parameter.> stl.read ('a.stl', 'Weld', 1)
%!error<stl.read: Tolerance must be a non-negative finite real scalar.> ...
%! stl.read ('a.stl', 'Tolerance', -1)
%!error<stl.read: FILE is not a readable STL file.> ...
%! stl.read ([tempname(), '.stl'])
%!error<stl.read: FILE is not a readable STL file.>
%! f = [tempname(), '.stl'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "not an STL file\n");
%! fclose (fid);
%! unwind_protect
%!   stl.read (f);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect
%!error<stl.read: FILE is not a readable STL file.>
%! f = [tempname(), '.stl'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "solid x\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\n");
%! fprintf (fid, "vertex 1 0\nendloop\nendfacet\nendsolid x\n");
%! fclose (fid);
%! unwind_protect
%!   stl.read (f);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect
