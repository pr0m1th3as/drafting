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
## @deftypefn  {drafting} {@var{M} =} polymesh.read (@var{FILE})
## @deftypefnx {drafting} {@var{M} =} polymesh.read (@var{FILE}, @qcode{'Tolerance'}, @var{T})
##
## Read a triangle mesh from an STL, OBJ, PLY or 3MF file.
##
## @code{@var{M} = polymesh.read (@var{FILE})} reads the mesh in @var{FILE}
## and returns it as a @code{polymesh.Mesh}, with the colours of its
## vertices or faces where the file has them.  The extension of @var{FILE}
## names the format, @file{.stl}, @file{.obj}, @file{.ply} or @file{.3mf},
## in any case.
##
## @itemize
## @item
## An STL file is binary or ASCII.  It is binary when it is exactly as long
## as the number of triangles it declares makes it, and anything else is
## read as ASCII, the three numbers after each @qcode{vertex}, whatever the
## case and spacing.  It has no colours.
##
## @item
## An OBJ file is text.  Its @qcode{v} lines give the vertices, by their
## first three numbers, and their colours by the next three where they have
## them; its @qcode{f} lines give the faces, by the index of each corner's
## vertex, counted from 1, or back from the last vertex so far when it is
## below 0.  A face takes the colour @qcode{Kd} of the material its
## @qcode{usemtl} names, from the libraries its @qcode{mtllib} lines name,
## read from the folder of @var{FILE}.  Texture and normal indices after a
## slash are ignored, as is every other line, and so are textures.
##
## @item
## A PLY file is ASCII or binary, in either byte order.  The vertices are
## the properties @qcode{x}, @qcode{y} and @qcode{z} of the element
## @qcode{vertex}, and the faces the list @qcode{vertex_indices}, or
## @qcode{vertex_index}, of the element @qcode{face}, counted from 0.  The
## properties @qcode{red}, @qcode{green} and @qcode{blue} of either element
## are its colours: an integer type from 0 to its largest value, as the
## common @qcode{uchar} from 0 to 255, a float from 0 to 1.  Every other
## element and property is read past, @qcode{alpha} among them.
##
## @item
## A 3MF file is the archive slicers write, its parts stored or deflated.
## The mesh is every item of its build, each object placed where its
## transform puts it, the objects it is made of placed in turn, those in
## other model parts of the archive included, in millimetres whatever unit
## the file declares.  A triangle takes the colour its property names, or
## else its object's, from base materials or a colour group; textures and
## the other kinds of property are passed over.
## @end itemize
##
## A face of more than three corners, which OBJ and PLY allow, is cut into
## triangles turned the way the face is, each taking the colour of the
## face.  It is cut in the plane it lies nearest, so a concave face is cut
## inside its outline; a face that crosses itself is cut as a fan from one
## corner.
##
## Points that are equal are welded into one vertex, shared by every
## triangle that meets there, and a triangle two of whose corners become one
## is dropped.  That is what joins the triangles of an STL file, which
## repeats every corner for every triangle that has it.  A vertex welded
## from several of the file's vertices takes the mean of their colours.
## The vertices come in the order the triangles first use them, and a
## vertex that no face uses is left out.  The coordinates are taken as they
## are written; none of the three formats has units, and most files are in
## millimetres.  A file with vertices but no faces, such as a point cloud,
## is an error.
##
## A file that colours only some of its vertices, or only some of its faces,
## gives the rest the grey @code{[0.72, 0.74, 0.78]} that an uncoloured mesh
## is shown in.  An OBJ file whose material library is missing is read
## without face colours, and a material missing from its library leaves the
## faces that use it grey; each is a warning.  A colour outside 0 to 1 is
## an error.
##
## @code{@var{M} = polymesh.read (@var{FILE}, @qcode{'Tolerance'}, @var{T})}
## welds points that lie within @var{T} of one another, not only those that
## are equal, which closes the hairline gaps some programs leave in a mesh.
## The default @var{T} is 0.
##
## @seealso{polymesh.Mesh, polymesh.Mesh.write, solid.polyhedron}
## @end deftypefn

