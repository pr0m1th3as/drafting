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
## @deftypefn  {drafting} {} stl.write (@var{FILE}, @var{S})
## @deftypefnx {drafting} {} stl.write (@var{FILE}, @var{P}, @var{Z})
## @deftypefnx {drafting} {@var{N} =} stl.write (@dots{})
##
## Write a section stack to a binary STL file.
##
## @code{stl.write (@var{FILE}, @var{S})} writes the solid described by the
## struct array @var{S} to @var{FILE} as a binary STL.  Each element of @var{S}
## is one prismatic section, with fields:
##
## @multitable @columnfractions 0.16 0.84
## @item @code{profile} @tab an @math{N}-by-2 outline, in the units of the model
## @item @code{z} @tab the two-element range @code{[@var{z0}, @var{z1}]} the
## outline is swept through
## @item @code{holes} @tab optional cell array of outlines to exclude
## @end multitable
##
## @code{stl.write (@var{FILE}, @var{P}, @var{Z})} is the single-section form,
## equivalent to one element with no holes.
##
## @code{@var{N} = stl.write (@dots{})} returns the number of triangles written.
##
## @subheading Why a stack of sections
##
## A single extrusion covers a plate, a disc or a flange, but not a part whose
## cross-section changes along its axis --- a stepped shaft, or one carrying an
## eccentric journal offset from the centreline.  A stack expresses those
## without leaving the planar model: every section is still a 2-D outline, and
## only its @math{z} range and its position change.
##
## The sections need not be concentric, contiguous or the same size.  Nothing
## requires them to touch.
##
## @subheading What is and is not watertight
##
## Each section is written as its own closed shell: side walls for the outline
## and for every hole, and a cap at each end.  A single-section solid is
## therefore a closed manifold, which covers a cycloidal disc, a ring or an
## output flange.
##
## A stack of several is @strong{not} one manifold shell.  Where two sections
## abut, both keep their own caps, so the interior face is present twice and the
## edges do not join.  Slicers and mesh-repair tools resolve this by unioning
## the shells and it prints correctly; a tool demanding a single closed surface
## will complain.  Producing the stepped annular cap that would join them is a
## harder problem and is not attempted here.
##
## @subheading Winding and normals
##
## Outlines are normalised before use: the profile is made counter-clockwise and
## every hole clockwise, so that one rule generates outward normals for both.
## The caller's winding is therefore irrelevant.  Normals are computed per facet
## from the vertices rather than stored independently, so they cannot disagree
## with the geometry they describe.
##
## Caps come from @code{geom.triangulate}, which is unconstrained, so a strongly
## concave outline may be capped slightly short.  Its @var{COVERAGE} output
## measures that, and dense sampling makes it negligible.
##
## @subheading Precision
##
## STL stores every coordinate as a 32-bit float, so about seven significant
## figures survive whatever the model carried.  On a part tens of millimetres
## across that is a resolution of a few microns, which is ample for a printed
## prototype and is @emph{not} the format to send a machinist: use
## @code{dxf.write} for anything dimensionally critical.
##
## @seealso{geom.triangulate, dxf.write, draw.Drawing}
## @end deftypefn

function N = write (FILE, varargin)

  ## Input validation
  if (nargin < 2 || nargin > 3)
    error ("stl.write: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE))
    error ("stl.write: FILE must be a character vector.");
  endif

  if (nargin == 3)
    S = struct ('profile', varargin{1}, 'z', varargin{2});
  else
    S = varargin{1};
    if (! isstruct (S) || isempty (S))
      error ("stl.write: S must be a non-empty struct array of sections.");
    endif
    if (! isfield (S, 'profile') || ! isfield (S, 'z'))
      error ("stl.write: each section needs a 'profile' and a 'z' range.");
    endif
  endif

  tri = zeros (0, 9);
  for k = 1:numel (S)
    [errmsg, P] = geom.__checkpoly__ (S(k).profile);
    if (! isempty (errmsg))
      error ("stl.write: section %d: %s", k, errmsg);
    endif
    z = S(k).z;
    if (! isnumeric (z) || ! isreal (z) || numel (z) != 2 ...
        || ! all (isfinite (z)))
      error ("stl.write: section %d: z must be two real finite values.", k);
    endif
    if (z(2) <= z(1))
      error ("stl.write: section %d: z must be increasing.", k);
    endif

    H = {};
    if (isfield (S, 'holes') && ! isempty (S(k).holes))
      H = S(k).holes;
      if (! iscell (H))
        error ("stl.write: section %d: holes must be a cell array.", k);
      endif
      for j = 1:numel (H)
        [errmsg, H{j}] = geom.__checkpoly__ (H{j});
        if (! isempty (errmsg))
          error ("stl.write: section %d, hole %d: %s", k, j, errmsg);
        endif
      endfor
    endif

    ## One winding rule for everything: outline counter-clockwise, holes
    ## clockwise, so the same wall construction faces outward for both
    P = orient (P, 1);
    for j = 1:numel (H)
      H{j} = orient (H{j}, -1);
    endfor

    tri = [tri; walls(P, z)];
    for j = 1:numel (H)
      tri = [tri; walls(H{j}, z)];
    endfor
    tri = [tri; caps(P, H, z)];
  endfor

  ## Binary STL: 80-byte header, facet count, then 50 bytes per facet
  fid = fopen (FILE, 'wb');
  if (fid < 0)
    error ("stl.write: cannot open '%s' for writing.", FILE);
  endif
  unwind_protect
    stamp = "Generated by the drafting package: stl.write";
    pad = zeros (1, 80 - numel (stamp), 'uint8');
    fwrite (fid, [uint8(stamp), pad], 'uint8');
    fwrite (fid, rows (tri), 'uint32');
    for i = 1:rows (tri)
      v = reshape (tri(i,:), 3, 3)';
      n = cross (v(2,:) - v(1,:), v(3,:) - v(1,:));
      L = norm (n);
      if (L > 0)
        n /= L;
      endif
      fwrite (fid, single ([n, tri(i,:)]), 'float32');
      fwrite (fid, 0, 'uint16');
    endfor
  unwind_protect_cleanup
    fclose (fid);
  end_unwind_protect

  if (nargout > 0)
    N = rows (tri);
  endif

endfunction

## Force a polygon to the requested orientation: +1 counter-clockwise, -1 not
function P = orient (P, want)

  if (sign (geom.signedarea (P)) != want)
    P = flipud (P);
  endif

endfunction

## Side walls of one closed outline swept through z, two facets per edge
function T = walls (P, z)

  A = P;
  B = P([2:end, 1],:);
  n = rows (P);
  z0 = z(1) * ones (n, 1);
  z1 = z(2) * ones (n, 1);
  T = [A, z0, B, z0, B, z1; ...
       A, z0, B, z1, A, z1];

endfunction

## End caps, triangulated in plane and lifted to each end of the range
function T = caps (P, H, z)

  [F, V] = geom.triangulate (P, H);
  x = reshape (V(F,1), size (F));
  y = reshape (V(F,2), size (F));

  ## Counter-clockwise in plane, so the top cap faces +z and the bottom -z
  flip = ((x(:,2) - x(:,1)) .* (y(:,3) - y(:,1)) ...
          - (x(:,3) - x(:,1)) .* (y(:,2) - y(:,1))) < 0;
  x(flip,[2, 3]) = x(flip,[3, 2]);
  y(flip,[2, 3]) = y(flip,[3, 2]);

  n = rows (F);
  hi = z(2) * ones (n, 1);
  lo = z(1) * ones (n, 1);
  T = [x(:,1), y(:,1), hi, x(:,2), y(:,2), hi, x(:,3), y(:,3), hi; ...
       x(:,1), y(:,1), lo, x(:,3), y(:,3), lo, x(:,2), y(:,2), lo];

endfunction

%!demo
%! ## A profile becomes a printable solid by sweeping it through a z range.
%! ## Holes are given as a cell array and are cut right through.
%!
%! a = linspace (0, 2*pi, 65)(1:64)';
%! b = linspace (0, 2*pi, 33)(1:32)';
%! outer = 30 * [cos(a), sin(a)];
%! H = {8 * [cos(b), sin(b)]};
%! for k = 1:4
%!   c = 19 * [cos(2*pi*(k-1)/4), sin(2*pi*(k-1)/4)];
%!   H{end+1} = c + 4 * [cos(b), sin(b)];
%! endfor
%!
%! fn = [tempname(), '.stl'];
%! n = stl.write (fn, struct ('profile', outer, 'z', [0, 10], 'holes', {H}));
%! printf ('%d facets, %.1f kB\n', n, stat (fn).size / 1024);
%! unlink (fn);

%!demo
%! ## A section stack expresses a part whose cross-section changes along its
%! ## axis --- here a stepped shaft carrying a journal offset from the
%! ## centreline, which no single extrusion could describe.
%!
%! a = linspace (0, 2*pi, 49)(1:48)';
%! circ = @(r, c) c + r * [cos(a), sin(a)];
%! S(1) = struct ('profile', circ (8, [0, 0]),   'z', [0, 20],  'holes', {{}});
%! S(2) = struct ('profile', circ (14, [2, 0]),  'z', [20, 34], 'holes', {{}});
%! S(3) = struct ('profile', circ (8, [0, 0]),   'z', [34, 55], 'holes', {{}});
%!
%! fn = [tempname(), '.stl'];
%! printf ('%d facets in 3 sections\n', stl.write (fn, S));
%! unlink (fn);
%!
%! ## The sections seen end-on, which is what the stack describes
%! D = draw.Drawing ();
%! D = D.circle ([0, 0], 8);
%! D.Colour = 'red';
%! D = D.circle ([2, 0], 14);
%! draw.plot (D);
%! title ('the journal (red) is offset 2 mm from the shaft axis');

%!function [N, V] = readstl (fn)
%!  fid = fopen (fn, 'rb');
%!  fread (fid, 80, 'uint8');
%!  n = double (fread (fid, 1, 'uint32'));
%!  N = zeros (n, 3);  V = zeros (n, 9);
%!  for i = 1:n
%!    d = fread (fid, 12, 'float32');
%!    N(i,:) = d(1:3)';
%!    V(i,:) = d(4:12)';
%!    fread (fid, 1, 'uint16');
%!  endfor
%!  fclose (fid);
%!endfunction

%!function vol = meshvolume (V)
%!  a = V(:,1:3);  b = V(:,4:6);  c = V(:,7:9);
%!  vol = sum (dot (a, cross (b, c, 2), 2)) / 6;
%!endfunction

%!test  # a square prism is twelve triangles: eight walls, four caps
%! fn = [tempname(), '.stl'];
%! unwind_protect
%!   n = stl.write (fn, [0, 0; 10, 0; 10, 10; 0, 10], [0, 5]);
%!   assert_equal (n, 12);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # the file is the size the binary format dictates
%! fn = [tempname(), '.stl'];
%! unwind_protect
%!   n = stl.write (fn, [0, 0; 10, 0; 10, 10; 0, 10], [0, 5]);
%!   assert_equal (stat (fn).size, 84 + 50 * n);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # the facet count in the header matches what was written
%! fn = [tempname(), '.stl'];
%! unwind_protect
%!   n = stl.write (fn, [0, 0; 10, 0; 10, 10; 0, 10], [0, 5]);
%!   fid = fopen (fn, 'rb');
%!   fread (fid, 80, 'uint8');
%!   assert_equal (double (fread (fid, 1, 'uint32')), n);
%!   fclose (fid);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # every normal is a unit vector
%! fn = [tempname(), '.stl'];
%! unwind_protect
%!   n = stl.write (fn, [0, 0; 10, 0; 10, 10; 0, 10], [0, 5]);
%!   [N, V] = readstl (fn);
%!   assert_equal (sqrt (sum (N .^ 2, 2)), ones (n, 1), 1e-6);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # the mesh encloses the right volume, by the divergence theorem
%! fn = [tempname(), '.stl'];
%! unwind_protect
%!   stl.write (fn, [0, 0; 10, 0; 10, 10; 0, 10], [0, 5]);
%!   [N, V] = readstl (fn);
%!   assert_equal (meshvolume (V), 500, 1e-3);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # a hole is subtracted from the volume, not added.  The expected value
%!       # is the area of the sampled polygons, not of the circles they
%!       # approximate: a 128-gon is measurably smaller, and asserting the
%!       # circle would be testing the sampling rather than the mesh.
%! fn = [tempname(), '.stl'];
%! a = linspace (0, 2*pi, 129)(1:128)';
%! outer = 20 * [cos(a), sin(a)];
%! inner = 5 * [cos(a), sin(a)];
%! S = struct ('profile', outer, 'z', [0, 4], 'holes', {{inner}});
%! unwind_protect
%!   stl.write (fn, S);
%!   [N, V] = readstl (fn);
%!   want = 4 * (abs (geom.signedarea (outer)) - abs (geom.signedarea (inner)));
%!   ## STL stores coordinates as float32, so a round trip through the file
%!   ## costs about seven significant figures; the tolerance is the format's
%!   assert_equal (meshvolume (V), want, 1e-3);
%!   assert_equal (want < 4 * pi * (20^2 - 5^2), true);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # several holes of differing vertex counts all stack correctly
%! fn = [tempname(), '.stl'];
%! a = linspace (0, 2*pi, 33)(1:32)';
%! b = linspace (0, 2*pi, 17)(1:16)';
%! outer = 40 * [cos(a), sin(a)];
%! H = {8 * [cos(b), sin(b)]};
%! for k = 1:5
%!   c = 25 * [cos(2*pi*(k-1)/5), sin(2*pi*(k-1)/5)];
%!   H{end+1} = c + 4 * [cos(b), sin(b)];
%! endfor
%! S = struct ('profile', outer, 'z', [0, 3], 'holes', {H});
%! unwind_protect
%!   stl.write (fn, S);
%!   [N, V] = readstl (fn);
%!   want = abs (geom.signedarea (outer));
%!   for k = 1:numel (H)
%!     want -= abs (geom.signedarea (H{k}));
%!   endfor
%!   assert_equal (meshvolume (V), 3 * want, 1e-2);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # winding of the input does not matter
%! fn1 = [tempname(), '.stl'];  fn2 = [tempname(), '.stl'];
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! unwind_protect
%!   stl.write (fn1, P, [0, 5]);
%!   stl.write (fn2, flipud (P), [0, 5]);
%!   [~, V1] = readstl (fn1);
%!   [~, V2] = readstl (fn2);
%!   assert_equal (meshvolume (V1), meshvolume (V2), 1e-9);
%!   assert_equal (meshvolume (V1) > 0, true);
%! unwind_protect_cleanup
%!   unlink (fn1);  unlink (fn2);
%! end_unwind_protect

%!test  # a stack of sections sums its volumes
%! fn = [tempname(), '.stl'];
%! S(1) = struct ('profile', [0, 0; 10, 0; 10, 10; 0, 10], 'z', [0, 2]);
%! S(2) = struct ('profile', [2, 2; 8, 2; 8, 8; 2, 8], 'z', [2, 5]);
%! unwind_protect
%!   stl.write (fn, S);
%!   [N, V] = readstl (fn);
%!   assert_equal (meshvolume (V), 100 * 2 + 36 * 3, 1e-6);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # a section offset from the axis is placed where it was asked for
%! fn = [tempname(), '.stl'];
%! S(1) = struct ('profile', [0, 0; 10, 0; 10, 10; 0, 10], 'z', [0, 2]);
%! S(2) = struct ('profile', [20, 0; 24, 0; 24, 4; 20, 4], 'z', [2, 5]);
%! unwind_protect
%!   stl.write (fn, S);
%!   [N, V] = readstl (fn);
%!   assert_equal (max (V(:,1)), 24, 1e-6);
%!   assert_equal (meshvolume (V), 100 * 2 + 16 * 3, 1e-6);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<stl.write: invalid number of input arguments.> stl.write ('a.stl')
%!error<stl.write: FILE must be a character vector.> stl.write (42, [0,0;1,0;1,1], [0,1])
%!error<stl.write: section 1: z must be increasing.> ...
%! stl.write ('a.stl', [0,0;1,0;1,1], [1, 0])
%!error<stl.write: section 1: P must be a polygon with at least 3 vertices.> ...
%! stl.write ('a.stl', [0, 0; 1, 1], [0, 1])
%!error<stl.write: S must be a non-empty struct array of sections.> ...
%! stl.write ('a.stl', 42)
