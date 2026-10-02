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


// Fitting lines, arcs and splines to a polygon, within a tolerance

pt
operator+ (const pt& a, const pt& b)
{
  return pt {a.x + b.x, a.y + b.y};
}

pt
operator- (const pt& a, const pt& b)
{
  return pt {a.x - b.x, a.y - b.y};
}

pt
operator* (double s, const pt& a)
{
  return pt {s * a.x, s * a.y};
}

double
dot (const pt& a, const pt& b)
{
  return a.x * b.x + a.y * b.y;
}

double
cross (const pt& a, const pt& b)
{
  return a.x * b.y - a.y * b.x;
}

double
len (const pt& a)
{
  return std::hypot (a.x, a.y);
}

pt
unit (const pt& a)
{
  const double l = len (a);
  return (l > 0) ? (1 / l) * a : a;
}

// The left normal of a direction
pt
left (const pt& a)
{
  return pt {-a.y, a.x};
}

double
segdist (const pt& q, const pt& a, const pt& b)
{
  const pt d = b - a;
  const double l2 = dot (d, d);
  double t = (l2 > 0) ? dot (q - a, d) / l2 : 0;
  t = std::min (1.0, std::max (0.0, t));
  return len (q - (a + t * d));
}

// A fitted piece: a line from P[0] to P[1]; an arc from P[0] through P[1] to
// P[2]; or a cubic spline with control points P and the full knot vector K
struct piece
{
  int type;
  vector<pt> P;
  vector<double> K;
  size_t e = 0;     // the index in its run of the point it ends at
  size_t b = 0;     // and of the point it starts at
};

// A circular arc from A to B with centre C and radius R, turning anticlockwise
// when CCW, through the angle SWEEP
struct arc
{
  pt A, B, C;
  double R, sweep;
  bool ccw;

  // The angle from A round to the point Q, in the arc's sense, in [0, 2 pi)
  double at (const pt& Q) const
  {
    double a = std::atan2 (cross (A - C, Q - C), dot (A - C, Q - C));
    if (! ccw)
    {
      a = -a;
    }
    return (a < 0) ? a + 2 * M_PI : a;
  }

  double dist (const pt& Q) const
  {
    const double a = at (Q);
    if (a <= sweep + 1e-9 || a >= 2 * M_PI - 1e-9)
    {
      return std::abs (len (Q - C) - R);
    }
    return std::min (len (Q - A), len (Q - B));
  }

  pt point (double a) const
  {
    const double s = ccw ? a : -a;
    const pt r = A - C;
    return C + pt {r.x * std::cos (s) - r.y * std::sin (s),
                   r.x * std::sin (s) + r.y * std::cos (s)};
  }

  pt tangent (const pt& Q) const
  {
    const pt t = unit (left (Q - C));
    return ccw ? t : -1.0 * t;
  }
};

// The arc from A through M to B
bool
arc3 (const pt& A, const pt& M, const pt& B, arc& c)
{
  const pt a = A - M, b = B - M;
  const double d = 2 * cross (a, b);
  if (std::abs (d) <= 1e-12 * dot (a, a) * std::sqrt (dot (b, b)) + 1e-300)
  {
    return false;
  }
  const double aa = dot (a, a), bb = dot (b, b);
  c.C = M + pt {(b.y * aa - a.y * bb) / d, (a.x * bb - b.x * aa) / d};
  c.R = len (A - c.C);
  c.A = A;
  c.B = B;
  c.ccw = cross (M - A, B - M) > 0;
  c.sweep = c.at (B);
  return c.sweep > 0;
}

// The arc from A leaving in the direction T and ending at B
bool
arct (const pt& A, const pt& T, const pt& B, arc& c)
{
  const pt n = left (T), v = B - A;
  const double d = 2 * dot (v, n);
  if (std::abs (d) <= 1e-12 * len (v))
  {
    return false;
  }
  const double r = dot (v, v) / d;
  c.C = A + r * n;
  c.R = std::abs (r);
  c.A = A;
  c.B = B;
  c.ccw = r > 0;
  c.sweep = c.at (B);
  return c.sweep > 0;
}

// A run of points of a polygon to fit, with the distance along it
struct run
{
  vector<pt> Q;
  vector<double> s;

  explicit run (const vector<pt>& q) : Q (q), s (q.size (), 0)
  {
    for (size_t i = 1; i < Q.size (); i++)
    {
      s[i] = s[i-1] + len (Q[i] - Q[i-1]);
    }
  }
};

// Whether the curve DIST strays no further than TOL from the run's points a
// to e and the middles of the segments between them, the first starting at S
template <typename F>
bool
within (const run& r, size_t a, size_t e, const pt& S, double tol, F dist)
{
  pt prev = S;
  for (size_t i = a + 1; i <= e; i++)
  {
    if (dist (r.Q[i]) > tol || dist (0.5 * (prev + r.Q[i])) > tol)
    {
      return false;
    }
    prev = r.Q[i];
  }
  return true;
}

// The furthest point e from a for which OK (e) holds, found by doubling then
// halving from a + FIRST; a when it does not hold there
template <typename F>
size_t
reach (size_t a, size_t m, F ok, size_t first = 1)
{
  if (a + first > m || ! ok (a + first))
  {
    return a;
  }
  size_t good = a + first, bad = m + 1, step = 2 * first;
  while (good < m)
  {
    const size_t e = std::min (m, a + step);
    if (ok (e))
    {
      good = e;
      step *= 2;
    }
    else
    {
      bad = e;
      break;
    }
  }
  while (bad <= m && bad - good > 1)
  {
    const size_t e = (good + bad) / 2;
    if (ok (e))
    {
      good = e;
    }
    else
    {
      bad = e;
    }
  }
  return good;
}

// The nonzero cubic B-spline basis functions at u on the knots K, and the
// index of the first
size_t
basis (const vector<double>& K, double u, double N[4])
{
  const size_t n = K.size () - 4;
  size_t s = std::upper_bound (K.begin (), K.end (), u) - K.begin () - 1;
  s = std::min (std::max (s, size_t (3)), n - 1);
  double left[4], right[4];
  N[0] = 1;
  for (int j = 1; j <= 3; j++)
  {
    left[j] = u - K[s + 1 - j];
    right[j] = K[s + j] - u;
    double saved = 0;
    for (int r = 0; r < j; r++)
    {
      const double t = N[r] / (right[r + 1] + left[j - r]);
      N[r] = saved + right[r + 1] * t;
      saved = left[j - r] * t;
    }
    N[j] = saved;
  }
  return s - 3;
}

// Solve the symmetric positive definite system A x = b, A n-by-n
bool
cholsolve (vector<double>& A, vector<double>& b, size_t n)
{
  for (size_t j = 0; j < n; j++)
  {
    double d = A[j * n + j];
    for (size_t k = 0; k < j; k++)
    {
      d -= A[j * n + k] * A[j * n + k];
    }
    if (d <= 0)
    {
      return false;
    }
    d = std::sqrt (d);
    A[j * n + j] = d;
    for (size_t i = j + 1; i < n; i++)
    {
      double t = A[i * n + j];
      for (size_t k = 0; k < j; k++)
      {
        t -= A[i * n + k] * A[j * n + k];
      }
      A[i * n + j] = t / d;
    }
  }
  for (size_t i = 0; i < n; i++)
  {
    double t = b[i];
    for (size_t k = 0; k < i; k++)
    {
      t -= A[i * n + k] * b[k];
    }
    b[i] = t / A[i * n + i];
  }
  for (size_t i = n; i-- > 0; )
  {
    double t = b[i];
    for (size_t k = i + 1; k < n; k++)
    {
      t -= A[k * n + i] * b[k];
    }
    b[i] = t / A[i * n + i];
  }
  return true;
}

// The least-squares cubic spline through the run's points a to e, starting at
// S and ending at E, leaving S in the direction T0 and arriving at E in the
// direction T1 where they are given, with knots added in the span where it
// strays most until it is within TOL
bool
splinefit (const run& r, size_t a, size_t e, const pt& S, const pt& E,
           const pt *T0, const pt *T1, double tol, piece& out)
{
  vector<pt> D;
  D.push_back (S);
  for (size_t i = a + 1; i < e; i++)
  {
    D.push_back (r.Q[i]);
  }
  D.push_back (E);
  const size_t k = D.size ();
  vector<double> u (k, 0);
  for (size_t i = 1; i < k; i++)
  {
    u[i] = u[i-1] + len (D[i] - D[i-1]);
  }
  if (u.back () <= 0)
  {
    return false;
  }
  for (double& x : u)
  {
    x /= u.back ();
  }
  vector<double> K = {0, 0, 0, 0, 1, 1, 1, 1};
  const size_t cap = std::max (size_t (4), std::min (k / 2, size_t (200)));
  while (true)
  {
    const size_t n = K.size () - 4;
    // Unknowns: the x and y of each free control point, then the lengths
    // along T0 and T1 of the second and the last but one
    vector<int> slot (n, -1);
    size_t nz = 0;
    for (size_t i = 1; i + 1 < n; i++)
    {
      if ((i == 1 && T0) || (i == n - 2 && T1))
      {
        continue;
      }
      slot[i] = nz;
      nz += 2;
    }
    const int ia = T0 ? nz++ : -1;
    const int ib = T1 ? nz++ : -1;
    if (nz == 0 || (n == 4 && T0 && T1 && false))
    {
      return false;
    }
    vector<double> A (nz * nz, 0), b (nz, 0);
    for (size_t j = 0; j < k; j++)
    {
      double N[4];
      const size_t f = basis (K, u[j], N);
      // Row for x and for y: sum of coefficients times unknowns = rhs
      for (int c = 0; c < 2; c++)
      {
        std::vector<std::pair<int, double>> row;
        double rhs = c ? D[j].y : D[j].x;
        for (int q = 0; q < 4; q++)
        {
          const size_t i = f + q;
          const double w = N[q];
          if (w == 0)
          {
            continue;
          }
          if (i == 0)
          {
            rhs -= w * (c ? S.y : S.x);
          }
          else if (i == n - 1)
          {
            rhs -= w * (c ? E.y : E.x);
          }
          else if (i == 1 && T0)
          {
            rhs -= w * (c ? S.y : S.x);
            row.emplace_back (ia, w * (c ? T0->y : T0->x));
          }
          else if (i == n - 2 && T1)
          {
            rhs -= w * (c ? E.y : E.x);
            row.emplace_back (ib, -w * (c ? T1->y : T1->x));
          }
          else
          {
            row.emplace_back (slot[i] + c, w);
          }
        }
        for (const auto& p : row)
        {
          b[p.first] += p.second * rhs;
          for (const auto& q : row)
          {
            A[p.first * nz + q.first] += p.second * q.second;
          }
        }
      }
    }
    double tr = 0;
    for (size_t i = 0; i < nz; i++)
    {
      tr += A[i * nz + i];
    }
    for (size_t i = 0; i < nz; i++)
    {
      A[i * nz + i] += 1e-12 * tr / nz + 1e-300;
    }
    if (! cholsolve (A, b, nz))
    {
      return false;
    }
    vector<pt> P (n);
    P[0] = S;
    P[n-1] = E;
    for (size_t i = 1; i + 1 < n; i++)
    {
      if (i == 1 && T0)
      {
        P[i] = S + b[ia] * *T0;
      }
      else if (i == n - 2 && T1)
      {
        P[i] = E - b[ib] * *T1;
      }
      else
      {
        P[i] = pt {b[slot[i]], b[slot[i] + 1]};
      }
    }
    if ((T0 && b[ia] <= 0) || (T1 && b[ib] <= 0))
    {
      return false;
    }
    auto eval = [&] (double t)
    {
      double N[4];
      const size_t f = basis (K, t, N);
      pt c {0, 0};
      for (int q = 0; q < 4; q++)
      {
        c = c + N[q] * P[f + q];
      }
      return c;
    };
    // The worst of the points and of the middles of the segments
    double worst = 0;
    double where = 0.5;
    for (size_t j = 0; j < k; j++)
    {
      const double d = len (eval (u[j]) - D[j]);
      if (d > worst)
      {
        worst = d;
        where = u[j];
      }
      if (j + 1 < k)
      {
        const double t = (u[j] + u[j+1]) / 2;
        const double dm = segdist (eval (t), D[j], D[j+1]);
        if (dm > worst)
        {
          worst = dm;
          where = t;
        }
      }
    }
    if (worst <= tol)
    {
      out.type = 2;
      out.P = P;
      out.K = K;
      return true;
    }
    if (n >= cap)
    {
      return false;
    }
    size_t s = std::upper_bound (K.begin (), K.end (), where) - K.begin () - 1;
    s = std::min (std::max (s, size_t (3)), n - 1);
    K.insert (K.begin () + s + 1, (K[s] + K[s + 1]) / 2);
  }
}

// The end direction of a piece
pt
endtangent (const piece& p)
{
  if (p.type == 0)
  {
    return unit (p.P[1] - p.P[0]);
  }
  if (p.type == 1)
  {
    arc c;
    arc3 (p.P[0], p.P[1], p.P[2], c);
    return c.tangent (p.P[2]);
  }
  return unit (p.P.back () - p.P[p.P.size () - 2]);
}

pt
starttangent (const piece& p)
{
  if (p.type == 0)
  {
    return unit (p.P[1] - p.P[0]);
  }
  if (p.type == 1)
  {
    arc c;
    arc3 (p.P[0], p.P[1], p.P[2], c);
    return c.tangent (p.P[0]);
  }
  return unit (p.P[1] - p.P[0]);
}

// The pieces of a run from its first point to its last, ends fixed, mode 1
// lines, 2 arcs, 3 curves: from each start the line or arc that reaches
// furthest within TOL, tangent to the piece before it where it can be; in
// mode 3 a stretch no line or arc covers well is one spline
vector<piece>
fitrun (const run& r, int mode, double tol, double size)
{
  vector<piece> out;
  const size_t m = r.Q.size () - 1;
  size_t a = 0;
  pt S = r.Q[0];
  bool smooth = false;      // a tangent to keep from the piece before
  pt T {0, 0};
  bool loose = false;       // inside a stretch for a spline
  size_t fa = 0;
  pt fS {0, 0};
  bool fsmooth = false;
  pt fT {0, 0};

  // A piece from S at a to e: a line, along T when given
  auto line = [&] (size_t e, const pt *t, piece& p)
  {
    pt E = r.Q[e];
    if (t)
    {
      const double l = dot (E - S, *t);
      if (l <= 0)
      {
        return false;
      }
      if (e != m)
      {
        E = S + l * *t;
      }
    }
    if (len (E - S) <= 0)
    {
      return false;
    }
    if (! within (r, a, e, S, tol, [&] (const pt& q)
                  { return segdist (q, S, E); }))
    {
      return false;
    }
    p.type = 0;
    p.P = {S, E};
    return true;
  };
  auto circ = [&] (size_t e, const pt *t, piece& p, double& sweep)
  {
    arc c;
    if (t)
    {
      if (! arct (S, *t, r.Q[e], c))
      {
        return false;
      }
    }
    else
    {
      if (e < a + 2)
      {
        return false;
      }
      const double mid = (r.s[a] + r.s[e]) / 2;
      size_t i = std::lower_bound (r.s.begin () + a, r.s.begin () + e,
                                   mid) - r.s.begin ();
      i = std::min (std::max (i, a + 1), e - 1);
      if (! arc3 (S, r.Q[i], r.Q[e], c))
      {
        return false;
      }
    }
    if (c.sweep > M_PI + 1e-9 || c.R > 1e6 * (r.s.back () + 1))
    {
      return false;
    }
    if (! within (r, a, e, S, tol, [&] (const pt& q) { return c.dist (q); }))
    {
      return false;
    }
    p.type = 1;
    p.P = {S, c.point (c.sweep / 2), r.Q[e]};
    sweep = c.sweep;
    return true;
  };

  auto spline = [&] (size_t b, const pt& E, const pt *T1)
  {
    piece p;
    if (b > fa + 1 && splinefit (r, fa, b, fS, E, fsmooth ? &fT : nullptr,
                                 T1, tol, p))
    {
      p.e = b;
      p.b = fa;
      out.push_back (p);
      return;
    }
    // Failing that, the polygon itself
    pt from = fS;
    for (size_t i = fa + 1; i <= b; i++)
    {
      const pt to = (i == b) ? E : r.Q[i];
      out.push_back (piece {0, {from, to}, {}, i, i - 1});
      from = to;
    }
  };

  while (a < m)
  {
    const pt *t = (smooth && ! loose) ? &T : nullptr;
    piece pl, pa;
    double sweep = 0;
    size_t el = reach (a, m, [&] (size_t e) { return line (e, t, pl); });
    size_t ea = (mode >= 2) ? reach (a, m, [&] (size_t e)
                                     { return circ (e, t, pa, sweep); },
                                     t ? 1 : 2) : a;
    if (t && el == a && ea == a)
    {
      t = nullptr;
      el = reach (a, m, [&] (size_t e) { return line (e, t, pl); });
      ea = (mode >= 2) ? reach (a, m, [&] (size_t e)
                                { return circ (e, t, pa, sweep); }, 2) : a;
    }
    if (el > a)
    {
      line (el, t, pl);
    }
    if (ea > a)
    {
      circ (ea, t, pa, sweep);
    }
    const bool isarc = ea > el;
    const size_t e = isarc ? ea : el;
    if (e == a)
    {
      // Nothing fits, not even one segment: take the segment as it is
      out.push_back (piece {0, {S, r.Q[a + 1]}, {}, a + 1, a});
      S = r.Q[a + 1];
      smooth = false;
      a++;
      continue;
    }
    const piece& best = isarc ? pa : pl;
    if (mode == 3)
    {
      const bool big = isarc ? (e - a >= 4 && sweep >= M_PI / 3)
                             : (e - a >= 2 && r.s[e] - r.s[a] >= 0.02 * size);
      if (! big)
      {
        if (! loose)
        {
          loose = true;
          fa = a;
          fS = S;
          fsmooth = smooth;
          fT = T;
        }
        a++;
        S = r.Q[a];
        smooth = false;
        continue;
      }
      if (loose)
      {
        const pt T1 = starttangent (best);
        spline (a, S, &T1);
        loose = false;
      }
    }
    out.push_back (best);
    out.back ().e = e;
    out.back ().b = a;
    S = best.P.back ();
    T = endtangent (best);
    smooth = true;
    a = e;
  }
  if (loose)
  {
    spline (m, r.Q[m], nullptr);
  }
  return out;
}

// The point at the distance S along the polygon P with distances D, round
// and round when it is closed, held to its ends when not
pt
along (const vector<pt>& P, const vector<double>& D, bool closed, double s)
{
  const double L = D.back ();
  if (closed)
  {
    s = std::fmod (s, L);
    if (s < 0)
    {
      s += L;
    }
  }
  else
  {
    s = std::min (std::max (s, 0.0), D[P.size () - 1]);
  }
  size_t i = std::upper_bound (D.begin (), D.end (), s) - D.begin ();
  i = std::min (std::max (i, size_t (1)), D.size () - 1);
  const pt& a = P[(i - 1) % P.size ()];
  const pt& b = P[i % P.size ()];
  const double l = D[i] - D[i-1];
  return (l > 0) ? a + ((s - D[i-1]) / l) * (b - a) : a;
}

// The line through the points of the polygon between the distances S0 and
// S1 along it, by least squares: a point on it and its direction
void
fitline (const vector<pt>& P, const vector<double>& D, bool closed,
         double s0, double s1, pt& O, pt& dir)
{
  vector<pt> q;
  q.push_back (along (P, D, closed, s0));
  const size_t n = P.size ();
  const double L = D.back ();
  for (size_t i = 0; i < n; i++)
  {
    double s = D[i];
    for (double w : {s - L, s, s + L})
    {
      if (w > s0 && w < s1 && (closed || w == s))
      {
        q.push_back (P[i]);
      }
    }
  }
  q.push_back (along (P, D, closed, s1));
  pt c {0, 0};
  for (const pt& p : q)
  {
    c = c + p;
  }
  c = (1.0 / q.size ()) * c;
  double sxx = 0, sxy = 0, syy = 0;
  for (const pt& p : q)
  {
    const pt d = p - c;
    sxx += d.x * d.x;
    sxy += d.x * d.y;
    syy += d.y * d.y;
  }
  const double th = 0.5 * std::atan2 (2 * sxy, sxx - syy);
  O = c;
  dir = pt {std::cos (th), std::sin (th)};
  if (dot (dir, q.back () - q.front ()) < 0)
  {
    dir = -1.0 * dir;
  }
}