function M = read (FILE, varargin)

  ## Input validation
  if (nargin < 1)
    error ("polymesh.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE))
    error ("polymesh.read: FILE must be a character vector.");
  endif
  [~, ~, ext] = fileparts (FILE);
  fmt = lower (ext);
  if (! any (strcmp (fmt, {'.stl', '.obj', '.ply', '.3mf'})))
    error ("polymesh.read: FILE must end in .stl, .obj, .ply or .3mf.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("polymesh.read: Name/Value arguments must come in pairs.");
  endif
  T = 0;
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("polymesh.read: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'tolerance'
        T = val;
        if (! isnumeric (T) || ! isreal (T) || ! isscalar (T)
            || ! isfinite (T) || T < 0)
          error (strcat ("polymesh.read: Tolerance must be a non-negative", ...
                         " finite real scalar."));
        endif
      otherwise
        error ("polymesh.read: unknown option '%s'.", name);
    endswitch
  endfor
  if (! isfile (FILE))
    error ("polymesh.read: FILE is not a readable %s file.", ...
           upper (fmt(2:end)));
  endif

  [V, F, VC, FC] = __mesh__ ('read', 'polymesh.read', FILE, double (T), ...
                             fmt(2:end));
  M = polymesh.Mesh (V, F, 'VertexColour', VC, 'FaceColour', FC);

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
%!  n = rows (V) / 3;
%!  fwrite (fid, n, 'uint32');
%!  C = typecast (single (reshape (V', [], 1)), 'uint8');
%!  fwrite (fid, [zeros(12, n, 'uint8'); reshape(C, 36, n); ...
%!                zeros(2, n, 'uint8')]);
%!  fclose (fid);
%!endfunction

%!test  # binary: the corners welded into eight vertices
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   writebinary (f, cube ());
%!   M = polymesh.read (f);
%!   assert_equal (size (M.Vertices), [8, 3]);
%!   assert_equal (size (M.Faces), [12, 3]);
%!   assert_equal (sortrows (M.Vertices), [0, 0, 0; 0, 0, 1; 0, 1, 0; ...
%!                 0, 1, 1; 1, 0, 0; 1, 0, 1; 1, 1, 0; 1, 1, 1]);
%!   V = cube ();
%!   assert_equal (M.Vertices(M.Faces',:), V);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # ASCII, whatever the case and the spacing
%! f = [tempname(), '.STL'];
%! unwind_protect
%!   V = cube ();
%!   fid = fopen (f, 'w');
%!   fprintf (fid, "solid  cube\n");
%!   fprintf (fid, ["  facet  NORMAL 0 0 0\n   outer loop\n", ...
%!                  repmat("\tVertex %g %g %g\n", 1, 3), ...
%!                  "   endloop\n  endfacet\n"], reshape (V', 9, []));
%!   fprintf (fid, "endsolid cube\n");
%!   fclose (fid);
%!   M = polymesh.read (f);
%!   assert_equal (size (M.Vertices), [8, 3]);
%!   assert_equal (M.Vertices(M.Faces',:), V);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # a corner a hair away, welded within a tolerance
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   V = cube ();
%!   V(end,:) += 1e-7;
%!   writebinary (f, V);
%!   M = polymesh.read (f);
%!   assert_equal (rows (M.Vertices), 9);
%!   M = polymesh.read (f, 'Tolerance', 1e-5);
%!   assert_equal (rows (M.Vertices), 8);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # a triangle that collapses is dropped; an empty file is empty
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   writebinary (f, [cube(); 0, 0, 0; 0, 0, 0; 1, 1, 1]);
%!   M = polymesh.read (f);
%!   assert_equal (rows (M.Faces), 12);
%!   writebinary (f, zeros (0, 3));
%!   M = polymesh.read (f);
%!   assert_equal (size (M.Vertices), [0, 3]);
%!   assert_equal (size (M.Faces), [0, 3]);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

## The unit cube's corners and its six faces as quadrilaterals turned
## outwards, the mesh read from text written to a file with extension EXT,
## its signed volume, the bytes of X as TYPE, big-endian, a column for each
## value, and the signed areas of a planar mesh's triangles
%!function [P, Q] = quadcube ()
%!  P = [0, 0, 0; 1, 0, 0; 1, 1, 0; 0, 1, 0; ...
%!       0, 0, 1; 1, 0, 1; 1, 1, 1; 0, 1, 1];
%!  Q = [1, 4, 3, 2; 5, 6, 7, 8; 1, 2, 6, 5; ...
%!       2, 3, 7, 6; 3, 4, 8, 7; 4, 1, 5, 8];
%!endfunction
%!function M = readtext (ext, str)
%!  f = [tempname(), ext];
%!  fid = fopen (f, 'w');
%!  fputs (fid, str);
%!  fclose (fid);
%!  unwind_protect
%!    M = polymesh.read (f);
%!  unwind_protect_cleanup
%!    delete (f);
%!  end_unwind_protect
%!endfunction
%!function v = signedvolume (M)
%!  V = M.Vertices;
%!  F = M.Faces;
%!  v = sum (dot (V(F(:,1),:), cross (V(F(:,2),:), V(F(:,3),:), 2), 2)) / 6;
%!endfunction
%!function b = bebytes (x, type)
%!  b = typecast (cast (x(:)', type), 'uint8');
%!  b = flipud (reshape (b, [], numel (x)));
%!endfunction
%!function a = triareas (M)
%!  V = M.Vertices;
%!  F = M.Faces;
%!  e = cross (V(F(:,2),:) - V(F(:,1),:), V(F(:,3),:) - V(F(:,1),:), 2);
%!  a = e(:,3) / 2;
%!endfunction

%!test  # OBJ: quadrilaterals cut into triangles turned as they are
%! [P, Q] = quadcube ();
%! M = readtext ('.obj', [sprintf("v %d %d %d\n", P'), ...
%!                        sprintf("f %d %d %d %d\n", Q')]);
%! assert_equal (size (M.Vertices), [8, 3]);
%! assert_equal (size (M.Faces), [12, 3]);
%! assert_equal (signedvolume (M), 1);

%!test  # OBJ: texture and normal indices and other lines ignored
%! [P, Q] = quadcube ();
%! M = readtext ('.OBJ', ["o cube\n", sprintf("v %d %d %d 1\n", P'), ...
%!                        "vt 0 0\nvn 0 0 1\ng side\ns off\n", ...
%!                        sprintf("f %d/1/1 %d/2/1 %d/3/1 %d/4/1\n", ...
%!                                Q(1:2,:)'), ...
%!                        sprintf("f %d//1 %d//1 %d//1 %d//1\n", Q(3:4,:)'), ...
%!                        sprintf("f %d/1 %d/1 %d/1 %d/1\n", Q(5:6,:)')]);
%! assert_equal (signedvolume (M), 1);

%!test  # OBJ: an index below 0 counts back from the last vertex
%! [P, Q] = quadcube ();
%! M = readtext ('.obj', [sprintf("v %d %d %d\n", P'), ...
%!                        sprintf("f %d %d %d %d\n", Q' - 9)]);
%! assert_equal (signedvolume (M), 1);

%!test  # OBJ: comments, and a backslash joining two lines
%! M = readtext ('.obj', ["# a triangle\nv 0 0 0 # origin\nv 1 0 \\\n0\n", ...
%!                        "v 0 1 0\nf 1 \\\r\n2 3\n"]);
%! assert_equal (M.Vertices, [0, 0, 0; 1, 0, 0; 0, 1, 0]);
%! assert_equal (M.Faces, [1, 2, 3]);

%!test  # a concave quadrilateral is cut inside its outline
%! M = readtext ('.obj', "v 2 0 0\nv 1 0.5 0\nv 0 2 0\nv 0 0 0\nf 1 2 3 4\n");
%! assert_equal (all (triareas (M) > 0), true);
%! assert_equal (sum (triareas (M)), 1.5);

%!test  # a concave hexagon is cut into four triangles inside it
%! M = readtext ('.obj', ["v 0 0 0\nv 2 0 0\nv 2 1 0\nv 1 1 0\nv 1 2 0\n", ...
%!                        "v 0 2 0\nf 1 2 3 4 5 6\n"]);
%! assert_equal (rows (M.Faces), 4);
%! assert_equal (all (triareas (M) > 0), true);
%! assert_equal (sum (triareas (M)), 3);

%!test  # PLY ASCII: other properties and elements read past
%! [P, Q] = quadcube ();
%! M = readtext ('.ply', ["ply\r\nformat ascii 1.0\r\ncomment a cube\r\n", ...
%!                        "element vertex 8\r\nproperty float x\r\n", ...
%!                        "property float y\r\nproperty uchar red\r\n", ...
%!                        "property float z\r\nelement face 6\r\n", ...
%!                        "property list uchar int vertex_indices\r\n", ...
%!                        "property float quality\r\nelement edge 1\r\n", ...
%!                        "property int vertex1\r\n", ...
%!                        "property int vertex2\r\n", ...
%!                        "end_header\r\n", ...
%!                        sprintf("%d %d 255 %d\r\n", P'), ...
%!                        sprintf("4 %d %d %d %d 0.5\r\n", Q' - 1), "0 1\r\n"]);
%! assert_equal (size (M.Vertices), [8, 3]);
%! assert_equal (signedvolume (M), 1);

%!test  # PLY binary, little-endian
%! [P, Q] = quadcube ();
%! f = [tempname(), '.ply'];
%! unwind_protect
%!   fid = fopen (f, 'w', 'ieee-le');
%!   fputs (fid, ["ply\nformat binary_little_endian 1.0\n", ...
%!                "element vertex 8\nproperty float x\nproperty float y\n", ...
%!                "property float z\nelement face 6\n", ...
%!                "property list uchar int vertex_indices\nend_header\n"]);
%!   fwrite (fid, P', 'float32');
%!   fwrite (fid, [repmat(uint8 (4), 1, 6); ...
%!                 reshape(flipud (bebytes (Q' - 1, 'int32')), 16, 6)]);
%!   fclose (fid);
%!   assert_equal (signedvolume (polymesh.read (f)), 1);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # PLY binary, big-endian, other types and the name vertex_index
%! [P, Q] = quadcube ();
%! f = [tempname(), '.ply'];
%! unwind_protect
%!   fid = fopen (f, 'w', 'ieee-be');
%!   fputs (fid, ["ply\nformat binary_big_endian 1.0\nelement vertex 8\n", ...
%!                "property double x\nproperty short n\n", ...
%!                "property double y\n", ...
%!                "property double z\nelement face 6\n", ...
%!                "property list ushort uint vertex_index\nend_header\n"]);
%!   fwrite (fid, [bebytes(P(:,1), 'double'); bebytes(-ones (8, 1), 'int16');
%!                 bebytes(P(:,2), 'double'); bebytes(P(:,3), 'double')]);
%!   fwrite (fid, [bebytes(4 * ones (6, 1), 'uint16');
%!                 reshape(bebytes (Q' - 1, 'uint32'), 16, 6)]);
%!   fclose (fid);
%!   assert_equal (signedvolume (polymesh.read (f)), 1);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect

%!test  # an empty OBJ or PLY file is an empty mesh
%! M = readtext ('.obj', "# nothing\n");
%! assert_equal (size (M.Vertices), [0, 3]);
%! assert_equal (size (M.Faces), [0, 3]);
%! M = readtext ('.ply', "ply\nformat ascii 1.0\nend_header\n");
%! assert_equal (size (M.Faces), [0, 3]);

## An OBJ file read with a material library MTL beside it, the OBJ naming
## it first; the PLY header of NV vertices and NF faces, each with the
## properties PV and PF after the usual ones
%!function M = readwithmtl (obj, mtl)
%!  f = [tempname(), '.obj'];
%!  l = [tempname(), '.mtl'];
%!  [~, name, ext] = fileparts (l);
%!  unwind_protect
%!    fid = fopen (l, 'w');
%!    fputs (fid, mtl);
%!    fclose (fid);
%!    fid = fopen (f, 'w');
%!    fputs (fid, ["mtllib ", name, ext, "\n", obj]);
%!    fclose (fid);
%!    M = polymesh.read (f);
%!  unwind_protect_cleanup
%!    delete (f);
%!    delete (l);
%!  end_unwind_protect
%!endfunction
%!function h = unitply (nv, nf, pv, pf)
%!  h = sprintf (["ply\nformat ascii 1.0\nelement vertex %d\n", ...
%!                "property float x\nproperty float y\nproperty float z\n", ...
%!                "%selement face %d\n", ...
%!                "property list uchar int vertex_indices\n%send_header\n"], ...
%!               nv, pv, nf, pf);
%!endfunction

%!test  # OBJ vertex colours, in the order the faces first use the vertices
%! M = readtext ('.obj', ["v 0 0 0 1 0 0\nv 1 0 0 0 1 0\nv 0 1 0 0 0 0.5\n", ...
%!                        "f 3 1 2\n"]);
%! assert_equal (M.VertexColour, [0, 0, 0.5; 1, 0, 0; 0, 1, 0]);
%! assert_equal (M.FaceColour, []);

%!test  # OBJ: a vertex without a colour in a coloured file is grey
%! M = readtext ('.obj', "v 0 0 0 1 0 0\nv 1 0 0\nv 0 1 0 1\nf 1 2 3\n");
%! assert_equal (M.VertexColour, [1, 0, 0; 0.72, 0.74, 0.78; 0.72, 0.74, 0.78]);

%!test  # OBJ: points welded into one vertex take the mean of their colours
%! M = readtext ('.obj', ["v 0 0 0 1 0 0\nv 1 0 0 0 0 0\nv 0 1 0 0 0 0\n", ...
%!                        "v 0 0 0 0 1 0\nv 0 0 1 0 0 0\nf 1 2 3\nf 4 3 5\n"]);
%! assert_equal (numvertices (M), 4);
%! assert_equal (M.VertexColour(1,:), [0.5, 0.5, 0]);

%!test  # OBJ face colours from materials; a quadrilateral's two triangles
%! M = readwithmtl (["v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nv 0 0 1\n", ...
%!                   "f 1 2 5\nusemtl red\nf 1 2 3 4\nusemtl blue\n", ...
%!                   "f 2 3 5\n"], ...
%!                  ["newmtl red\nKa 0 0 0\nKd 1 0 0\n", ...
%!                   "newmtl blue\nKd 0 0 1\n"]);
%! assert_equal (M.FaceColour, [0.72, 0.74, 0.78; 1, 0, 0; 1, 0, 0; 0, 0, 1]);

%!warning<polymesh.read: FILE uses the material green, which its library does not have, so its faces are grey.> ...
%! M = readwithmtl ("v 0 0 0\nv 1 0 0\nv 0 1 0\nusemtl green\nf 1 2 3\n", ...
%!                  "newmtl red\nKd 1 0 0\n");
%! assert_equal (M.FaceColour, [0.72, 0.74, 0.78]);

%!warning<polymesh.read: the material library of FILE is missing, so its faces have no colour.> ...
%! M = readtext ('.obj', ["mtllib nowhere.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\n", ...
%!                        "usemtl red\nf 1 2 3\n"]);
%! assert_equal (M.FaceColour, []);

%!test  # PLY colours on vertices, uchar from 0 to 255
%! M = readtext ('.ply', [unitply(3, 1, ["property uchar red\n", ...
%!                                       "property uchar green\n", ...
%!                                       "property uchar blue\n"], ""), ...
%!                        "0 0 0 255 0 0\n1 0 0 0 51 0\n0 1 0 0 0 0\n", ...
%!                        "3 0 1 2\n"]);
%! assert_equal (M.VertexColour, [1, 0, 0; 0, 0.2, 0; 0, 0, 0]);

%!test  # PLY colours on faces, floats from 0 to 1, a quadrilateral's two
%! M = readtext ('.ply', [unitply(4, 1, "", ["property float red\n", ...
%!                                           "property float green\n", ...
%!                                           "property float blue\n"]), ...
%!                        "0 0 0\n1 0 0\n1 1 0\n0 1 0\n", ...
%!                        "4 0 1 2 3 0.25 0.5 1\n"]);
%! assert_equal (M.FaceColour, [0.25, 0.5, 1; 0.25, 0.5, 1]);
%! assert_equal (M.VertexColour, []);

## A file NAME of the text TEXT under the folder D; a 3MF package of the
## model MODEL and the other parts EXTRA, pairs of a name and its text,
## zipped; and a tetrahedron object with the identity ID
## and the attributes ATTR, its triangles each with TRI after its corners
%!function putpart (d, name, text)
%!  folder = fileparts (fullfile (d, name));
%!  if (! isfolder (folder))
%!    mkdir (folder);
%!  endif
%!  fid = fopen (fullfile (d, name), 'w');
%!  fputs (fid, text);
%!  fclose (fid);
%!endfunction
%!function f = pack3mf (model, extra)
%!  d = tempname ();
%!  ct = ['<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://', ...
%!        'schemas.openxmlformats.org/package/2006/content-types">', ...
%!        '<Default Extension="rels" ContentType="application/', ...
%!        'vnd.openxmlformats-', ...
%!        'package.relationships+xml"/><Default Extension="model" ', ...
%!        'ContentType="application/vnd.ms-package.3dmanufacturing-', ...
%!        '3dmodel+xml"/></Types>'];
%!  rels = ['<?xml version="1.0" encoding="UTF-8"?><Relationships ', ...
%!          'xmlns="http://schemas.openxmlformats.org/package/2006/', ...
%!          'relationships"><Relationship Target="/3D/3dmodel.model" ', ...
%!          'Id="rel0" Type="http://schemas.microsoft.com/', ...
%!          '3dmanufacturing/2013/01/3dmodel"/>', ...
%!          '</Relationships>'];
%!  names = [{'[Content_Types].xml', '_rels/.rels', '3D/3dmodel.model'}, ...
%!           extra(1:2:end)];
%!  texts = [{ct, rels, model}, extra(2:2:end)];
%!  mkdir (d);
%!  cellfun (@(n, t) putpart (d, n, t), names, texts);
%!  f = [tempname(), '.3mf'];
%!  zip (f, names, d);
%!  confirm_recursive_rmdir (false, 'local');
%!  rmdir (d, 's');
%!endfunction
%!function o = tetra3mf (id, attr, tri)
%!  o = sprintf (['<object id="%d" type="model"%s><mesh><vertices>', ...
%!                '<vertex x="0" y="0" z="0"/><vertex x="1" y="0" z="0"/>', ...
%!                '<vertex x="0" y="1" z="0"/><vertex x="0" y="0" z="1"/>', ...
%!                '</vertices><triangles>', ...
%!                '<triangle v1="0" v2="2" v3="1"%s/>', ...
%!                '<triangle v1="0" v2="1" v3="3"%s/>', ...
%!                '<triangle v1="1" v2="2" v3="3"%s/>', ...
%!                '<triangle v1="2" v2="0" v3="3"%s/>', ...
%!                '</triangles></mesh></object>'], ...
%!               id, attr, tri, tri, tri, tri);
%!endfunction

%!test  # 3MF as polymesh.Mesh writes it, back exactly, colours to 1/255
%! V = [0.1, 0.2, 0.3; pi, 0.2, 0.3; 0.1, exp(1), 0.3; 0.1, 0.2, 1/3];
%! M = polymesh.Mesh (V, [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4], ...
%!                    'FaceColour', [1, 0, 0; 1, 0, 0; 0, 0, 1; 0.2, 0.4, 0.6]);
%! f = [tempname(), '.3mf'];
%! unwind_protect
%!   write (M, f);
%!   R = polymesh.read (f);
%!   assert_equal (R.Vertices(R.Faces',:), M.Vertices(M.Faces',:));
%!   assert_equal (R.FaceColour, M.FaceColour, 0.5 / 255);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: a component placed twice, by its transform and the item's
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources>', tetra3mf(1, '', ''), ...
%!      '<object id="2" type="model"><components>', ...
%!      '<component objectid="1"/>', ...
%!      '<component objectid="1" transform="0 1 0 -1 0 0 0 0 1 10 0 0"/>', ...
%!      '</components></object></resources><build>', ...
%!      '<item objectid="2" transform="1 0 0 0 1 0 0 0 1 0 0 5"/>', ...
%!      '</build></model>'];
%! f = pack3mf (m, {});
%! unwind_protect
%!   M = polymesh.read (f);
%!   assert_equal (numfaces (M), 8);
%!   assert_equal ([min(M.Vertices); max(M.Vertices)], [0, 0, 5; 10, 1, 6]);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: a model in centimetres comes back in millimetres
%! m = ['<model unit="centimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources>', tetra3mf(1, '', ''), ...
%!      '</resources><build><item objectid="1"/></build></model>'];
%! f = pack3mf (m, {});
%! unwind_protect
%!   M = polymesh.read (f);
%!   assert_equal (max (M.Vertices), [10, 10, 10]);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: colours of a colour group, the object's and a triangle's own
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02" xmlns:m="http://schemas.microsoft.', ...
%!      'com/3dmanufacturing/material/2015/02"><resources>', ...
%!      '<m:colorgroup id="5"><m:color color="#FF0000"/>', ...
%!      '<m:color color="#0000FFFF"/></m:colorgroup>', ...
%!      tetra3mf(1, ' pid="5" pindex="0"', ''), ...
%!      '</resources><build><item objectid="1"/></build></model>'];
%! m = strrep (m, '<triangle v1="1" v2="2" v3="3"/>', ...
%!             '<triangle v1="1" v2="2" v3="3" pid="5" p1="1"/>');
%! f = pack3mf (m, {});
%! unwind_protect
%!   M = polymesh.read (f);
%!   assert_equal (sortrows (M.FaceColour), ...
%!                 [0, 0, 1; 1, 0, 0; 1, 0, 0; 1, 0, 0]);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## 3MF: a component in another model part of the archive
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02" xmlns:p="http://schemas.microsoft.', ...
%!      'com/3dmanufacturing/production/2015/06"><resources>', ...
%!      '<object id="2" type="model"><components>', ...
%!      '<component p:path="/3D/Objects/part.model" objectid="1"/>', ...
%!      '</components></object></resources><build>', ...
%!      '<item objectid="2"/></build></model>'];
%! o = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources>', tetra3mf(1, '', ''), ...
%!      '</resources><build/></model>'];
%! f = pack3mf (m, {'3D/Objects/part.model', o});
%! unwind_protect
%!   M = polymesh.read (f);
%!   assert_equal (numfaces (M), 4);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!error<polymesh.read: invalid number of input arguments.> polymesh.read ()
%!error<polymesh.read: Name/Value arguments must come in pairs.> ...
%! polymesh.read ('a.stl', 1)
%!error<polymesh.read: FILE must be a character vector.> polymesh.read (1)
%!error<polymesh.read: FILE must end in .stl, .obj, .ply or .3mf.> ...
%! polymesh.read ('part.step')
%!error<polymesh.read: unknown option 'Weld'.> polymesh.read ('a.stl', 'Weld', 1)
%!error<polymesh.read: option names must be character vectors.> polymesh.read ('a.stl', 1, 1)
%!test  # option names ignore case
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   write (solid.box (1, 1, 1), f);
%!   M1 = polymesh.read (f, 'tolerance', 0.1);
%!   M2 = polymesh.read (f, 'Tolerance', 0.1);
%!   assert_equal (M1.Vertices, M2.Vertices);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect
%!error<polymesh.read: Tolerance must be a non-negative finite real scalar.> ...
%! polymesh.read ('a.stl', 'Tolerance', -1)
%!error<polymesh.read: FILE is not a readable STL file.> ...
%! polymesh.read ([tempname(), '.stl'])
%!error<polymesh.read: FILE is not a readable STL file.>
%! f = [tempname(), '.stl'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "not an STL file\n");
%! fclose (fid);
%! unwind_protect
%!   polymesh.read (f);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect
%!error<polymesh.read: FILE is not a readable STL file.>
%! f = [tempname(), '.stl'];
%! fid = fopen (f, 'w');
%! fprintf (fid, "solid x\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\n");
%! fprintf (fid, "vertex 1 0\nendloop\nendfacet\nendsolid x\n");
%! fclose (fid);
%! unwind_protect
%!   polymesh.read (f);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect
%!error<polymesh.read: FILE is not a readable OBJ file.> ...
%! polymesh.read ([tempname(), '.obj'])
%!error<polymesh.read: FILE is not a readable OBJ file.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0\n")
%!error<polymesh.read: FILE is not a readable OBJ file.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nf 1 2\n")
%!error<polymesh.read: FILE is not a readable OBJ file.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 0 1 2\n")
%!error<polymesh.read: FILE is not a readable OBJ file.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2x 3\n")
%!error<polymesh.read: a face of FILE refers to a vertex the file does not have.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 4\n")
%!error<polymesh.read: a face of FILE refers to a vertex the file does not have.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nf 1 2 -3\nv 0 1 0\n")
%!error<polymesh.read: FILE has vertices but no faces.> ...
%! readtext ('.obj', "v 0 0 0\nv 1 0 0\nv 0 1 0\nl 1 2\n")
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', "format ascii 1.0\nend_header\n")
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', "ply\nformat ascii 1.0\nelement vertex 1\n")
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', "ply\nformat binary 1.0\nend_header\n")
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 1\n", ...
%!                    "property long x\nend_header\n0\n"])
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 1\n", ...
%!                    "property float x\nproperty float y\nend_header\n0 0\n"])
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 2\n", ...
%!                    "property float x\nproperty float y\n", ...
%!                    "property float z\nend_header\n0 0 0\n"])
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', ["ply\nformat binary_little_endian 1.0\n", ...
%!                    "element vertex 1\nproperty float x\n", ...
%!                    "property float y\nproperty float z\n", ...
%!                    "end_header\nabcdefgh"])
%!error<polymesh.read: FILE is not a readable PLY file.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 3\n", ...
%!                    "property float x\nproperty float y\n", ...
%!                    "property float z\nelement face 1\n", ...
%!                    "property list uchar int vertex_indices\n", ...
%!                    "end_header\n", ...
%!                    "0 0 0\n1 0 0\n0 1 0\n2 0 1\n"])
%!error<polymesh.read: a face of FILE refers to a vertex the file does not have.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 3\n", ...
%!                    "property float x\nproperty float y\n", ...
%!                    "property float z\nelement face 1\n", ...
%!                    "property list uchar int vertex_indices\n", ...
%!                    "end_header\n", ...
%!                    "0 0 0\n1 0 0\n0 1 0\n3 0 1 3\n"])
%!error<polymesh.read: FILE has vertices but no faces.> ...
%! readtext ('.ply', ["ply\nformat ascii 1.0\nelement vertex 1\n", ...
%!                    "property float x\nproperty float y\n", ...
%!                    "property float z\nend_header\n0 0 0\n"])
%!error<polymesh.read: a colour in FILE is outside 0 to 1.> ...
%! readtext ('.obj', "v 0 0 0 255 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n")
%!error<polymesh.read: a colour in FILE is outside 0 to 1.> ...
%! readwithmtl ("v 0 0 0\nv 1 0 0\nv 0 1 0\nusemtl red\nf 1 2 3\n", ...
%!              "newmtl red\nKd 2 0 0\n")
%!error<polymesh.read: a colour in FILE is outside 0 to 1.> ...
%! readtext ('.ply', [unitply(3, 1, "", ["property float red\n", ...
%!                                       "property float green\n", ...
%!                                       "property float blue\n"]), ...
%!                    "0 0 0\n1 0 0\n0 1 0\n3 0 1 2 1.5 0 0\n"])
%!error<polymesh.read: FILE is not a readable 3MF file.> ...
%! readtext ('.3mf', "not a zip archive\n")
%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'zip')) || ! isempty (file_in_path (getenv ('PATH'), 'zip.exe'))
%! ## a missing object is not a readable 3MF file
%! m = ['<model unit="millimeter" xmlns="http://schemas.microsoft.com/', ...
%!      '3dmanufacturing/core/2015/02"><resources></resources><build>', ...
%!      '<item objectid="7"/></build></model>'];
%! f = pack3mf (m, {});
%! unwind_protect
%!   msg = '';
%!   try
%!     polymesh.read (f);
%!   catch err
%!     msg = err.message;
%!   end_try_catch
%!   assert_equal (msg, "polymesh.read: FILE is not a readable 3MF file.");
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect
