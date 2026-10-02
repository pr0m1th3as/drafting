// Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
//
// This file is part of the drafting package for GNU Octave.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, see <http://www.gnu.org/licenses/>.

// Triangle meshes: reading STL files and cutting meshes with a plane.  It
// needs nothing but Octave, so the stl namespace works on any build.

#include <octave/oct.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <tuple>
#include <unordered_map>
#include <utility>
#include <vector>

using std::string;
using std::vector;

namespace
{

// A key for a cell of a regular grid, or for three exact coordinates
struct key3
{
  int64_t a, b, c;
  bool operator== (const key3& o) const
  {
    return a == o.a && b == o.b && c == o.c;
  }
};

struct hash3
{
  size_t operator() (const key3& k) const
  {
    uint64_t h = 1469598103934665603ULL;
    for (int64_t v : {k.a, k.b, k.c})
    {
      h ^= static_cast<uint64_t> (v) + 0x9e3779b97f4a7c15ULL + (h << 6)
           + (h >> 2);
    }
    return h;
  }
};

int64_t
bits (double x)
{
  if (x == 0)
  {
    x = 0;    // one key for 0 and -0
  }
  int64_t b;
  std::memcpy (&b, &x, sizeof b);
  return b;
}

// The corners of every triangle of an STL file, three rows of x, y and z
// for each triangle in turn.  A binary file is recognised by its size, which
// its triangle count sets exactly; anything else must be ASCII, read as the
// three numbers after every "vertex", in any case and with any spacing.
vector<double>
readstl (const string& file, const string& caller)
{
  FILE *f = std::fopen (file.c_str (), "rb");
  if (! f)
  {
    error ("%s: FILE is not a readable STL file.", caller.c_str ());
  }
  std::fseek (f, 0, SEEK_END);
  const long size = std::ftell (f);
  std::fseek (f, 0, SEEK_SET);
  vector<char> buf (size > 0 ? size + 1 : 1);
  const size_t got = (size > 0) ? std::fread (buf.data (), 1, size, f) : 0;
  std::fclose (f);
  buf[got] = 0;

  vector<double> xyz;
  uint32_t n = 0;
  if (got >= 84)
  {
    std::memcpy (&n, buf.data () + 80, 4);
  }
  if (got >= 84 && got == 84 + 50 * static_cast<size_t> (n))
  {
    xyz.reserve (9 * static_cast<size_t> (n));
    for (uint32_t t = 0; t < n; t++)
    {
      const char *p = buf.data () + 84 + 50 * static_cast<size_t> (t) + 12;
      for (int i = 0; i < 9; i++)
      {
        float x;
        std::memcpy (&x, p + 4 * i, 4);
        xyz.push_back (x);
      }
    }
    return xyz;
  }

  const char *p = buf.data ();
  const char *end = p + got;
  while (p < end && std::isspace (static_cast<unsigned char> (*p)))
  {
    p++;
  }
  if (end - p < 5 || strncasecmp (p, "solid", 5) != 0)
  {
    error ("%s: FILE is not a readable STL file.", caller.c_str ());
  }
  while (p < end)
  {
    while (p < end && std::isspace (static_cast<unsigned char> (*p)))
    {
      p++;
    }
    const char *w = p;
    while (p < end && ! std::isspace (static_cast<unsigned char> (*p)))
    {
      p++;
    }
    if (p - w == 6 && strncasecmp (w, "vertex", 6) == 0)
    {
      for (int i = 0; i < 3; i++)
      {
        char *q;
        const double x = std::strtod (p, &q);
        if (q == p || ! std::isfinite (x))
        {
          error ("%s: FILE is not a readable STL file.", caller.c_str ());
        }
        xyz.push_back (x);
        p = q;
      }
    }
  }
  if (xyz.size () % 9 != 0)
  {
    error ("%s: FILE is not a readable STL file.", caller.c_str ());
  }
  return xyz;
}

// The corners XYZ welded into vertices, exactly or within TOL, and the
// triangles as indices into them from 1, those that two of whose corners
// became one dropped
void
weld (const vector<double>& xyz, double tol, Matrix& V, Matrix& F)
{
  const size_t m = xyz.size () / 3;
  vector<double> verts;
  vector<octave_idx_type> id (m);
  std::unordered_map<key3, vector<octave_idx_type>, hash3> grid;
  grid.reserve (m);
  for (size_t i = 0; i < m; i++)
  {
    const double *p = &xyz[3 * i];
    octave_idx_type k = -1;
    if (tol == 0)
    {
      const key3 c = {bits (p[0]), bits (p[1]), bits (p[2])};
      auto it = grid.find (c);
      if (it != grid.end ())
      {
        k = it->second[0];
      }
      else
      {
        k = verts.size () / 3;
        grid[c].push_back (k);
      }
    }
    else
    {
      const key3 c = {static_cast<int64_t> (std::floor (p[0] / tol)),
                      static_cast<int64_t> (std::floor (p[1] / tol)),
                      static_cast<int64_t> (std::floor (p[2] / tol))};
      for (int64_t a = -1; a <= 1 && k < 0; a++)
        for (int64_t b = -1; b <= 1 && k < 0; b++)
          for (int64_t d = -1; d <= 1 && k < 0; d++)
          {
            auto it = grid.find ({c.a + a, c.b + b, c.c + d});
            if (it == grid.end ())
            {
              continue;
            }
            for (octave_idx_type j : it->second)
            {
              const double *q = &verts[3 * j];
              if (std::hypot (p[0] - q[0], p[1] - q[1], p[2] - q[2]) <= tol)
              {
                k = j;
                break;
              }
            }
          }
      if (k < 0)
      {
        k = verts.size () / 3;
        grid[c].push_back (k);
      }
    }
    if (k == static_cast<octave_idx_type> (verts.size () / 3))
    {
      verts.insert (verts.end (), p, p + 3);
    }
    id[i] = k;
  }

  V = Matrix (verts.size () / 3, 3);
  for (octave_idx_type i = 0; i < V.rows (); i++)
    for (int c = 0; c < 3; c++)
    {
      V(i,c) = verts[3 * i + c];
    }
  vector<octave_idx_type> keep;
  for (size_t t = 0; t < m / 3; t++)
  {
    const octave_idx_type a = id[3 * t], b = id[3 * t + 1], c = id[3 * t + 2];
    if (a != b && b != c && c != a)
    {
      keep.push_back (t);
    }
  }
  F = Matrix (keep.size (), 3);
  for (size_t r = 0; r < keep.size (); r++)
    for (int c = 0; c < 3; c++)
    {
      F(r,c) = id[3 * keep[r] + c] + 1;
    }
}

// A point of a cut, in the plane z = 0
struct pt
{
  double x, y;
};

double
dist (const pt& a, const pt& b)
{
  return std::hypot (a.x - b.x, a.y - b.y);
}

// Twice the signed area inside the closed polygon P, positive anticlockwise
double
area2 (const vector<pt>& P)
{
  double s = 0;
  for (size_t i = 0, j = P.size () - 1; i < P.size (); j = i++)
  {
    s += P[j].x * P[i].y - P[i].x * P[j].y;
  }
  return s;
}

// Whether the point Q lies inside the closed polygon P
bool
inside (const pt& Q, const vector<pt>& P)
{
  bool in = false;
  for (size_t i = 0, j = P.size () - 1; i < P.size (); j = i++)
  {
    if ((P[i].y > Q.y) != (P[j].y > Q.y)
        && Q.x < (P[j].x - P[i].x) * (Q.y - P[i].y) / (P[j].y - P[i].y)
                 + P[i].x)
    {
      in = ! in;
    }
  }
  return in;
}

// Whether the segments AB and CD meet, crossing or touching; three points
// count as in line when the sine of the angle at the first is below 1e-12
bool
meet (const pt& A, const pt& B, const pt& C, const pt& D)
{
  auto orient = [] (const pt& p, const pt& q, const pt& r)
  {
    const double v = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    return (std::abs (v) <= 1e-12 * dist (p, q) * dist (p, r))
           ? 0 : (v > 0 ? 1 : -1);
  };
  auto on = [] (const pt& p, const pt& q, const pt& r)
  {
    return std::min (p.x, q.x) <= r.x && r.x <= std::max (p.x, q.x)
           && std::min (p.y, q.y) <= r.y && r.y <= std::max (p.y, q.y);
  };
  const int o1 = orient (A, B, C), o2 = orient (A, B, D);
  const int o3 = orient (C, D, A), o4 = orient (C, D, B);
  if (o1 != o2 && o3 != o4)
  {
    return true;
  }
  return (o1 == 0 && on (A, B, C)) || (o2 == 0 && on (A, B, D))
         || (o3 == 0 && on (C, D, A)) || (o4 == 0 && on (C, D, B));
}

// A loop with exact repeats and points exactly on the line through their
// neighbours removed
vector<pt>
tidy (const vector<pt>& P, double tol)
{
  vector<pt> Q;
  for (const pt& p : P)
  {
    if (Q.empty () || dist (Q.back (), p) > tol)
    {
      Q.push_back (p);
    }
  }
  while (Q.size () > 1 && dist (Q.front (), Q.back ()) <= tol)
  {
    Q.pop_back ();
  }
  bool changed = true;
  while (changed && Q.size () > 3)
  {
    changed = false;
    vector<pt> R;
    const size_t n = Q.size ();
    for (size_t i = 0; i < n; i++)
    {
      const pt& a = R.empty () ? Q[(i + n - 1) % n] : R.back ();
      const pt& b = Q[i];
      const pt& c = Q[(i + 1) % n];
      const double cr = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
      const double l = dist (a, c);
      if (std::abs (cr) <= 1e-12 * l * l)
      {
        changed = true;
        continue;
      }
      R.push_back (b);
    }
    Q.swap (R);
  }
  return Q;
}

Matrix
tomatrix (const vector<pt>& P, bool repeat = false)
{
  Matrix m (P.size () + (repeat ? 1 : 0), 2);
  for (size_t i = 0; i < P.size (); i++)
  {
    m(i,0) = P[i].x;
    m(i,1) = P[i].y;
  }
  if (repeat)
  {
    m(P.size (),0) = P[0].x;
    m(P.size (),1) = P[0].y;
  }
  return m;
}

// The cut of the mesh with vertices V and triangles F, indices from 1, by
// the plane z = 0.  The cut as a closed set is the slice just below the
// plane, with vertices on it counted above, together with the faces lying in
// the plane that have the mesh above them; their boundaries are added
// segment by segment and those that appear twice cancel.  The segments are
// chained without regard to their direction, so a mesh with its triangles
// turned either way is cut the same, and loose ends closer than TOL are
// joined.  Each loop is an outline or a hole by how deeply it is nested.
// PIECES holds one struct for each separate piece, its outline anticlockwise
// and its holes clockwise, largest first; OPEN the chains that would not
// close and the loops that cross another or themselves.
void
section (const Matrix& V, const Matrix& F, double tol, Cell& pieces,
         Cell& open)
{
  const octave_idx_type nv = V.rows (), nf = F.rows ();
  double scale = 1;
  for (octave_idx_type i = 0; i < V.numel (); i++)
  {
    scale = std::max (scale, std::abs (V(i)));
  }
  const double zt = 1e-9 * scale;
  vector<int> side (nv);    // 0 on the plane, 1 above, -1 below
  for (octave_idx_type i = 0; i < nv; i++)
  {
    const double z = V(i,2);
    side[i] = (std::abs (z) <= zt) ? 0 : (z > 0 ? 1 : -1);
  }

  // A point of the cut is a vertex on the plane, key 2 i, or the crossing of
  // an edge, key 2 (i N + j) + 1, numbered the first time it is met
  std::unordered_map<int64_t, size_t> id;
  id.reserve (nf / 2 + 16);
  vector<pt> where;
  auto vkey = [&] (octave_idx_type i)
  {
    const auto r = id.emplace (2 * static_cast<int64_t> (i), where.size ());
    if (r.second)
    {
      where.push_back (pt {V(i,0), V(i,1)});
    }
    return r.first->second;
  };
  auto ekey = [&] (octave_idx_type i, octave_idx_type j)
  {
    if (side[i] == 0)
    {
      return vkey (i);
    }
    if (side[j] == 0)
    {
      return vkey (j);
    }
    const octave_idx_type a = std::min (i, j), b = std::max (i, j);
    const auto r = id.emplace (2 * (static_cast<int64_t> (a) * nv + b) + 1,
                               where.size ());
    if (r.second)
    {
      const double f = V(a,2) / (V(a,2) - V(b,2));
      where.push_back (pt {V(a,0) + (V(b,0) - V(a,0)) * f,
                           V(a,1) + (V(b,1) - V(a,1)) * f});
    }
    return r.first->second;
  };

  // Every segment, ends in order; one met an even number of times cancels
  vector<std::pair<size_t, size_t>> raw;
  raw.reserve (nf / 4 + 16);
  auto add = [&] (size_t a, size_t b)
  {
    if (a != b)
    {
      raw.emplace_back (std::min (a, b), std::max (a, b));
    }
  };

  vector<octave_idx_type> flat;
  std::unordered_map<int64_t, vector<octave_idx_type>> edgetri;
  auto ek = [nv] (octave_idx_type i, octave_idx_type j)
  {
    return static_cast<int64_t> (std::min (i, j)) * nv + std::max (i, j);
  };
  for (octave_idx_type t = 0; t < nf; t++)
  {
    const octave_idx_type v[3] = {static_cast<octave_idx_type> (F(t,0)) - 1,
                                  static_cast<octave_idx_type> (F(t,1)) - 1,
                                  static_cast<octave_idx_type> (F(t,2)) - 1};
    // Only a triangle with two corners on the plane can border a face lying
    // in it
    if ((side[v[0]] == 0) + (side[v[1]] == 0) + (side[v[2]] == 0) >= 2)
    {
      for (int e = 0; e < 3; e++)
      {
        edgetri[ek (v[e], v[(e + 1) % 3])].push_back (t);
      }
    }
    if (side[v[0]] == 0 && side[v[1]] == 0 && side[v[2]] == 0)
    {
      flat.push_back (t);
      continue;
    }
    // Below or not: a vertex on the plane counts as above
    const bool lo[3] = {side[v[0]] < 0, side[v[1]] < 0, side[v[2]] < 0};
    if (lo[0] == lo[1] && lo[1] == lo[2])
    {
      continue;
    }
    int64_t k[2];
    int n = 0;
    for (int e = 0; e < 3 && n < 2; e++)
    {
      const int a = e, b = (e + 1) % 3;
      if (lo[a] != lo[b])
      {
        k[n++] = ekey (v[a], v[b]);
      }
    }
    add (k[0], k[1]);
  }

  // The faces in the plane, by connected patch, with the mesh above them:
  // known from a triangle across the patch's border, or failing that from
  // the way the face is turned
  if (! flat.empty ())
  {
    std::unordered_map<octave_idx_type, size_t> isflat;
    for (size_t i = 0; i < flat.size (); i++)
    {
      isflat[flat[i]] = i;
    }
    vector<int> patch (flat.size (), -1);
    int np = 0;
    for (size_t s = 0; s < flat.size (); s++)
    {
      if (patch[s] >= 0)
      {
        continue;
      }
      vector<size_t> stack = {s};
      patch[s] = np;
      int above = 0;
      while (! stack.empty ())
      {
        const size_t i = stack.back ();
        stack.pop_back ();
        const octave_idx_type t = flat[i];
        for (int e = 0; e < 3; e++)
        {
          const octave_idx_type a = static_cast<octave_idx_type> (F(t,e)) - 1;
          const octave_idx_type b
            = static_cast<octave_idx_type> (F(t,(e + 1) % 3)) - 1;
          for (octave_idx_type u : edgetri[ek (a, b)])
          {
            if (u == t)
            {
              continue;
            }
            auto it = isflat.find (u);
            if (it != isflat.end ())
            {
              if (patch[it->second] < 0)
              {
                patch[it->second] = np;
                stack.push_back (it->second);
              }
            }
            else if (above == 0)
            {
              for (int c = 0; c < 3; c++)
              {
                const int sd = side[static_cast<octave_idx_type> (F(u,c)) - 1];
                if (sd != 0)
                {
                  above = sd;
                }
              }
            }
          }
        }
      }
      if (above == 0)
      {
        // The outward normal of the first face, down when the mesh is above
        const octave_idx_type t = flat[s];
        const octave_idx_type a = static_cast<octave_idx_type> (F(t,0)) - 1;
        const octave_idx_type b = static_cast<octave_idx_type> (F(t,1)) - 1;
        const octave_idx_type c = static_cast<octave_idx_type> (F(t,2)) - 1;
        const double nz = (V(b,0) - V(a,0)) * (V(c,1) - V(a,1))
                          - (V(b,1) - V(a,1)) * (V(c,0) - V(a,0));
        above = (nz < 0) ? 1 : -1;
      }
      if (above > 0)
      {
        for (size_t i = 0; i < flat.size (); i++)
        {
          if (patch[i] == np)
          {
            const octave_idx_type t = flat[i];
            for (int e = 0; e < 3; e++)
            {
              add (vkey (static_cast<octave_idx_type> (F(t,e)) - 1),
                   vkey (static_cast<octave_idx_type> (F(t,(e + 1) % 3)) - 1));
            }
          }
        }
      }
      np++;
    }
  }

  // The segments that remain, and the segments meeting at each point in one
  // array, those at point p from START (p) on
  std::sort (raw.begin (), raw.end ());
  vector<std::pair<size_t, size_t>> seg;
  for (size_t i = 0; i < raw.size (); )
  {
    size_t j = i;
    while (j < raw.size () && raw[j] == raw[i])
    {
      j++;
    }
    if ((j - i) % 2 == 1)
    {
      seg.push_back (raw[i]);
    }
    i = j;
  }
  const size_t npt = where.size ();
  vector<size_t> start (npt + 1, 0);
  for (const auto& g : seg)
  {
    start[g.first + 1]++;
    start[g.second + 1]++;
  }
  for (size_t p = 0; p < npt; p++)
  {
    start[p + 1] += start[p];
  }
  vector<size_t> adj (2 * seg.size ());
  {
    vector<size_t> fill (start.begin (), start.end () - 1);
    for (size_t i = 0; i < seg.size (); i++)
    {
      adj[fill[seg[i].first]++] = i;
      adj[fill[seg[i].second]++] = i;
    }
  }

  // Chains, walked from a loose end where there is one
  vector<char> used (seg.size (), 0);
  vector<vector<size_t>> chains;
  vector<char> closed;
  auto walk = [&] (size_t s, size_t from)
  {
    vector<size_t> c = {from};
    size_t here = from;
    size_t i = s;
    while (true)
    {
      used[i] = 1;
      here = (seg[i].first == here) ? seg[i].second : seg[i].first;
      c.push_back (here);
      size_t next = seg.size ();
      for (size_t q = start[here]; q < start[here + 1]; q++)
      {
        if (! used[adj[q]])
        {
          next = adj[q];
          break;
        }
      }
      if (next == seg.size ())
      {
        break;
      }
      i = next;
    }
    return c;
  };
  for (size_t p = 0; p < npt; p++)
  {
    if (start[p + 1] - start[p] == 1 && ! used[adj[start[p]]])
    {
      chains.push_back (walk (adj[start[p]], p));
      closed.push_back (0);
    }
  }
  for (size_t i = 0; i < seg.size (); i++)
  {
    if (! used[i])
    {
      vector<size_t> c = walk (i, seg[i].first);
      const bool shut = (c.back () == c.front ());
      if (shut)
      {
        c.pop_back ();
      }
      chains.push_back (c);
      closed.push_back (shut);
    }
  }

  vector<vector<pt>> pts (chains.size ());
  for (size_t i = 0; i < chains.size (); i++)
  {
    pts[i].reserve (chains[i].size ());
    for (size_t k : chains[i])
    {
      pts[i].push_back (where[k]);
    }
  }

  // Loose ends closer than TOL joined, nearest first: each end linked to at
  // most one other, then the chains followed from link to link
  vector<size_t> loose;
  for (size_t i = 0; i < chains.size (); i++)
  {
    if (! closed[i])
    {
      loose.push_back (i);
    }
  }
  vector<vector<pt>> loops;
  vector<vector<pt>> openchains;
  if (! loose.empty ())
  {
    // End 2 i is the start of loose chain i, 2 i + 1 its end
    const size_t ne = 2 * loose.size ();
    auto endpt = [&] (size_t e)
    {
      const vector<pt>& c = pts[loose[e / 2]];
      return (e % 2 == 0) ? c.front () : c.back ();
    };
    vector<std::tuple<double, size_t, size_t>> cand;
    if (tol > 0)
    {
      std::unordered_map<key3, vector<size_t>, hash3> grid;
      for (size_t e = 0; e < ne; e++)
      {
        const pt p = endpt (e);
        grid[{static_cast<int64_t> (std::floor (p.x / tol)),
              static_cast<int64_t> (std::floor (p.y / tol)), 0}].push_back (e);
      }
      for (size_t e = 0; e < ne; e++)
      {
        const pt p = endpt (e);
        const int64_t cx = std::floor (p.x / tol), cy = std::floor (p.y / tol);
        for (int64_t a = -1; a <= 1; a++)
          for (int64_t b = -1; b <= 1; b++)
          {
            auto it = grid.find ({cx + a, cy + b, 0});
            if (it == grid.end ())
            {
              continue;
            }
            for (size_t f : it->second)
            {
              if (f > e && ! (f / 2 == e / 2 && pts[loose[e / 2]].size () < 3))
              {
                const double d = dist (p, endpt (f));
                if (d <= tol)
                {
                  cand.emplace_back (d, e, f);
                }
              }
            }
          }
      }
      std::sort (cand.begin (), cand.end ());
    }
    vector<long> link (ne, -1);
    for (const auto& c : cand)
    {
      const size_t e = std::get<1> (c), f = std::get<2> (c);
      if (link[e] < 0 && link[f] < 0)
      {
        link[e] = f;
        link[f] = e;
      }
    }
    vector<char> done (loose.size (), 0);
    auto follow = [&] (size_t e0)
    {
      // Enter the chain at end e0 and follow links until a free end or back
      // to the start
      vector<pt> out;
      size_t e = e0;
      bool shut = false;
      while (true)
      {
        const size_t c = e / 2;
        done[c] = 1;
        const vector<pt>& P = pts[loose[c]];
        if (e % 2 == 0)
        {
          out.insert (out.end (), P.begin (), P.end ());
        }
        else
        {
          out.insert (out.end (), P.rbegin (), P.rend ());
        }
        const size_t x = (e % 2 == 0) ? e + 1 : e - 1;
        if (link[x] < 0)
        {
          break;
        }
        e = link[x];
        if (e == e0)
        {
          shut = true;
          break;
        }
      }
      return std::make_pair (out, shut);
    };
    for (size_t e = 0; e < ne; e++)
    {
      if (! done[e / 2] && link[e] < 0)
      {
        openchains.push_back (follow (e).first);
      }
    }
    for (size_t e = 0; e < ne; e += 2)
    {
      if (! done[e / 2])
      {
        auto r = follow (e);
        if (r.second)
        {
          loops.push_back (r.first);
        }
        else
        {
          openchains.push_back (r.first);
        }
      }
    }
  }
  for (size_t i = 0; i < chains.size (); i++)
  {
    if (closed[i])
    {
      loops.push_back (pts[i]);
    }
  }

  // Loops tidied, slivers thinner than TOL dropped
  vector<vector<pt>> L;
  for (const vector<pt>& P : loops)
  {
    vector<pt> Q = tidy (P, tol);
    if (Q.size () < 3)
    {
      continue;
    }
    double per = 0;
    for (size_t i = 0, j = Q.size () - 1; i < Q.size (); j = i++)
    {
      per += dist (Q[i], Q[j]);
    }
    if (std::abs (area2 (Q)) / 2 <= std::max (tol, 1e-12 * scale) * per)
    {
      continue;
    }
    L.push_back (Q);
  }

  // Loops that cross or touch themselves or another, found on a grid
  vector<char> bad (L.size (), 0);
  {
    // Cells twice the mean length of a segment, so that each holds a few;
    // every segment listed under each cell it reaches, the list sorted by
    // cell and each cell's segments tested pair by pair
    size_t nseg = 0;
    double total = 0;
    double lo[2] = {INFINITY, INFINITY}, hi[2] = {-INFINITY, -INFINITY};
    for (const auto& P : L)
    {
      nseg += P.size ();
      for (size_t i = 0; i < P.size (); i++)
      {
        total += dist (P[i], P[(i + 1) % P.size ()]);
        lo[0] = std::min (lo[0], P[i].x);
        lo[1] = std::min (lo[1], P[i].y);
        hi[0] = std::max (hi[0], P[i].x);
        hi[1] = std::max (hi[1], P[i].y);
      }
    }
    if (nseg > 0)
    {
      const double cell = std::max ({2 * total / nseg, 1e-9 * scale,
                                     (hi[0] - lo[0]) / 1e9,
                                     (hi[1] - lo[1]) / 1e9});
      struct entry
      {
        uint64_t cell;
        size_t loop, i;
      };
      vector<entry> grid;
      grid.reserve (2 * nseg);
      for (size_t l = 0; l < L.size (); l++)
        for (size_t i = 0; i < L[l].size (); i++)
        {
          const pt& a = L[l][i];
          const pt& b = L[l][(i + 1) % L[l].size ()];
          const uint64_t x0 = (std::min (a.x, b.x) - lo[0]) / cell;
          const uint64_t x1 = (std::max (a.x, b.x) - lo[0]) / cell;
          const uint64_t y0 = (std::min (a.y, b.y) - lo[1]) / cell;
          const uint64_t y1 = (std::max (a.y, b.y) - lo[1]) / cell;
          for (uint64_t x = x0; x <= x1; x++)
            for (uint64_t y = y0; y <= y1; y++)
            {
              grid.push_back ({(x << 32) | y, l, i});
            }
        }
      std::sort (grid.begin (), grid.end (),
                 [] (const entry& a, const entry& b)
                 { return a.cell < b.cell; });
      for (size_t g0 = 0; g0 < grid.size (); )
      {
        size_t g1 = g0;
        while (g1 < grid.size () && grid[g1].cell == grid[g0].cell)
        {
          g1++;
        }
        for (size_t p = g0; p < g1; p++)
          for (size_t q = p + 1; q < g1; q++)
          {
            const size_t l1 = grid[p].loop, i1 = grid[p].i;
            const size_t l2 = grid[q].loop, i2 = grid[q].i;
            if (bad[l1] && bad[l2])
            {
              continue;
            }
            const size_t n1 = L[l1].size ();
            if (l1 == l2 && (i1 == i2 || (i1 + 1) % n1 == i2
                             || (i2 + 1) % n1 == i1))
            {
              continue;
            }
            if (meet (L[l1][i1], L[l1][(i1 + 1) % n1], L[l2][i2],
                      L[l2][(i2 + 1) % L[l2].size ()]))
            {
              bad[l1] = bad[l2] = 1;
            }
          }
        g0 = g1;
      }
    }
  }
  vector<vector<pt>> G;
  for (size_t l = 0; l < L.size (); l++)
  {
    if (bad[l])
    {
      L[l].push_back (L[l][0]);
      openchains.push_back (L[l]);
    }
    else
    {
      G.push_back (L[l]);
    }
  }

  // Nesting: a loop inside an even number of others is an outline, inside
  // an odd number a hole in the smallest outline around it
  const size_t ng = G.size ();
  vector<double> A (ng);
  for (size_t i = 0; i < ng; i++)
  {
    A[i] = std::abs (area2 (G[i])) / 2;
  }
  vector<int> depth (ng, 0);
  vector<long> parent (ng, -1);
  for (size_t i = 0; i < ng; i++)
    for (size_t j = 0; j < ng; j++)
    {
      if (i != j && A[j] > A[i] && inside (G[i][0], G[j]))
      {
        depth[i]++;
        if (parent[i] < 0 || A[j] < A[parent[i]])
        {
          parent[i] = j;
        }
      }
    }
  vector<size_t> outer;
  for (size_t i = 0; i < ng; i++)
  {
    if (depth[i] % 2 == 0)
    {
      outer.push_back (i);
    }
  }
  vector<double> net (ng, 0);
  for (size_t i : outer)
  {
    net[i] = A[i];
  }
  for (size_t i = 0; i < ng; i++)
  {
    if (depth[i] % 2 == 1)
    {
      net[parent[i]] -= A[i];
    }
  }
  std::sort (outer.begin (), outer.end (),
             [&] (size_t a, size_t b) { return net[a] > net[b]; });
  pieces = Cell (1, outer.size ());
  for (size_t k = 0; k < outer.size (); k++)
  {
    const size_t o = outer[k];
    if (area2 (G[o]) < 0)
    {
      std::reverse (G[o].begin (), G[o].end ());
    }
    vector<Matrix> holes;
    for (size_t i = 0; i < ng; i++)
    {
      if (depth[i] % 2 == 1 && parent[i] == static_cast<long> (o))
      {
        if (area2 (G[i]) > 0)
        {
          std::reverse (G[i].begin (), G[i].end ());
        }
        holes.push_back (tomatrix (G[i]));
      }
    }
    Cell h (1, holes.size ());
    for (size_t i = 0; i < holes.size (); i++)
    {
      h(i) = holes[i];
    }
    octave_scalar_map m;
    m.assign ("outline", tomatrix (G[o]));
    m.assign ("holes", h);
    pieces(k) = m;
  }
  open = Cell (1, openchains.size ());
  for (size_t i = 0; i < openchains.size (); i++)
  {
    open(i) = tomatrix (openchains[i]);
  }
}

}

DEFUN_DLD (__mesh__, args, ,
           "-*- texinfo -*-\n\
@deftypefn {} {@dots{} =} __mesh__ (@var{cmd}, @var{caller}, @dots{})\n\
Undocumented internal function.\n\
@end deftypefn")
{
  if (args.length () < 2)
  {
    print_usage ();
  }
  const string cmd = args(0).string_value ();
  const string caller = args(1).string_value ();

  // [V, F] = __mesh__ ('read', caller, FILE, TOL)
  if (cmd == "read")
  {
    Matrix V, F;
    weld (readstl (args(2).string_value (), caller), args(3).double_value (),
          V, F);
    return ovl (V, F);
  }

  // [PIECES, OPEN] = __mesh__ ('section', caller, V, F, TOL), the vertices
  // in the frame of the plane, which is z = 0
  else if (cmd == "section")
  {
    Cell pieces, open;
    section (args(2).matrix_value (), args(3).matrix_value (),
             args(4).double_value (), pieces, open);
    return ovl (pieces, open);
  }

  error ("__mesh__: unknown command '%s'.", cmd.c_str ());
}