// The corners of the polygon P: where the turn between its mean direction
// over W behind a point and over W ahead passes the angle CORNER, at the
// peak, kept where the polygon near it lies within TOL of the sharp corner
// the lines of its two sides make and no arc through it does.  Each is the
// index of its vertex and the corner point.
vector<std::pair<size_t, pt>>
corners (const vector<pt>& P, bool closed, double tol, double corner,
         double W)
{
  const size_t n = P.size ();
  vector<double> D (n + 1, 0);
  for (size_t i = 1; i <= n; i++)
  {
    D[i] = D[i-1] + ((i < n || closed) ? len (P[i % n] - P[i-1]) : 0);
  }
  if (! closed)
  {
    D.pop_back ();
  }
  const double L = D.back ();
  vector<double> turn (n, 0);
  for (size_t i = 0; i < n; i++)
  {
    if (! closed && (D[i] - W < 0 || D[i] + W > L))
    {
      continue;
    }
    const pt b = P[i] - along (P, D, closed, D[i] - W);
    const pt f = along (P, D, closed, D[i] + W) - P[i];
    turn[i] = std::atan2 (std::abs (cross (b, f)), dot (b, f));
  }

  // The peak of each run of points turning more than CORNER, a run broken
  // where it does not or where two points lie more than 2 W apart
  auto gap = [&] (size_t i)
  {
    const size_t h = (i + n - 1) % n;
    return (i == 0 && ! closed) || D[i] - D[h] > 2 * W
           || (i == 0 && L - D[h] > 2 * W);
  };
  auto breaks = [&] (size_t i) { return turn[i] <= corner || gap (i); };
  vector<size_t> cand;
  size_t start = 0;
  if (closed)
  {
    while (start < n && ! breaks (start))
    {
      start++;
    }
    if (start == n)
    {
      return {};
    }
  }
  for (size_t k = 0; k < n; )
  {
    const size_t i = (start + k) % n;
    if (turn[i] <= corner)
    {
      k++;
      continue;
    }
    size_t best = i;
    size_t j = k + 1;
    while (j < n && turn[(start + j) % n] > corner && ! gap ((start + j) % n))
    {
      if (turn[(start + j) % n] > turn[best])
      {
        best = (start + j) % n;
      }
      j++;
    }
    cand.push_back (best);
    k = j;
  }
  std::sort (cand.begin (), cand.end ());

  vector<std::pair<size_t, pt>> out;
  for (size_t c = 0; c < cand.size (); c++)
  {
    const size_t i = cand[c];
    const double si = D[i];
    double back = L, ahead = L;
    if (cand.size () > 1)
    {
      const size_t p = cand[(c + cand.size () - 1) % cand.size ()];
      const size_t q = cand[(c + 1) % cand.size ()];
      back = si - D[p];
      ahead = D[q] - si;
      if (closed)
      {
        back = (back <= 0) ? back + L : back;
        ahead = (ahead <= 0) ? ahead + L : ahead;
      }
    }
    if (! closed)
    {
      back = std::min (back, si);
      ahead = std::min (ahead, L - si);
    }
    const double lb = std::min (6 * W, back / 2 - W);
    const double la = std::min (6 * W, ahead / 2 - W);
    if (lb <= 0 || la <= 0)
    {
      continue;
    }
    pt O1, d1, O2, d2;
    fitline (P, D, closed, si - W - lb, si - W, O1, d1);
    fitline (P, D, closed, si + W, si + W + la, O2, d2);
    const double sn = cross (d1, d2);
    if (std::abs (std::asin (std::min (1.0, std::abs (sn)))) < corner / 2)
    {
      continue;
    }
    const double t = cross (O2 - O1, d2) / sn;
    const pt X = O1 + t * d1;
    const pt A = O1 + dot (along (P, D, closed, si - W - lb) - O1, d1) * d1;
    const pt B = O2 + dot (along (P, D, closed, si + W + la) - O2, d2) * d2;

    // The polygon near it, and the sharp corner and an arc against it
    vector<std::pair<double, pt>> zone;
    zone.emplace_back (si - W - lb, along (P, D, closed, si - W - lb));
    for (size_t k = 0; k < n; k++)
    {
      for (double w : {D[k] - L, D[k], D[k] + L})
      {
        if (w > si - W - lb && w < si + W + la && (closed || w == D[k]))
        {
          zone.emplace_back (w, P[k]);
        }
      }
    }
    zone.emplace_back (si + W + la, along (P, D, closed, si + W + la));
    std::sort (zone.begin (), zone.end (),
               [] (const std::pair<double, pt>& u,
                   const std::pair<double, pt>& v)
               { return u.first < v.first; });
    vector<pt> near;
    for (const auto& z : zone)
    {
      near.push_back (z.second);
    }
    bool sharp = true;
    for (size_t k = 0; k < near.size () && sharp; k++)
    {
      auto dist = [&] (const pt& q)
      {
        return std::min (segdist (q, A, X), segdist (q, X, B));
      };
      sharp = dist (near[k]) <= tol
              && (k + 1 == near.size ()
                  || dist (0.5 * (near[k] + near[k+1])) <= tol);
    }
    if (! sharp)
    {
      continue;
    }
    arc ca;
    bool round = arc3 (near.front (), P[i], near.back (), ca);
    for (size_t k = 0; k < near.size () && round; k++)
    {
      round = ca.dist (near[k]) <= tol
              && (k + 1 == near.size ()
                  || ca.dist (0.5 * (near[k] + near[k+1])) <= tol);
    }
    if (round)
    {
      continue;
    }
    out.emplace_back (i, X);
  }
  return out;
}

// The pieces that fit the polygon P, closed or open, mode 1 lines, 2 arcs,
// 3 curves: split at its corners, each stretch between them fitted on its
// own; a closed polygon with no corner that lies on one circle is two half
// circles
vector<piece>
fitpolygon (vector<pt> P, bool closed, int mode, double tol, double corner,
            double W)
{
  // Points closer than a hair of the tolerance are one
  vector<pt> Q;
  for (const pt& p : P)
  {
    if (Q.empty () || len (p - Q.back ()) > 1e-9 * tol)
    {
      Q.push_back (p);
    }
  }
  while (closed && Q.size () > 1 && len (Q.front () - Q.back ()) <= 1e-9 * tol)
  {
    Q.pop_back ();
  }
  P.swap (Q);
  const size_t n = P.size ();
  vector<piece> out;
  double size = 0;
  {
    double lo[2] = {INFINITY, INFINITY}, hi[2] = {-INFINITY, -INFINITY};
    for (const pt& p : P)
    {
      lo[0] = std::min (lo[0], p.x);
      lo[1] = std::min (lo[1], p.y);
      hi[0] = std::max (hi[0], p.x);
      hi[1] = std::max (hi[1], p.y);
    }
    size = std::hypot (hi[0] - lo[0], hi[1] - lo[1]);
  }
  if (n < 2 || (closed && n < 3))
  {
    return out;
  }
  vector<std::pair<size_t, pt>> C;
  if (n >= 3)
  {
    C = corners (P, closed, tol, corner, W);
  }

  if (closed && C.empty ())
  {
    // One circle through it all, as two half circles
    vector<double> D (n + 1, 0);
    for (size_t i = 1; i <= n; i++)
    {
      D[i] = D[i-1] + len (P[i % n] - P[i-1]);
    }
    // Through the vertices a third and two thirds of the way round, which
    // lie on the circle where the facets meet it
    const size_t i1 = std::lower_bound (D.begin (), D.end (), D[n] / 3)
                      - D.begin ();
    const size_t i2 = std::lower_bound (D.begin (), D.end (), 2 * D[n] / 3)
                      - D.begin ();
    arc c;
    if (mode >= 2 && i1 > 0 && i2 > i1 && i2 < n
        && arc3 (P[0], P[i1], P[i2], c))
    {
      bool ok = true;
      for (size_t i = 0; i < n && ok; i++)
      {
        const double di = std::abs (len (P[i] - c.C) - c.R);
        const pt mid = 0.5 * (P[i] + P[(i + 1) % n]);
        ok = di <= tol && std::abs (len (mid - c.C) - c.R) <= tol;
      }
      if (ok)
      {
        const pt A = P[0];
        const pt B = c.C + (c.C - A);
        c.B = B;
        c.sweep = M_PI;
        const pt M1 = c.point (M_PI / 2);
        arc d = c;
        d.A = B;
        const pt M2 = d.point (M_PI / 2);
        out.push_back (piece {1, {A, M1, B}, {}});
        out.push_back (piece {1, {B, M2, A}, {}});
        return out;
      }
    }
    // Otherwise from the point that turns most, round to it again
    size_t s0 = 0;
    double most = -1;
    for (size_t i = 0; i < n; i++)
    {
      const pt a = P[i] - P[(i + n - 1) % n], b = P[(i + 1) % n] - P[i];
      const double t = std::atan2 (std::abs (cross (a, b)), dot (a, b));
      if (t > most)
      {
        most = t;
        s0 = i;
      }
    }
    vector<pt> q;
    for (size_t k = 0; k <= n; k++)
    {
      q.push_back (P[(s0 + k) % n]);
    }
    out = fitrun (run (q), mode, tol, size);

    // Again from where the first piece ended, so that the seam falls where
    // the pieces change and does not cut one in two
    if (out.size () > 1)
    {
      const size_t s1 = (s0 + out.front ().e) % n;
      q.clear ();
      for (size_t k = 0; k <= n; k++)
      {
        q.push_back (P[(s1 + k) % n]);
      }
      const run rq (q);
      out = fitrun (rq, mode, tol, size);

      // A spline closing the loop arrives in the direction the loop leaves
      if (out.size () > 1 && out.back ().type == 2)
      {
        const piece& l = out.back ();
        const pt T1 = starttangent (out.front ());
        const pt T0 = endtangent (out[out.size () - 2]);
        piece p;
        if (splinefit (rq, l.b, l.e, l.P.front (), l.P.back (), &T0, &T1,
                       tol, p))
        {
          p.b = l.b;
          p.e = l.e;
          out.back () = p;
        }
      }
    }
    return out;
  }

  // Stretch by stretch between the corners, or from end to end
  vector<size_t> at;
  vector<pt> X;
  for (const auto& c : C)
  {
    at.push_back (c.first);
    X.push_back (c.second);
  }
  if (! closed)
  {
    at.insert (at.begin (), 0);
    X.insert (X.begin (), P[0]);
    at.push_back (n - 1);
    X.push_back (P[n-1]);
  }
  const size_t nc = at.size ();
  const size_t ns = closed ? nc : nc - 1;
  for (size_t k = 0; k < ns; k++)
  {
    const size_t i0 = at[k], i1 = at[(k + 1) % nc];
    vector<pt> q = {X[k]};
    for (size_t i = (i0 + 1) % n; i != i1; i = (i + 1) % n)
    {
      if (len (P[i] - q.back ()) > 1e-9 * tol)
      {
        q.push_back (P[i]);
      }
    }
    if (len (X[(k + 1) % nc] - q.back ()) > 1e-9 * tol || q.size () == 1)
    {
      q.push_back (X[(k + 1) % nc]);
    }
    else
    {
      q.back () = X[(k + 1) % nc];
    }
    const vector<piece> p = fitrun (run (q), mode, tol, size);
    out.insert (out.end (), p.begin (), p.end ());
  }
  return out;
}

Cell
topieces (const vector<piece>& pieces)
{
  Cell c (1, pieces.size ());
  for (size_t i = 0; i < pieces.size (); i++)
  {
    const piece& p = pieces[i];
    octave_scalar_map m;
    m.assign ("type", p.type == 0 ? "line" : p.type == 1 ? "arc" : "spline");
    Matrix P (p.P.size (), 2);
    for (size_t k = 0; k < p.P.size (); k++)
    {
      P(k,0) = p.P[k].x;
      P(k,1) = p.P[k].y;
    }
    m.assign ("points", P);
    RowVector K (p.K.size ());
    for (size_t k = 0; k < p.K.size (); k++)
    {
      K(k) = p.K[k];
    }
    m.assign ("knots", K);
    c(i) = m;
  }
  return c;
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

  // PIECES = __mesh__ ('fit', caller, P, CLOSED, MODE, TOL, CORNER, W): the
  // lines, arcs and splines that fit the polygon P, N-by-2, within TOL
  else if (cmd == "fit")
  {
    const Matrix P = args(2).matrix_value ();
    vector<pt> q (P.rows ());
    for (octave_idx_type i = 0; i < P.rows (); i++)
    {
      q[i] = pt {P(i,0), P(i,1)};
    }
    return ovl (topieces (fitpolygon (q, args(3).bool_value (),
                                      args(4).int_value (),
                                      args(5).double_value (),
                                      args(6).double_value (),
                                      args(7).double_value ())));
  }

  error ("__mesh__: unknown command '%s'.", cmd.c_str ());
}
