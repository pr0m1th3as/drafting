/*
Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>

This file is part of the drafting package for GNU Octave.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see <http://www.gnu.org/licenses/>.
*/

// ASCII DXF reading and writing for the geom classes and draw.Drawing.
//
// The writer takes the objects themselves and reads their properties; the
// reader builds objects through their constructors.  Nothing crosses into
// Octave as an entity list: the records below exist only inside this file.
//
//   __dxf__ ('write', FILE, OBJS, OPTS, CALLER)
//     OBJS is a cell of geom objects or a cell holding one draw.Drawing; OPTS
//     a cell of Name/Value pairs.  Every argument is validated here and every
//     error is raised under CALLER.
//   [C, LAYERS, TYPES, LABELS, COUNTS] = __dxf__ ('readgeom', FILE, CALLER)
//     C a row cell of geom objects, one per entity or per group the package
//     wrote; LAYERS and TYPES the layer and DXF type of each; LABELS and
//     COUNTS what was skipped, counted by label.
//   [D, LABELS, COUNTS] = __dxf__ ('readdraw', FILE, CALLER)

#include <octave/oct.h>
#include <octave/parse.h>
#include <octave/interpreter.h>
#include <octave/oct-map.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <list>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using namespace std;

static string g_caller = "__dxf__";

// Geometry is compared at this scale in millimetres
static const double TOL = 1e-9;

////////////////////////////////////////////////////////////////////////////////
// Vectors and frames

struct V3
{
  double x, y, z;
};

static inline V3
v3 (double x, double y, double z)
{
  V3 v = {x, y, z};
  return v;
}

static inline V3 operator + (const V3& a, const V3& b)
{ return v3 (a.x + b.x, a.y + b.y, a.z + b.z); }
static inline V3 operator - (const V3& a, const V3& b)
{ return v3 (a.x - b.x, a.y - b.y, a.z - b.z); }
static inline V3 operator * (const V3& a, double s)
{ return v3 (a.x * s, a.y * s, a.z * s); }
static inline V3 operator * (double s, const V3& a)
{ return v3 (a.x * s, a.y * s, a.z * s); }

static inline double
dot (const V3& a, const V3& b)
{
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

static inline V3
cross (const V3& a, const V3& b)
{
  return v3 (a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z,
             a.x * b.y - a.y * b.x);
}

static inline double
norm (const V3& a)
{
  return sqrt (dot (a, a));
}

static inline V3
unit (const V3& a)
{
  double n = norm (a);
  return n > 0 ? a * (1.0 / n) : a;
}

// A coordinate system: origin and three orthonormal axes
struct Frame
{
  V3 o, x, y, n;
};

static inline V3
toworld (const Frame& f, const V3& p)
{
  return f.o + f.x * p.x + f.y * p.y + f.n * p.z;
}

static inline V3
tolocal (const Frame& f, const V3& w)
{
  V3 d = w - f.o;
  return v3 (dot (d, f.x), dot (d, f.y), dot (d, f.n));
}

static Frame
worldframe ()
{
  Frame f;
  f.o = v3 (0, 0, 0);
  f.x = v3 (1, 0, 0);
  f.y = v3 (0, 1, 0);
  f.n = v3 (0, 0, 1);
  return f;
}

// DXF's arbitrary axis algorithm: the x axis a reader derives from a normal
static void
ocsaxes (const V3& normal, V3& ax, V3& ay)
{
  V3 n = unit (normal);
  if (fabs (n.x) < 1.0 / 64 && fabs (n.y) < 1.0 / 64)
    ax = unit (cross (v3 (0, 1, 0), n));
  else
    ax = unit (cross (v3 (0, 0, 1), n));
  ay = unit (cross (n, ax));
}

// The object coordinate system of a normal, its origin at the world origin
static Frame
ocsframe (const V3& normal)
{
  Frame f;
  f.o = v3 (0, 0, 0);
  f.n = unit (normal);
  ocsaxes (f.n, f.x, f.y);
  return f;
}

// Whether a normal is the world z axis, either way up
static inline bool
isz (const V3& n)
{
  V3 u = unit (n);
  return fabs (u.x) < 1e-12 && fabs (u.y) < 1e-12;
}

// The bulge of the arc from S through M to E, all in one plane, as seen from
// the plane's normal: positive for an arc running anticlockwise
static double
bulge3 (double sx, double sy, double mx, double my, double ex, double ey)
{
  double cx = ex - sx, cy = ey - sy;
  double c2 = cx * cx + cy * cy;
  if (c2 == 0)
    return 0;
  double cr = cx * (my - sy) - cy * (mx - sx);
  return -2 * cr / c2;
}

// Centre and radius of the circle through three points in a plane
static bool
circle3 (const V3& a, const V3& m, const V3& b, V3& c, double& r, V3& n)
{
  V3 u = m - a, w = b - a;
  V3 k = cross (u, w);
  double kk = dot (k, k);
  if (kk <= 1e-24 * dot (u, u) * dot (w, w))
    return false;
  // Circumcentre of the triangle a, m, b
  V3 cc = a + (cross (k, u) * dot (w, w) + cross (w, k) * dot (u, u))
              * (1.0 / (2 * kk));
  c = cc;
  r = norm (a - cc);
  // Anticlockwise from a through m to b as seen from n
  n = unit (cross (m - a, b - m));
  return true;
}

static inline double
deg (double rad)
{
  return rad * 180.0 / M_PI;
}

static inline double
rad (double d)
{
  return d * M_PI / 180.0;
}

////////////////////////////////////////////////////////////////////////////////
// Octave helpers

static octave_value
prop (const octave_value& obj, const string& name)
{
  std::list<octave_value_list> idx;
  idx.push_back (octave_value_list (octave_value (name)));
  octave_value tmp = obj;
  return tmp.subsref (".", idx);
}

static octave_value
setprop (const octave_value& obj, const string& name, const octave_value& v)
{
  std::list<octave_value_list> idx;
  idx.push_back (octave_value_list (octave_value (name)));
  octave_value tmp = obj;
  return tmp.subsasgn (".", idx, v);
}

static octave_value
call (const string& fcn, const octave_value_list& args)
{
  octave_value_list r = octave::feval (fcn, args, 1);
  return r.length () > 0 ? r(0) : octave_value ();
}

// A static method, which feval does not find by its qualified name
static octave_value
callstatic (const string& fcn, const octave_value_list& args)
{
  octave_value fh = call ("str2func", ovl (fcn));
  octave_value_list r = octave::feval (fh, args, 1);
  return r.length () > 0 ? r(0) : octave_value ();
}

static void
recover ()
{
  octave::interpreter *interp = octave::interpreter::the_interpreter ();
  if (interp)
    interp->recover_from_exception ();
}

static inline bool
isclass (const octave_value& v, const char *name)
{
  return v.class_name () == name;
}

static V3
row3 (const Matrix& m, octave_idx_type i)
{
  return v3 (m(i,0), m.cols () > 1 ? m(i,1) : 0, m.cols () > 2 ? m(i,2) : 0);
}

static Matrix
rowmat (const V3& p)
{
  Matrix m (1, 3);
  m(0,0) = p.x;
  m(0,1) = p.y;
  m(0,2) = p.z;
  return m;
}

static Frame
ucsframe (const octave_value& U)
{
  Frame f;
  f.o = row3 (prop (U, "Origin").matrix_value (), 0);
  f.x = row3 (prop (U, "XAxis").matrix_value (), 0);
  f.y = row3 (prop (U, "YAxis").matrix_value (), 0);
  f.n = row3 (prop (U, "Normal").matrix_value (), 0);
  return f;
}

static octave_value
ucsobject (const Frame& f)
{
  if (fabs (f.o.x) + fabs (f.o.y) + fabs (f.o.z) == 0
      && f.x.x == 1 && f.n.z == 1 && f.y.y == 1)
    return call ("geom.UCS", octave_value_list ());
  return call ("geom.UCS", ovl (rowmat (f.n), rowmat (f.o),
                                rowmat (f.o + f.x)));
}

static string
lower (string s)
{
  for (auto& c : s)
    c = tolower (c);
  return s;
}

static string
upper (string s)
{
  for (auto& c : s)
    c = toupper (c);
  return s;
}

static string
trim (const string& s)
{
  size_t a = s.find_first_not_of (" \t\r");
  if (a == string::npos)
    return "";
  size_t b = s.find_last_not_of (" \t\r");
  return s.substr (a, b - a + 1);
}

////////////////////////////////////////////////////////////////////////////////
// Writing

typedef pair<int, string> Tag;

static string
fmtnum (double v)
{
  if (fabs (v) < 1e-14)
    return "0.0";
  char buf[40];
  snprintf (buf, sizeof (buf), "%.15g", v);
  string s (buf);
  if (s.find_first_of (".eEni") == string::npos)
    s += ".0";
  return s;
}

// Octave holds text as UTF-8; the file carries every character outside ASCII
// as a \U+XXXX escape, so it reads the same whatever the reader's code page
static string
encodetext (const string& s)
{
  string out;
  size_t i = 0;
  while (i < s.size ())
  {
    unsigned char c = s[i];
    if (c < 0x80)
    {
      out += c;
      i++;
      continue;
    }
    unsigned cp;
    int len;
    if ((c & 0xE0) == 0xC0)
    {
      cp = c & 0x1F;
      len = 2;
    }
    else if ((c & 0xF0) == 0xE0)
    {
      cp = c & 0x0F;
      len = 3;
    }
    else if ((c & 0xF8) == 0xF0)
    {
      cp = c & 0x07;
      len = 4;
    }
    else
    {
      out += '?';
      i++;
      continue;
    }
    if (i + len > s.size ())
    {
      out += '?';
      break;
    }
    for (int k = 1; k < len; k++)
      cp = (cp << 6) | (static_cast<unsigned char> (s[i+k]) & 0x3F);
    i += len;
    char buf[16];
    if (cp > 0xFFFF)
    {
      cp -= 0x10000;
      snprintf (buf, sizeof (buf), "\\U+%04X", 0xD800 + (cp >> 10));
      out += buf;
      snprintf (buf, sizeof (buf), "\\U+%04X", 0xDC00 + (cp & 0x3FF));
      out += buf;
    }
    else
    {
      snprintf (buf, sizeof (buf), "\\U+%04X", cp);
      out += buf;
    }
  }
  return out;
}

// Layer, line type and colour, which every entity carries
struct Attr
{
  string layer = "0";
  string ltype = "CONTINUOUS";
  int colour = 256;
};

// One record to emit.  Handles and owners are given when the file is laid
// out, since an entity is written after the tables that name its owner.
struct Item
{
  string type;
  Attr a;
  vector<Tag> data;
  vector<Tag> xdata;
  vector<Item> follow;
  int group = -1;
  string handle;
};

class Body
{
public:
  Body (vector<Tag>& t, bool r12) : m_t (t), m_r12 (r12) { }
  void marker (const char *s)
  {
    if (! m_r12)
      m_t.push_back (Tag (100, s));
  }
  void str (int c, const string& s) { m_t.push_back (Tag (c, s)); }
  void num (int c, double v) { m_t.push_back (Tag (c, fmtnum (v))); }
  void integ (int c, long v) { m_t.push_back (Tag (c, to_string (v))); }
  void pt (int c, const V3& p)
  {
    num (c, p.x);
    num (c + 10, p.y);
    num (c + 20, p.z);
  }
  void pt2 (int c, double x, double y)
  {
    num (c, x);
    num (c + 10, y);
  }
  // The normal of a planar entity, omitted where it is the world z axis
  void normal (const V3& n)
  {
    if (! (isz (n) && n.z > 0))
      pt (210, unit (n));
  }
private:
  vector<Tag>& m_t;
  bool m_r12;
};

// A vertex of a polyline in its object coordinate system
struct PV
{
  double x, y, b;
};

// An edge of a hatch boundary that is not a polyline, in the hatch's OCS
struct Edge
{
  int kind;                  // 1 line, 2 arc, 4 spline
  double x1, y1, x2, y2;     // line ends
  double cx, cy, r, a0, a1;  // arc, degrees, anticlockwise from a0 to a1
  bool ccw;
  int degree;
  vector<double> knots, weights, px, py;
};

struct Loop
{
  bool outer;
  bool poly;
  vector<PV> verts;
  vector<Edge> edges;
};

// What a hatch pattern is made of, kept in step with geom.hatchlines
struct Pattern
{
  const char *name;
  vector<double> angles;
  double spacing;
};

static const vector<Pattern>&
patterns ()
{
  static const vector<Pattern> p = {
    {"ANSI31", {45}, 3.175},
    {"ANSI32", {45}, 6.35},
    {"ANSI37", {45, 135}, 3.175},
    {"HORIZONTAL", {0}, 3.175},
    {"VERTICAL", {90}, 3.175},
    {"CROSS", {0, 90}, 3.175}};
  return p;
}

static const Pattern *
findpattern (const string& name)
{
  for (const auto& p : patterns ())
    if (upper (name) == p.name)
      return &p;
  return nullptr;
}

struct WOpts
{
  bool r12 = false;
  double ltscale = 1;
  bool explode = false;
  bool expand = false;
  double dimscale = 1;
  bool fill = false;
};

class Writer
{
public:
  WOpts opt;

  vector<Item> model;
  struct Block
  {
    string name;
    bool anon;
    vector<Item> items;
    string rec, beg, end;
  };
  vector<Block> blocks;
  struct Group
  {
    vector<int> members;
    vector<Tag> xdata;
    string handle, name;
  };
  vector<Group> groups;
  vector<string> layers;
  vector<string> ltypes;
  int ndim = 0;

  Writer (const WOpts& o) : opt (o) { uselayer ("0"); }

  void uselayer (const string& s)
  {
    for (const auto& l : layers)
      if (lower (l) == lower (s))
        return;
    layers.push_back (s);
  }

  void useltype (const string& s)
  {
    string u = upper (s);
    if (u == "CONTINUOUS" || u == "BYLAYER" || u == "BYBLOCK")
      return;
    for (const auto& l : ltypes)
      if (upper (l) == u)
        return;
    ltypes.push_back (s);
  }

  Item start (const char *type, const Attr& a)
  {
    Item it;
    it.type = type;
    it.a = a;
    uselayer (a.layer);
    useltype (a.ltype);
    return it;
  }

  // Entities, each appended to DEST

  void line (vector<Item>& dest, const Attr& a, const V3& p, const V3& q)
  {
    Item it = start ("LINE", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbLine");
    b.pt (10, p);
    b.pt (11, q);
    dest.push_back (it);
  }

  void point (vector<Item>& dest, const Attr& a, const V3& p)
  {
    Item it = start ("POINT", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbPoint");
    b.pt (10, p);
    dest.push_back (it);
  }

  // A circle given in world coordinates, on the plane square to N
  void circle (vector<Item>& dest, const Attr& a, const V3& c, double r,
               const V3& n)
  {
    Frame f = ocsframe (n);
    Item it = start ("CIRCLE", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbCircle");
    b.pt (10, tolocal (f, c));
    b.num (40, r);
    b.normal (n);
    dest.push_back (it);
  }

  // An arc in world coordinates, anticlockwise about N from A0 to A1, the
  // angles in degrees in the object coordinate system of N
  void arc (vector<Item>& dest, const Attr& a, const V3& c, double r,
            double a0, double a1, const V3& n)
  {
    Frame f = ocsframe (n);
    Item it = start ("ARC", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbCircle");
    b.pt (10, tolocal (f, c));
    b.num (40, r);
    b.normal (n);
    b.marker ("AcDbArc");
    b.num (50, fmod (fmod (a0, 360) + 360, 360));
    b.num (51, fmod (fmod (a1, 360) + 360, 360));
    dest.push_back (it);
  }

  // The arc from S through M to E, on its own plane unless N is given
  void arc3 (vector<Item>& dest, const Attr& a, const V3& s, const V3& m,
             const V3& e, const V3 *plane = nullptr)
  {
    V3 c, n;
    double r;
    if (! circle3 (s, m, e, c, r, n))
    {
      line (dest, a, s, e);
      return;
    }
    if (plane)
    {
      // Keep the arc on the plane it shares with its neighbours, running
      // anticlockwise about that plane's normal whichever way it turns
      if (dot (n, *plane) < 0)
      {
        Frame f = ocsframe (*plane);
        V3 cs = tolocal (f, c), ss = tolocal (f, s), es = tolocal (f, e);
        double as = deg (atan2 (ss.y - cs.y, ss.x - cs.x));
        double ae = deg (atan2 (es.y - cs.y, es.x - cs.x));
        arc (dest, a, c, r, ae, as, *plane);
        return;
      }
      n = *plane;
    }
    Frame f = ocsframe (n);
    V3 cs = tolocal (f, c), ss = tolocal (f, s), es = tolocal (f, e);
    double as = deg (atan2 (ss.y - cs.y, ss.x - cs.x));
    double ae = deg (atan2 (es.y - cs.y, es.x - cs.x));
    arc (dest, a, c, r, as, ae, n);
  }

  void ellipse (vector<Item>& dest, const Attr& a, const V3& c,
                const V3& major, double ratio, double p0, double p1,
                const V3& n)
  {
    Item it = start ("ELLIPSE", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbEllipse");
    b.pt (10, c);
    b.pt (11, major);
    b.pt (210, unit (n));
    b.num (40, ratio);
    b.num (41, p0);
    b.num (42, p1);
    dest.push_back (it);
  }

  // A polyline in the object coordinate system of N, at elevation ELEV
  void lwpoly (vector<Item>& dest, const Attr& a, const vector<PV>& v,
               bool closed, double elev, const V3& n)
  {
    if (opt.r12)
    {
      Item it = start ("POLYLINE", a);
      Body b (it.data, true);
      b.integ (66, 1);
      b.integ (70, closed ? 1 : 0);
      b.pt (10, v3 (0, 0, elev));
      b.normal (n);
      for (const auto& p : v)
      {
        Item vx = start ("VERTEX", a);
        Body bv (vx.data, true);
        bv.pt (10, v3 (p.x, p.y, elev));
        if (p.b != 0)
          bv.num (42, p.b);
        it.follow.push_back (vx);
      }
      it.follow.push_back (start ("SEQEND", a));
      dest.push_back (it);
      return;
    }
    Item it = start ("LWPOLYLINE", a);
    Body b (it.data, false);
    b.marker ("AcDbPolyline");
    b.integ (90, v.size ());
    b.integ (70, closed ? 1 : 0);
    if (elev != 0)
      b.num (38, elev);
    for (const auto& p : v)
    {
      b.pt2 (10, p.x, p.y);
      if (p.b != 0)
        b.num (42, p.b);
    }
    b.normal (n);
    dest.push_back (it);
  }

  void spline (vector<Item>& dest, const Attr& a, int degree,
               const vector<double>& knots, const vector<double>& weights,
               const vector<V3>& cps, const vector<V3>& fit,
               const V3 *t1, const V3 *t2, bool closed, const V3 *planar)
  {
    bool rational = false;
    for (double w : weights)
      if (w != 1)
        rational = true;
    Item it = start ("SPLINE", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbSpline");
    if (planar)
      b.pt (210, unit (*planar));
    b.integ (70, (closed ? 1 : 0) | (rational ? 4 : 0) | (planar ? 8 : 0));
    b.integ (71, degree);
    b.integ (72, knots.size ());
    b.integ (73, cps.size ());
    b.integ (74, fit.size ());
    b.num (42, 1e-10);
    b.num (43, 1e-10);
    if (! fit.empty ())
      b.num (44, 1e-10);
    if (t1)
      b.pt (12, *t1);
    if (t2)
      b.pt (13, *t2);
    for (double k : knots)
      b.num (40, k);
    if (rational)
      for (double w : weights)
        b.num (41, w);
    for (const auto& p : cps)
      b.pt (10, p);
    for (const auto& p : fit)
      b.pt (11, p);
    dest.push_back (it);
  }

  void text (vector<Item>& dest, const Attr& a, const V3& p, double h,
             const string& s, double rot)
  {
    Item it = start ("TEXT", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbText");
    b.pt (10, p);
    b.num (40, h);
    b.str (1, encodetext (s));
    if (rot != 0)
      b.num (50, rot);
    b.marker ("AcDbText");
    dest.push_back (it);
  }

  void insert (vector<Item>& dest, const Attr& a, const string& name,
               const V3& p, double scale, double rot)
  {
    Item it = start ("INSERT", a);
    Body b (it.data, opt.r12);
    b.marker ("AcDbBlockReference");
    b.str (2, name);
    b.pt (10, p);
    if (scale != 1)
    {
      b.num (41, scale);
      b.num (42, scale);
      b.num (43, scale);
    }
    if (rot != 0)
      b.num (50, rot);
    dest.push_back (it);
  }

  // A dimension from its six definition points, rows in the order of group
  // codes 10, 11, 13, 14, 15 and 16
  void dimension (vector<Item>& dest, const Attr& a, const Matrix& P,
                  int type, const string& txt, double rot,
                  const string& block)
  {
    Item it = start ("DIMENSION", a);
    Body b (it.data, opt.r12);
    auto p = [&] (int r) { return v3 (P(r,0), P(r,1), 0); };
    b.marker ("AcDbDimension");
    b.str (2, block);
    if (opt.r12)
    {
      b.str (3, "DRAFTING");
      int codes[6] = {10, 11, 13, 14, 15, 16};
      for (int k = 0; k < 6; k++)
        b.pt (codes[k], p (k));
      b.integ (70, type + 32);
      b.str (1, encodetext (txt));
      b.num (50, rot);
      dest.push_back (it);
      return;
    }
    b.pt (10, p (0));
    b.pt (11, p (1));
    b.integ (70, type + 32);
    b.str (1, encodetext (txt));
    b.str (3, "DRAFTING");
    switch (type)
    {
      case 0:
        b.marker ("AcDbAlignedDimension");
        b.pt (13, p (2));
        b.pt (14, p (3));
        b.num (50, rot);
        b.marker ("AcDbRotatedDimension");
        break;
      case 1:
        b.marker ("AcDbAlignedDimension");
        b.pt (13, p (2));
        b.pt (14, p (3));
        break;
      case 2:
        b.marker ("AcDb2LineAngularDimension");
        b.pt (13, p (2));
        b.pt (14, p (3));
        b.pt (15, p (4));
        b.pt (16, p (5));
        break;
      case 5:
        b.marker ("AcDb3PointAngularDimension");
        b.pt (13, p (2));
        b.pt (14, p (3));
        b.pt (15, p (4));
        break;
      case 3:
        b.marker ("AcDbDiametricDimension");
        b.pt (15, p (4));
        b.num (40, 0);
        break;
      case 4:
        b.marker ("AcDbRadialDimension");
        b.pt (15, p (4));
        b.num (40, 0);
        break;
      default:
        b.marker ("AcDbOrdinateDimension");
        b.pt (13, p (2));
        b.pt (14, p (3));
        break;
    }
    dest.push_back (it);
  }

  // A hatch over boundary loops in the object coordinate system of N
  void hatch (vector<Item>& dest, const Attr& a, const vector<Loop>& loops,
              const string& name, bool solid, double angle, double spacing,
              double elev, const V3& n)
  {
    Item it = start ("HATCH", a);
    Body b (it.data, false);
    b.marker ("AcDbHatch");
    b.pt (10, v3 (0, 0, elev));
    b.pt (210, unit (n));
    b.str (2, solid ? "SOLID" : upper (name));
    b.integ (70, solid ? 1 : 0);
    b.integ (71, 0);
    b.integ (91, loops.size ());
    for (const auto& L : loops)
    {
      b.integ (92, (L.outer ? 17 : 0) | (L.poly ? 2 : 0));
      if (L.poly)
      {
        bool hasb = false;
        for (const auto& v : L.verts)
          if (v.b != 0)
            hasb = true;
        b.integ (72, hasb ? 1 : 0);
        b.integ (73, 1);
        b.integ (93, L.verts.size ());
        for (const auto& v : L.verts)
        {
          b.pt2 (10, v.x, v.y);
          if (hasb)
            b.num (42, v.b);
        }
      }
      else
      {
        b.integ (93, L.edges.size ());
        for (const auto& e : L.edges)
        {
          b.integ (72, e.kind);
          if (e.kind == 1)
          {
            b.pt2 (10, e.x1, e.y1);
            b.pt2 (11, e.x2, e.y2);
          }
          else if (e.kind == 2)
          {
            b.pt2 (10, e.cx, e.cy);
            b.num (40, e.r);
            // A clockwise arc is stored by the complements of its
            // angles, swapped, as DXF has it
            if (e.ccw)
            {
              b.num (50, e.a0);
              b.num (51, e.a1);
            }
            else
            {
              b.num (50, 360 - e.a1);
              b.num (51, 360 - e.a0);
            }
            b.integ (73, e.ccw ? 1 : 0);
          }
          else
          {
            bool rat = false;
            for (double w : e.weights)
              if (w != 1)
                rat = true;
            b.integ (94, e.degree);
            b.integ (73, rat ? 1 : 0);
            b.integ (74, 0);
            b.integ (95, e.knots.size ());
            b.integ (96, e.px.size ());
            for (double k : e.knots)
              b.num (40, k);
            for (size_t k = 0; k < e.px.size (); k++)
            {
              b.pt2 (10, e.px[k], e.py[k]);
              if (rat)
                b.num (42, e.weights[k]);
            }
          }
        }
      }
      b.integ (97, 0);
    }
    b.integ (75, 0);
    b.integ (76, 1);
    if (! solid)
    {
      const Pattern *p = findpattern (name);
      double base = p ? p->spacing : spacing;
      b.num (52, angle);
      b.num (41, spacing / base);
      b.integ (77, 0);
      vector<double> ang = p ? p->angles : vector<double> {45};
      b.integ (78, ang.size ());
      for (double a0 : ang)
      {
        double phi = rad (a0 + angle);
        b.num (53, a0 + angle);
        b.num (43, 0);
        b.num (44, 0);
        b.num (45, -spacing * sin (phi));
        b.num (46, spacing * cos (phi));
        b.integ (79, 0);
      }
    }
    b.integ (98, 0);
    dest.push_back (it);
  }

  // The DRAFTING extended data: a class name for a group, then a frame
  static vector<Tag> xdataframe (const string& cls, const Frame *f,
                                 bool withnormal)
  {
    vector<Tag> x;
    Body b (x, false);
    b.str (1001, "DRAFTING");
    if (! cls.empty ())
      b.str (1000, cls);
    if (f)
    {
      b.pt (1011, f->o);
      b.pt (1013, f->x);
      if (withnormal)
        b.pt (1013, f->n);
    }
    return x;
  }

  string text ();

private:
  int m_next = 1;
  string hnew ()
  {
    char b[24];
    snprintf (b, sizeof (b), "%X", m_next++);
    return b;
  }
  void emitr2000 (ostringstream& s);
  void emitr12 (ostringstream& s);
};

static void
put (ostringstream& s, int code, const string& v)
{
  char b[16];
  snprintf (b, sizeof (b), "%3d\n", code);
  s << b << v << "\n";
}

static void
putn (ostringstream& s, int code, double v)
{
  put (s, code, fmtnum (v));
}

static void
puti (ostringstream& s, int code, long v)
{
  put (s, code, to_string (v));
}

static void
putp (ostringstream& s, int code, const V3& p)
{
  putn (s, code, p.x);
  putn (s, code + 10, p.y);
  putn (s, code + 20, p.z);
}

// One line-type table record.  A name the package defines carries its dash
// pattern; one it does not is named only, as a file names a line type the
// receiving installation already holds.
static void
ltyperecord (ostringstream& s, const string& name, bool r12,
             const string& handle, const string& table)
{
  put (s, 0, "LTYPE");
  if (! r12)
  {
    put (s, 5, handle);
    put (s, 330, table);
    put (s, 100, "AcDbSymbolTableRecord");
    put (s, 100, "AcDbLinetypeTableRecord");
  }
  put (s, 2, name);
  puti (s, 70, 0);
  vector<double> pat;
  string descr = "";
  string u = upper (name);
  if (u != "CONTINUOUS" && u != "BYLAYER" && u != "BYBLOCK")
  {
    descr = name;
    try
    {
      octave_value_list r = octave::feval ("draw.linetype", ovl (name), 2);
      Matrix m = r(0).matrix_value ();
      for (octave_idx_type k = 0; k < m.numel (); k++)
        pat.push_back (m(k));
      if (r.length () > 1 && r(1).is_string ())
        descr = r(1).string_value ();
    }
    catch (const octave::execution_exception&)
    {
      recover ();
      pat.clear ();
    }
  }
  else if (u == "CONTINUOUS")
    descr = "Solid line";
  put (s, 3, descr);
  puti (s, 72, 65);
  puti (s, 73, pat.size ());
  double total = 0;
  for (double d : pat)
    total += fabs (d);
  putn (s, 40, total);
  for (double d : pat)
  {
    putn (s, 49, d);
    if (! r12)
      puti (s, 74, 0);
  }
}

static void
dimstylebody (ostringstream& s, bool drafting)
{
  if (drafting)
  {
    // DIMTSZ non-zero is what makes a reader draw the 45-degree obliques
    // this package draws itself, rather than filled arrowheads
    putn (s, 40, 1);       // DIMSCALE
    putn (s, 41, 2.5);     // DIMASZ
    putn (s, 42, 0.625);   // DIMEXO
    putn (s, 44, 1.25);    // DIMEXE
    putn (s, 140, 2.5);    // DIMTXT
    putn (s, 141, 2.5);    // DIMCEN
    putn (s, 142, 1.25);   // DIMTSZ
    putn (s, 147, 0.625);  // DIMGAP
    puti (s, 77, 1);       // DIMTAD
  }
  else
  {
    putn (s, 40, 1);
    putn (s, 41, 2.5);
    putn (s, 42, 0.625);
    putn (s, 44, 1.25);
    putn (s, 140, 2.5);
    putn (s, 141, 2.5);
    putn (s, 147, 0.625);
  }
}

// The common head of an entity, then its own tags and its extended data
static void
emititem (ostringstream& s, const Item& it, bool r12, const string& owner,
          const string& reactor)
{
  put (s, 0, it.type);
  if (! r12)
  {
    put (s, 5, it.handle);
    if (! reactor.empty ())
    {
      put (s, 102, "{ACAD_REACTORS");
      put (s, 330, reactor);
      put (s, 102, "}");
    }
    put (s, 330, owner);
    put (s, 100, "AcDbEntity");
  }
  put (s, 8, it.a.layer);
  if (upper (it.a.ltype) != "CONTINUOUS")
    put (s, 6, it.a.ltype);
  if (it.a.colour != 256)
    puti (s, 62, it.a.colour);
  for (const auto& t : it.data)
    put (s, t.first, t.second);
  for (const auto& t : it.xdata)
    put (s, t.first, t.second);
  for (const auto& f : it.follow)
  {
    put (s, 0, f.type);
    put (s, 8, f.a.layer);
    if (upper (f.a.ltype) != "CONTINUOUS")
      put (s, 6, f.a.ltype);
    if (f.a.colour != 256)
      puti (s, 62, f.a.colour);
    for (const auto& t : f.data)
      put (s, t.first, t.second);
  }
}

void
Writer::emitr12 (ostringstream& s)
{
  put (s, 0, "SECTION");
  put (s, 2, "HEADER");
  put (s, 9, "$ACADVER");
  put (s, 1, "AC1009");
  put (s, 9, "$INSUNITS");
  puti (s, 70, 4);
  // Without this the dash lengths in the line-type table are scaled by
  // whatever the receiving installation has set
  put (s, 9, "$LTSCALE");
  putn (s, 40, opt.ltscale);
  put (s, 0, "ENDSEC");

  put (s, 0, "SECTION");
  put (s, 2, "TABLES");
  put (s, 0, "TABLE");
  put (s, 2, "LTYPE");
  puti (s, 70, 1 + ltypes.size ());
  ltyperecord (s, "CONTINUOUS", true, "", "");
  for (const auto& l : ltypes)
    ltyperecord (s, l, true, "", "");
  put (s, 0, "ENDTAB");
  put (s, 0, "TABLE");
  put (s, 2, "LAYER");
  puti (s, 70, layers.size ());
  for (const auto& l : layers)
  {
    put (s, 0, "LAYER");
    put (s, 2, l);
    puti (s, 70, 0);
    puti (s, 62, 7);
    put (s, 6, "CONTINUOUS");
  }
  put (s, 0, "ENDTAB");
  put (s, 0, "TABLE");
  put (s, 2, "APPID");
  puti (s, 70, 2);
  put (s, 0, "APPID");
  put (s, 2, "ACAD");
  puti (s, 70, 0);
  put (s, 0, "APPID");
  put (s, 2, "DRAFTING");
  puti (s, 70, 0);
  put (s, 0, "ENDTAB");
  put (s, 0, "TABLE");
  put (s, 2, "DIMSTYLE");
  puti (s, 70, 1);
  put (s, 0, "DIMSTYLE");
  put (s, 2, "DRAFTING");
  puti (s, 70, 0);
  dimstylebody (s, true);
  put (s, 0, "ENDTAB");
  put (s, 0, "ENDSEC");

  put (s, 0, "SECTION");
  put (s, 2, "BLOCKS");
  for (const auto& B : blocks)
  {
    put (s, 0, "BLOCK");
    put (s, 8, "0");
    put (s, 2, B.name);
    puti (s, 70, B.anon ? 1 : 0);
    putp (s, 10, v3 (0, 0, 0));
    put (s, 3, B.name);
    for (const auto& it : B.items)
      emititem (s, it, true, "", "");
    put (s, 0, "ENDBLK");
    put (s, 8, "0");
  }
  put (s, 0, "ENDSEC");

  put (s, 0, "SECTION");
  put (s, 2, "ENTITIES");
  for (const auto& it : model)
    emititem (s, it, true, "", "");
  put (s, 0, "ENDSEC");
  put (s, 0, "EOF");
}

void
Writer::emitr2000 (ostringstream& s)
{
  // Handles, given in the order the file is laid out
  string tVport = hnew (), tLtype = hnew (), tLayer = hnew (), tStyle = hnew ();
  string tView = hnew (), tUcs = hnew (), tAppid = hnew (), tDimst = hnew ();
  string tBrec = hnew ();
  string rVport = hnew ();
  vector<string> rLtype;
  for (size_t k = 0; k < 3 + ltypes.size (); k++)
    rLtype.push_back (hnew ());
  vector<string> rLayer;
  for (size_t k = 0; k < layers.size (); k++)
    rLayer.push_back (hnew ());
  string rStyle = hnew (), rAcad = hnew (), rDrafting = hnew ();
  string rDimStd = hnew (), rDimDraft = hnew ();
  string recModel = hnew (), recPaper = hnew ();
  for (auto& B : blocks)
    B.rec = hnew ();
  string oRoot = hnew (), oGroup = hnew (), oLayout = hnew ();
  string oMline = hnew (), oPlot = hnew (), oPstyle = hnew ();
  string oHolder = hnew (), oMlStd = hnew (), oLayModel = hnew ();
  string oLayPaper = hnew ();
  string bModel = hnew (), eModel = hnew (), bPaper = hnew (), ePaper = hnew ();
  for (auto& B : blocks)
  {
    B.beg = hnew ();
    for (auto& it : B.items)
      it.handle = hnew ();
    B.end = hnew ();
  }
  for (auto& it : model)
    it.handle = hnew ();
  for (size_t k = 0; k < groups.size (); k++)
  {
    groups[k].handle = hnew ();
    groups[k].name = "*A" + to_string (k + 1);
  }

  put (s, 0, "SECTION");
  put (s, 2, "HEADER");
  put (s, 9, "$ACADVER");
  put (s, 1, "AC1015");
  put (s, 9, "$DWGCODEPAGE");
  put (s, 3, "ANSI_1252");
  put (s, 9, "$INSBASE");
  putp (s, 10, v3 (0, 0, 0));
  put (s, 9, "$LTSCALE");
  putn (s, 40, opt.ltscale);
  put (s, 9, "$HANDSEED");
  put (s, 5, hnew ());
  put (s, 9, "$INSUNITS");
  puti (s, 70, 4);
  put (s, 9, "$MEASUREMENT");
  puti (s, 70, 1);
  put (s, 0, "ENDSEC");

  put (s, 0, "SECTION");
  put (s, 2, "CLASSES");
  put (s, 0, "ENDSEC");

  auto table = [&] (const char *name, const string& h, size_t n)
  {
    put (s, 0, "TABLE");
    put (s, 2, name);
    put (s, 5, h);
    put (s, 330, "0");
    put (s, 100, "AcDbSymbolTable");
    puti (s, 70, n);
  };
  auto record = [&] (const char *type, const string& h, const string& t,
                     const char *sub)
  {
    put (s, 0, type);
    put (s, 5, h);
    put (s, 330, t);
    put (s, 100, "AcDbSymbolTableRecord");
    put (s, 100, sub);
  };

  put (s, 0, "SECTION");
  put (s, 2, "TABLES");

  table ("VPORT", tVport, 1);
  record ("VPORT", rVport, tVport, "AcDbViewportTableRecord");
  put (s, 2, "*Active");
  puti (s, 70, 0);
  putn (s, 10, 0);
  putn (s, 20, 0);
  putn (s, 11, 1);
  putn (s, 21, 1);
  putn (s, 12, 0);
  putn (s, 22, 0);
  putn (s, 13, 0);
  putn (s, 23, 0);
  putn (s, 14, 10);
  putn (s, 24, 10);
  putn (s, 15, 10);
  putn (s, 25, 10);
  putp (s, 16, v3 (0, 0, 1));
  putp (s, 17, v3 (0, 0, 0));
  putn (s, 40, 1000);
  putn (s, 41, 1.34);
  putn (s, 42, 50);
  putn (s, 43, 0);
  putn (s, 44, 0);
  putn (s, 50, 0);
  putn (s, 51, 0);
  puti (s, 71, 0);
  puti (s, 72, 1000);
  puti (s, 73, 1);
  puti (s, 74, 3);
  puti (s, 75, 0);
  puti (s, 76, 0);
  puti (s, 77, 0);
  puti (s, 78, 0);
  put (s, 0, "ENDTAB");

  table ("LTYPE", tLtype, 3 + ltypes.size ());
  ltyperecord (s, "ByBlock", false, rLtype[0], tLtype);
  ltyperecord (s, "ByLayer", false, rLtype[1], tLtype);
  ltyperecord (s, "Continuous", false, rLtype[2], tLtype);
  for (size_t k = 0; k < ltypes.size (); k++)
    ltyperecord (s, ltypes[k], false, rLtype[3+k], tLtype);
  put (s, 0, "ENDTAB");

  table ("LAYER", tLayer, layers.size ());
  for (size_t k = 0; k < layers.size (); k++)
  {
    record ("LAYER", rLayer[k], tLayer, "AcDbLayerTableRecord");
    put (s, 2, layers[k]);
    puti (s, 70, 0);
    puti (s, 62, 7);
    put (s, 6, "Continuous");
    puti (s, 370, -3);
    put (s, 390, oHolder);
  }
  put (s, 0, "ENDTAB");

  table ("STYLE", tStyle, 1);
  record ("STYLE", rStyle, tStyle, "AcDbTextStyleTableRecord");
  put (s, 2, "Standard");
  puti (s, 70, 0);
  putn (s, 40, 0);
  putn (s, 41, 1);
  putn (s, 50, 0);
  puti (s, 71, 0);
  putn (s, 42, 2.5);
  put (s, 3, "txt");
  put (s, 4, "");
  put (s, 0, "ENDTAB");

  table ("VIEW", tView, 0);
  put (s, 0, "ENDTAB");
  table ("UCS", tUcs, 0);
  put (s, 0, "ENDTAB");

  table ("APPID", tAppid, 2);
  record ("APPID", rAcad, tAppid, "AcDbRegAppTableRecord");
  put (s, 2, "ACAD");
  puti (s, 70, 0);
  record ("APPID", rDrafting, tAppid, "AcDbRegAppTableRecord");
  put (s, 2, "DRAFTING");
  puti (s, 70, 0);
  put (s, 0, "ENDTAB");

  table ("DIMSTYLE", tDimst, 2);
  put (s, 100, "AcDbDimStyleTable");
  // A dimension style record carries its handle in group 105, not 5
  put (s, 0, "DIMSTYLE");
  put (s, 105, rDimStd);
  put (s, 330, tDimst);
  put (s, 100, "AcDbSymbolTableRecord");
  put (s, 100, "AcDbDimStyleTableRecord");
  put (s, 2, "Standard");
  puti (s, 70, 0);
  dimstylebody (s, false);
  put (s, 0, "DIMSTYLE");
  put (s, 105, rDimDraft);
  put (s, 330, tDimst);
  put (s, 100, "AcDbSymbolTableRecord");
  put (s, 100, "AcDbDimStyleTableRecord");
  put (s, 2, "DRAFTING");
  puti (s, 70, 0);
  dimstylebody (s, true);
  put (s, 0, "ENDTAB");

  table ("BLOCK_RECORD", tBrec, 2 + blocks.size ());
  record ("BLOCK_RECORD", recModel, tBrec, "AcDbBlockTableRecord");
  put (s, 2, "*Model_Space");
  put (s, 340, oLayModel);
  record ("BLOCK_RECORD", recPaper, tBrec, "AcDbBlockTableRecord");
  put (s, 2, "*Paper_Space");
  put (s, 340, oLayPaper);
  for (const auto& B : blocks)
  {
    record ("BLOCK_RECORD", B.rec, tBrec, "AcDbBlockTableRecord");
    put (s, 2, B.name);
  }
  put (s, 0, "ENDTAB");
  put (s, 0, "ENDSEC");

  auto blockhead = [&] (const string& h, const string& rec, const string& name,
                        int flags, bool paper)
  {
    put (s, 0, "BLOCK");
    put (s, 5, h);
    put (s, 330, rec);
    put (s, 100, "AcDbEntity");
    if (paper)
      puti (s, 67, 1);
    put (s, 8, "0");
    put (s, 100, "AcDbBlockBegin");
    put (s, 2, name);
    puti (s, 70, flags);
    putp (s, 10, v3 (0, 0, 0));
    put (s, 3, name);
    put (s, 1, "");
  };
  auto blocktail = [&] (const string& h, const string& rec, bool paper)
  {
    put (s, 0, "ENDBLK");
    put (s, 5, h);
    put (s, 330, rec);
    put (s, 100, "AcDbEntity");
    if (paper)
      puti (s, 67, 1);
    put (s, 8, "0");
    put (s, 100, "AcDbBlockEnd");
  };

  put (s, 0, "SECTION");
  put (s, 2, "BLOCKS");
  blockhead (bModel, recModel, "*Model_Space", 0, false);
  blocktail (eModel, recModel, false);
  blockhead (bPaper, recPaper, "*Paper_Space", 0, true);
  blocktail (ePaper, recPaper, true);
  for (const auto& B : blocks)
  {
    blockhead (B.beg, B.rec, B.name, B.anon ? 1 : 0, false);
    for (const auto& it : B.items)
      emititem (s, it, false, B.rec, "");
    blocktail (B.end, B.rec, false);
  }
  put (s, 0, "ENDSEC");

  put (s, 0, "SECTION");
  put (s, 2, "ENTITIES");
  for (const auto& it : model)
    emititem (s, it, false, recModel,
              it.group >= 0 ? groups[it.group].handle : "");
  put (s, 0, "ENDSEC");

  auto dict = [&] (const char *type, const string& h, const string& owner)
  {
    put (s, 0, type);
    put (s, 5, h);
    put (s, 330, owner);
    put (s, 100, "AcDbDictionary");
    puti (s, 281, 1);
  };
  auto layout = [&] (const string& h, const string& name, int tab,
                     const string& rec, bool model)
  {
    put (s, 0, "LAYOUT");
    put (s, 5, h);
    put (s, 330, oLayout);
    put (s, 100, "AcDbPlotSettings");
    put (s, 1, "");
    put (s, 4, "A3");
    put (s, 6, "");
    putn (s, 40, 7.5);
    putn (s, 41, 20);
    putn (s, 42, 7.5);
    putn (s, 43, 20);
    putn (s, 44, 420);
    putn (s, 45, 297);
    putn (s, 46, 0);
    putn (s, 47, 0);
    putn (s, 48, 0);
    putn (s, 49, 0);
    putn (s, 140, 0);
    putn (s, 141, 0);
    putn (s, 142, 1);
    putn (s, 143, 1);
    puti (s, 70, model ? 1024 : 0);
    puti (s, 72, 1);
    puti (s, 73, 0);
    puti (s, 74, 5);
    put (s, 7, "");
    puti (s, 75, 16);
    putn (s, 147, 1);
    putn (s, 148, 0);
    putn (s, 149, 0);
    put (s, 100, "AcDbLayout");
    put (s, 1, name);
    puti (s, 70, 1);
    puti (s, 71, tab);
    putn (s, 10, 0);
    putn (s, 20, 0);
    putn (s, 11, 420);
    putn (s, 21, 297);
    putp (s, 12, v3 (0, 0, 0));
    putp (s, 14, v3 (1e20, 1e20, 1e20));
    putp (s, 15, v3 (-1e20, -1e20, -1e20));
    putn (s, 146, 0);
    putp (s, 13, v3 (0, 0, 0));
    putp (s, 16, v3 (1, 0, 0));
    putp (s, 17, v3 (0, 1, 0));
    puti (s, 76, 1);
    put (s, 330, rec);
  };

  put (s, 0, "SECTION");
  put (s, 2, "OBJECTS");
  dict ("DICTIONARY", oRoot, "0");
  put (s, 3, "ACAD_GROUP");
  put (s, 350, oGroup);
  put (s, 3, "ACAD_LAYOUT");
  put (s, 350, oLayout);
  put (s, 3, "ACAD_MLINESTYLE");
  put (s, 350, oMline);
  put (s, 3, "ACAD_PLOTSETTINGS");
  put (s, 350, oPlot);
  put (s, 3, "ACAD_PLOTSTYLENAME");
  put (s, 350, oPstyle);
  dict ("DICTIONARY", oGroup, oRoot);
  for (const auto& G : groups)
  {
    put (s, 3, G.name);
    put (s, 350, G.handle);
  }
  dict ("DICTIONARY", oLayout, oRoot);
  put (s, 3, "Model");
  put (s, 350, oLayModel);
  put (s, 3, "Layout1");
  put (s, 350, oLayPaper);
  dict ("DICTIONARY", oMline, oRoot);
  put (s, 3, "Standard");
  put (s, 350, oMlStd);
  dict ("DICTIONARY", oPlot, oRoot);
  dict ("ACDBDICTIONARYWDFLT", oPstyle, oRoot);
  put (s, 3, "Normal");
  put (s, 350, oHolder);
  put (s, 100, "AcDbDictionaryWithDefault");
  put (s, 340, oHolder);
  put (s, 0, "ACDBPLACEHOLDER");
  put (s, 5, oHolder);
  put (s, 330, oPstyle);
  put (s, 0, "MLINESTYLE");
  put (s, 5, oMlStd);
  put (s, 330, oMline);
  put (s, 100, "AcDbMlineStyle");
  put (s, 2, "Standard");
  puti (s, 70, 0);
  put (s, 3, "");
  puti (s, 62, 256);
  putn (s, 51, 90);
  putn (s, 52, 90);
  puti (s, 71, 2);
  putn (s, 49, 0.5);
  puti (s, 62, 256);
  put (s, 6, "BYLAYER");
  putn (s, 49, -0.5);
  puti (s, 62, 256);
  put (s, 6, "BYLAYER");
  layout (oLayModel, "Model", 0, recModel, true);
  layout (oLayPaper, "Layout1", 1, recPaper, false);
  for (const auto& G : groups)
  {
    put (s, 0, "GROUP");
    put (s, 5, G.handle);
    put (s, 102, "{ACAD_REACTORS");
    put (s, 330, oGroup);
    put (s, 102, "}");
    put (s, 330, oGroup);
    put (s, 100, "AcDbGroup");
    put (s, 300, "");
    puti (s, 70, 1);
    puti (s, 71, 1);
    for (int m : G.members)
      put (s, 340, model[m].handle);
    for (const auto& t : G.xdata)
      put (s, t.first, t.second);
  }
  put (s, 0, "ENDSEC");
  put (s, 0, "EOF");
}

string
Writer::text ()
{
  ostringstream s;
  if (opt.r12)
    emitr12 (s);
  else
    emitr2000 (s);
  return s.str ();
}

////////////////////////////////////////////////////////////////////////////////
// From objects to records

static inline V3
rotate (const Frame& f, const V3& d)
{
  return f.x * d.x + f.y * d.y + f.n * d.z;
}

// One segment of a path, in world coordinates
struct Seg
{
  int kind;                 // 0 straight, 1 arc, 2 spline
  V3 s, m, e;
  octave_value sp;
};

static vector<Seg>
pathsegs (const octave_value& P, Frame& F)
{
  F = ucsframe (prop (P, "UCS"));
  Matrix V = prop (P, "Vertices").matrix_value ();
  Matrix M = prop (P, "Midpoints").matrix_value ();
  Cell S = prop (P, "Splines").cell_value ();
  bool closed = prop (P, "Closed").bool_value ();
  octave_idx_type n = V.rows ();
  octave_idx_type nseg = closed ? n : n - 1;
  vector<Seg> segs;
  for (octave_idx_type i = 0; i < nseg; i++)
  {
    Seg g;
    g.s = toworld (F, row3 (V, i));
    g.e = toworld (F, row3 (V, (i + 1) % n));
    g.kind = 0;
    if (i < S.numel () && ! S(i).isempty ())
    {
      g.kind = 2;
      g.sp = S(i);
    }
    else if (! std::isnan (M(i,0)))
    {
      g.kind = 1;
      g.m = toworld (F, row3 (M, i));
    }
    segs.push_back (g);
  }
  return segs;
}

struct SplineData
{
  int degree;
  vector<double> knots, weights;
  vector<V3> cps, fit;
  bool hast1 = false, hast2 = false;
  V3 t1, t2;
  bool closed;
};

// A spline's data in world coordinates, its points given in the frame G
static SplineData
splinedata (const octave_value& SP, const Frame& G)
{
  SplineData d;
  d.degree = prop (SP, "Degree").int_value ();
  Matrix K = prop (SP, "Knots").matrix_value ();
  for (octave_idx_type k = 0; k < K.numel (); k++)
    d.knots.push_back (K(k));
  Matrix W = prop (SP, "Weights").matrix_value ();
  for (octave_idx_type k = 0; k < W.numel (); k++)
    d.weights.push_back (W(k));
  Matrix C = prop (SP, "ControlPoints").matrix_value ();
  for (octave_idx_type k = 0; k < C.rows (); k++)
    d.cps.push_back (toworld (G, row3 (C, k)));
  Matrix F = prop (SP, "FitPoints").matrix_value ();
  for (octave_idx_type k = 0; k < F.rows (); k++)
    d.fit.push_back (toworld (G, row3 (F, k)));
  Matrix T = prop (SP, "Tangents").matrix_value ();
  if (T.rows () == 2 && ! F.isempty ())
  {
    if (! std::isnan (T(0,0)))
    {
      d.hast1 = true;
      d.t1 = rotate (G, row3 (T, 0));
    }
    if (! std::isnan (T(1,0)))
    {
      d.hast2 = true;
      d.t2 = rotate (G, row3 (T, 1));
    }
  }
  d.closed = prop (SP, "Closed").bool_value ();
  return d;
}

// The plane a set of points lies in, if they lie in the plane of G
static bool
inplane (const vector<V3>& pts, const Frame& G)
{
  double scale = 1;
  for (const auto& p : pts)
    scale = max (scale, max (fabs (p.x), max (fabs (p.y), fabs (p.z))));
  for (const auto& p : pts)
    if (fabs (tolocal (G, p).z) > 1e-9 * scale)
      return false;
  return true;
}

static void
splineitem (Writer& w, vector<Item>& dest, const Attr& a,
            const SplineData& d, const Frame& G)
{
  bool planar = inplane (d.cps, G);
  w.spline (dest, a, d.degree, d.knots, d.weights, d.cps, d.fit,
            d.hast1 ? &d.t1 : nullptr, d.hast2 ? &d.t2 : nullptr,
            d.closed, planar ? &G.n : nullptr);
}

static void
polylineitem (Writer& w, vector<Item>& dest, const octave_value& PL,
              const Attr& a, bool withframe)
{
  Frame F = ucsframe (prop (PL, "UCS"));
  Matrix V = prop (PL, "Vertices").matrix_value ();
  bool closed = prop (PL, "Closed").bool_value ();
  Frame f = ocsframe (F.n);
  vector<PV> verts;
  double elev = 0;
  for (octave_idx_type i = 0; i < V.rows (); i++)
  {
    V3 o = tolocal (f, toworld (F, v3 (V(i,0), V(i,1), 0)));
    double b = V(i,2);
    if (! closed && i == V.rows () - 1)
      b = 0;
    verts.push_back ({o.x, o.y, b});
    elev = o.z;
  }
  w.lwpoly (dest, a, verts, closed, elev, F.n);
  if (withframe)
    dest.back ().xdata = Writer::xdataframe ("", &F, false);
}

static void
splineobjitem (Writer& w, vector<Item>& dest, const octave_value& SP,
               const Attr& a, bool withframe)
{
  Frame F = ucsframe (prop (SP, "UCS"));
  splineitem (w, dest, a, splinedata (SP, F), F);
  if (withframe)
    dest.back ().xdata = Writer::xdataframe ("", &F, true);
}

// A path as its pieces; the arcs on PLANE when one is given
static void
pathpieces (Writer& w, vector<Item>& dest, const octave_value& P,
            const Attr& a, const V3 *plane)
{
  Frame F;
  vector<Seg> segs = pathsegs (P, F);
  for (const auto& g : segs)
  {
    if (g.kind == 0)
      w.line (dest, a, g.s, g.e);
    else if (g.kind == 1)
      w.arc3 (dest, a, g.s, g.m, g.e, plane);
    else
    {
      SplineData d = splinedata (g.sp, F);
      bool planar = plane ? true : inplane (d.cps, F);
      V3 n = plane ? *plane : F.n;
      w.spline (dest, a, d.degree, d.knots, d.weights, d.cps, d.fit,
                d.hast1 ? &d.t1 : nullptr, d.hast2 ? &d.t2 : nullptr,
                d.closed, planar ? &n : nullptr);
    }
  }
}

static bool
hasspline (const vector<Seg>& segs)
{
  for (const auto& g : segs)
    if (g.kind == 2)
      return true;
  return false;
}

// A closed loop on the plane square to N: one polyline unless a spline is
// part of it, then its pieces
static void
loopitems (Writer& w, vector<Item>& dest, const octave_value& L,
           const Attr& a, const V3& n)
{
  Frame F;
  vector<Seg> segs = pathsegs (L, F);
  if (hasspline (segs))
  {
    pathpieces (w, dest, L, a, &n);
    return;
  }
  Frame f = ocsframe (n);
  vector<PV> verts;
  double elev = 0;
  for (const auto& g : segs)
  {
    V3 s = tolocal (f, g.s);
    double b = 0;
    if (g.kind == 1)
    {
      V3 m = tolocal (f, g.m), e = tolocal (f, g.e);
      b = bulge3 (s.x, s.y, m.x, m.y, e.x, e.y);
    }
    verts.push_back ({s.x, s.y, b});
    elev = s.z;
  }
  w.lwpoly (dest, a, verts, true, elev, n);
}

// The same loop as a hatch boundary in the OCS of N
static Loop
hatchloop (const octave_value& L, const V3& n, bool outer, double& elev)
{
  Frame F;
  vector<Seg> segs = pathsegs (L, F);
  Frame f = ocsframe (n);
  Loop lp;
  lp.outer = outer;
  lp.poly = ! hasspline (segs);
  for (const auto& g : segs)
  {
    V3 s = tolocal (f, g.s), e = tolocal (f, g.e);
    elev = s.z;
    if (lp.poly)
    {
      double b = 0;
      if (g.kind == 1)
      {
        V3 m = tolocal (f, g.m);
        b = bulge3 (s.x, s.y, m.x, m.y, e.x, e.y);
      }
      lp.verts.push_back ({s.x, s.y, b});
      continue;
    }
    Edge ed;
    ed.kind = 1;
    ed.x1 = s.x;
    ed.y1 = s.y;
    ed.x2 = e.x;
    ed.y2 = e.y;
    if (g.kind == 1)
    {
      V3 m = tolocal (f, g.m), c, nn;
      double r;
      if (circle3 (v3 (s.x, s.y, 0), v3 (m.x, m.y, 0), v3 (e.x, e.y, 0),
                   c, r, nn))
        {
          ed.kind = 2;
          ed.cx = c.x;
          ed.cy = c.y;
          ed.r = r;
          double as = deg (atan2 (s.y - c.y, s.x - c.x));
          double ae = deg (atan2 (e.y - c.y, e.x - c.x));
          ed.ccw = nn.z > 0;
          // Anticlockwise from a0 to a1, whichever way the edge runs
          ed.a0 = ed.ccw ? as : ae;
          ed.a1 = ed.ccw ? ae : as;
          ed.a0 = fmod (fmod (ed.a0, 360) + 360, 360);
          ed.a1 = fmod (fmod (ed.a1, 360) + 360, 360);
        }
    }
    else if (g.kind == 2)
    {
      SplineData d = splinedata (g.sp, F);
      ed.kind = 4;
      ed.degree = d.degree;
      ed.knots = d.knots;
      ed.weights = d.weights;
      for (const auto& p : d.cps)
      {
        V3 q = tolocal (f, p);
        ed.px.push_back (q.x);
        ed.py.push_back (q.y);
      }
    }
    lp.edges.push_back (ed);
  }
  return lp;
}

static vector<octave_value>
regionloops (const octave_value& R)
{
  vector<octave_value> loops;
  loops.push_back (prop (R, "Outline"));
  Cell H = prop (R, "Holes").cell_value ();
  for (octave_idx_type k = 0; k < H.numel (); k++)
    loops.push_back (H(k));
  return loops;
}

// A region's loops, and a hatch over them when asked, or the hatch alone;
// returns the indices of the records written
static vector<int>
regionitems (Writer& w, vector<Item>& dest, const octave_value& R,
             const Attr& a, bool fill, bool withloops, const string& pattern,
             double angle, double spacing, bool solid)
{
  vector<int> idx;
  Frame F = ucsframe (prop (R, "UCS"));
  vector<octave_value> loops = regionloops (R);
  for (const auto& L : loops)
  {
    if (! withloops)
      break;
    size_t n0 = dest.size ();
    loopitems (w, dest, L, a, F.n);
    for (size_t k = n0; k < dest.size (); k++)
      idx.push_back (k);
  }
  if (fill)
  {
    vector<Loop> hl;
    double elev = 0;
    for (size_t k = 0; k < loops.size (); k++)
      hl.push_back (hatchloop (loops[k], F.n, k == 0, elev));
    w.hatch (dest, a, hl, pattern, solid, angle, spacing, elev, F.n);
    idx.push_back (dest.size () - 1);
  }
  return idx;
}

static vector<int>
pathitems (Writer& w, vector<Item>& dest, const octave_value& P,
           const Attr& a)
{
  vector<int> idx;
  size_t n0 = dest.size ();
  pathpieces (w, dest, P, a, nullptr);
  for (size_t k = n0; k < dest.size (); k++)
    idx.push_back (k);
  return idx;
}

static void
groupof (Writer& w, const vector<int>& members, const vector<Tag>& xdata)
{
  Writer::Group G;
  G.members = members;
  G.xdata = xdata;
  w.groups.push_back (G);
  for (int m : members)
    w.model[m].group = w.groups.size () - 1;
}

static string
r12name (const string& cls)
{
  if (cls == "geom.Spline" || cls == "spline")
    return "a spline";
  if (cls == "geom.Path" || cls == "path")
    return "a path";
  if (cls == "geom.Region" || cls == "region")
    return "a region";
  if (cls == "ellipse")
    return "an ellipse";
  if (cls == "hatch")
    return "a hatch";
  return cls;
}

static void
refuser12 (const string& what)
{
  error ("%s: R12 holds only lines and arcs, not %s.", g_caller.c_str (),
         r12name (what).c_str ());
}

static string
mapstr (const octave_map& m, const char *f, octave_idx_type i,
        const string& dflt = "")
{
  if (! m.isfield (f))
    return dflt;
  octave_value v = m.contents (f)(i);
  return v.is_string () ? v.string_value () : dflt;
}

static Matrix
mapmat (const octave_map& m, const char *f, octave_idx_type i)
{
  if (! m.isfield (f))
    return Matrix ();
  octave_value v = m.contents (f)(i);
  if (v.isempty () || ! (v.isnumeric () || v.islogical ()))
    return Matrix ();
  return v.matrix_value ();
}

static double
mapnum (const octave_map& m, const char *f, octave_idx_type i, double dflt)
{
  Matrix x = mapmat (m, f, i);
  return x.isempty () ? dflt : x(0);
}

// The entities of a drawing; INBLOCK leaves paths and regions ungrouped,
// since a group holds entities of the model alone
static void
drawingitems (Writer& w, vector<Item>& dest, const octave_value& D,
              bool inblock)
{
  octave_map E = prop (D, "Entities").map_value ();
  V3 up = v3 (0, 0, 1);
  for (octave_idx_type i = 0; i < E.numel (); i++)
  {
    string type = mapstr (E, "type", i);
    Attr a;
    a.layer = mapstr (E, "layer", i, "0");
    a.ltype = mapstr (E, "linetype", i, "CONTINUOUS");
    a.colour = static_cast<int> (mapnum (E, "colour", i, 256));
    Matrix P = mapmat (E, "pts", i);
    auto pt = [&] (int r) { return v3 (P(r,0), P(r,1), 0); };
    octave_value shape;
    if (E.isfield ("shape"))
      shape = E.contents ("shape")(i);
    if (type == "line")
      w.line (dest, a, pt (0), pt (1));
    else if (type == "point")
      w.point (dest, a, pt (0));
    else if (type == "polyline")
    {
      Matrix b = mapmat (E, "bulge", i);
      bool closed = mapnum (E, "closed", i, 0) != 0;
      vector<PV> v;
      for (octave_idx_type k = 0; k < P.rows (); k++)
      {
        double bk = k < b.numel () ? b(k) : 0;
        if (! closed && k == P.rows () - 1)
          bk = 0;
        v.push_back ({P(k,0), P(k,1), bk});
      }
      w.lwpoly (dest, a, v, closed, 0, up);
    }
    else if (type == "arc")
    {
      Matrix ang = mapmat (E, "angles", i);
      w.arc (dest, a, pt (0), mapnum (E, "radius", i, 0), ang(0), ang(1),
             up);
    }
    else if (type == "circle")
      w.circle (dest, a, pt (0), mapnum (E, "radius", i, 0), up);
    else if (type == "ellipse")
    {
      if (w.opt.r12)
        refuser12 ("ellipse");
      Matrix r = mapmat (E, "radius", i);
      double rot = rad (mapnum (E, "angle", i, 0));
      double A = r(0), B = r(1);
      V3 major;
      double ratio;
      if (A >= B)
      {
        major = v3 (A * cos (rot), A * sin (rot), 0);
        ratio = B / A;
      }
      else
      {
        major = v3 (-B * sin (rot), B * cos (rot), 0);
        ratio = A / B;
      }
      w.ellipse (dest, a, pt (0), major, ratio, 0, 2 * M_PI, up);
    }
    else if (type == "text")
      w.text (dest, a, pt (0), mapnum (E, "height", i, 2.5),
              mapstr (E, "text", i), mapnum (E, "angle", i, 0));
    else if (type == "spline")
    {
      if (w.opt.r12)
        refuser12 ("spline");
      splineobjitem (w, dest, shape, a, false);
    }
    else if (type == "path")
    {
      if (w.opt.r12)
        refuser12 ("path");
      vector<int> m = pathitems (w, dest, shape, a);
      if (! inblock && &dest == &w.model)
        groupof (w, m, Writer::xdataframe ("geom.Path", nullptr, false));
    }
    else if (type == "region" || type == "hatch")
    {
      if (w.opt.r12)
        refuser12 (type);
      // A hatch is its HATCH alone, a region its loops
      bool h = type == "hatch";
      vector<int> m = regionitems (w, dest, shape, a, h, ! h,
                                   mapstr (E, "pattern", i, "ANSI31"),
                                   mapnum (E, "angle", i, 0),
                                   mapnum (E, "spacing", i, 2.5), false);
      if (! h && ! inblock && &dest == &w.model)
        groupof (w, m, Writer::xdataframe ("geom.Region", nullptr,
                                             false));
    }
    else if (type == "insert")
      w.insert (dest, a, mapstr (E, "block", i), pt (0),
                mapnum (E, "scale", i, 1), mapnum (E, "angle", i, 0));
    else if (type == "dim" || type == "diam" || type == "radius"
             || type == "angdim" || type == "ordinate"
             || type == "centremark" || type == "leader")
      {
        octave_value_list r
          = octave::feval ("__ornament__",
                           ovl (D, static_cast<double> (i + 1),
                                w.opt.dimscale), 2);
        octave_value B = r(0);
        octave_value rec = r(1);
        if (rec.isempty () || w.opt.explode)
        {
          drawingitems (w, dest, B, true);
          continue;
        }
        vector<Item> pic;
        drawingitems (w, pic, B, true);
        string name = "*D" + to_string (++w.ndim);
        Writer::Block blk;
        blk.name = name;
        blk.anon = true;
        blk.items = pic;
        w.blocks.push_back (blk);
        octave_map m = rec.map_value ();
        w.dimension (dest, a, m.contents ("pts")(0).matrix_value (),
                     m.contents ("angles")(0).int_value (),
                     m.contents ("text")(0).string_value (),
                     m.contents ("rotation")(0).double_value (), name);
      }
  }
}

// Every block a drawing defines, and those its blocks define, once each
static void
drawingblocks (Writer& w, const octave_value& D, set<string>& seen)
{
  octave_map B = prop (D, "Blocks").map_value ();
  for (octave_idx_type i = 0; i < B.numel (); i++)
  {
    string name = B.contents ("name")(i).string_value ();
    if (seen.count (upper (name)))
      continue;
    seen.insert (upper (name));
    octave_value sub = B.contents ("drawing")(i);
    vector<Item> items;
    drawingitems (w, items, sub, true);
    Writer::Block blk;
    blk.name = name;
    blk.anon = false;
    blk.items = items;
    w.blocks.push_back (blk);
    drawingblocks (w, sub, seen);
  }
}

////////////////////////////////////////////////////////////////////////////////
// The write command

static bool
ischarrow (const octave_value& v)
{
  return v.is_string () && v.rows () == 1 && v.numel () > 0;
}

static bool
posfinite (const octave_value& v)
{
  if (! v.isnumeric () || ! v.isreal () || v.numel () != 1)
    return false;
  double x = v.double_value ();
  return std::isfinite (x) && x > 0;
}

static bool
colourindex (const octave_value& v)
{
  if (! v.isnumeric () || ! v.isreal () || v.numel () != 1)
    return false;
  double x = v.double_value ();
  return std::isfinite (x) && x == floor (x) && x >= 1 && x <= 256;
}

// One value of an option for every object: a scalar shared by all, or for
// several objects a cell of one per object
static vector<octave_value>
perobject (const octave_value& v, size_t n, bool many, bool (*ok) (
             const octave_value&), const char *msg1, const char *msgn)
{
  vector<octave_value> out;
  if (ok (v))
  {
    out.assign (n, v);
    return out;
  }
  if (many && v.iscell () && static_cast<size_t> (v.numel ()) == n)
  {
    Cell c = v.cell_value ();
    for (octave_idx_type k = 0; k < c.numel (); k++)
    {
      if (! ok (c(k)))
        error ("%s: %s", g_caller.c_str (), msgn);
      out.push_back (c(k));
    }
    return out;
  }
  error ("%s: %s", g_caller.c_str (), many ? msgn : msg1);
  return out;
}

static void
writefile (const string& file, const string& text)
{
  ofstream f (file.c_str (), ios::out | ios::binary);
  if (! f)
    error ("%s: cannot open '%s' for writing.", g_caller.c_str (),
           file.c_str ());
  f << text;
  f.close ();
  if (! f)
    error ("%s: cannot write '%s'.", g_caller.c_str (), file.c_str ());
}

static void
cmdwrite (const octave_value_list& args)
{
  if (args.length () != 5)
    error ("__dxf__: invalid number of input arguments.");
  g_caller = args(4).string_value ();
  if (! ischarrow (args(1)))
    error ("%s: FILE must be a non-empty character vector.",
           g_caller.c_str ());
  string file = args(1).string_value ();
  if (file.size () < 4 || lower (file.substr (file.size () - 4)) != ".dxf")
    error ("%s: FILE must end in .dxf.", g_caller.c_str ());
  if (! args(2).iscell ())
    error ("%s: C must be a cell array of geom.Polyline, geom.Spline,"
           " geom.Path and geom.Region objects.", g_caller.c_str ());
  Cell objs = args(2).cell_value ();
  Cell opts = args(3).cell_value ();
  if (opts.numel () % 2 != 0)
    error ("%s: Name/Value arguments must come in pairs.", g_caller.c_str ());

  bool drawing = objs.numel () == 1 && isclass (objs(0), "draw.Drawing");
  bool many = g_caller == "geom.write";
  bool canfill = many || g_caller == "geom.Region.write";
  size_t n = objs.numel ();
  if (! drawing)
    for (octave_idx_type k = 0; k < objs.numel (); k++)
    {
      octave_value o = objs(k);
      if (! (isclass (o, "geom.Polyline") || isclass (o, "geom.Spline")
             || isclass (o, "geom.Path") || isclass (o, "geom.Region")))
        error (strcmp (g_caller.c_str (), "geom.write") == 0
               ? "%s: C must be a cell array of geom.Polyline,"
                 " geom.Spline, geom.Path and geom.Region objects."
               : "%s: invalid object.", g_caller.c_str ());
    }

  WOpts w;
  vector<octave_value> layer (n, octave_value ("0"));
  vector<octave_value> ltype (n, octave_value ("CONTINUOUS"));
  vector<octave_value> colour (n, octave_value (256.0));
  for (octave_idx_type k = 0; k < opts.numel (); k += 2)
  {
    if (! ischarrow (opts(k)))
      error ("%s: unknown parameter.",
             g_caller.c_str ());
    string name = lower (opts(k).string_value ());
    octave_value v = opts(k+1);
    if (name == "version")
    {
      string s = ischarrow (v) ? upper (v.string_value ()) : "";
      if (s != "R2000" && s != "R12")
        error ("%s: Version must be 'R2000' or 'R12'.", g_caller.c_str ());
      w.r12 = s == "R12";
    }
    else if (name == "ltscale")
    {
      if (! posfinite (v))
        error ("%s: LTScale must be a positive finite scalar.",
               g_caller.c_str ());
      w.ltscale = v.double_value ();
    }
    else if (drawing && name == "dimensions")
    {
      string s = ischarrow (v) ? lower (v.string_value ()) : "";
      if (s != "associative" && s != "explode")
        error ("%s: Dimensions must be 'associative' or 'explode'.",
               g_caller.c_str ());
      w.explode = s == "explode";
    }
    else if (drawing && name == "blocks")
    {
      string s = ischarrow (v) ? lower (v.string_value ()) : "";
      if (s != "reference" && s != "expand")
        error ("%s: Blocks must be 'reference' or 'expand'.",
               g_caller.c_str ());
      w.expand = s == "expand";
    }
    else if (drawing && name == "dimscale")
    {
      if (! posfinite (v))
        error ("%s: DimScale must be a positive finite scalar.",
               g_caller.c_str ());
      w.dimscale = v.double_value ();
    }
    else if (! drawing && name == "layer")
      layer = perobject (v, n, many, ischarrow,
                         "Layer must be a non-empty character vector.",
                         "Layer must be a non-empty character vector or"
                         " a cell array of one per object.");
    else if (! drawing && name == "linetype")
      ltype = perobject (v, n, many, ischarrow,
                         "Linetype must be a non-empty character vector.",
                         "Linetype must be a non-empty character vector"
                         " or a cell array of one per object.");
    else if (! drawing && name == "colour")
      colour = perobject (v, n, many, colourindex,
                          "Colour must be an integer from 1 to 256.",
                          "Colour must be an integer from 1 to 256 or a"
                          " cell array of one per object.");
    else if (canfill && name == "fill")
    {
      if (! (v.islogical () || v.isnumeric ()) || v.numel () != 1)
        error ("%s: Fill must be a logical scalar.", g_caller.c_str ());
      double x = v.double_value ();
      if (x != 0 && x != 1)
        error ("%s: Fill must be a logical scalar.", g_caller.c_str ());
      w.fill = x != 0;
    }
    else
      error ("%s: unknown parameter.", g_caller.c_str ());
  }

  Writer wr (w);
  if (drawing)
  {
    octave_value D = objs(0);
    if (w.expand)
      D = call ("expand", ovl (D));
    drawingitems (wr, wr.model, D, false);
    // Expanded, the blocks are in place of their inserts and nothing
    // refers to them
    if (! w.expand)
    {
      set<string> seen;
      drawingblocks (wr, D, seen);
    }
  }
  else
    for (size_t k = 0; k < n; k++)
    {
      octave_value o = objs(k);
      string cls = o.class_name ();
      if (wr.opt.r12 && cls != "geom.Polyline")
        refuser12 (cls);
      Attr a;
      a.layer = layer[k].string_value ();
      a.ltype = ltype[k].string_value ();
      a.colour = colour[k].int_value ();
      if (cls == "geom.Polyline")
        polylineitem (wr, wr.model, o, a, true);
      else if (cls == "geom.Spline")
        splineobjitem (wr, wr.model, o, a, true);
      else if (cls == "geom.Path")
      {
        Frame F = ucsframe (prop (o, "UCS"));
        vector<int> m = pathitems (wr, wr.model, o, a);
        groupof (wr, m, Writer::xdataframe ("geom.Path", &F, true));
      }
      else
      {
        Frame F = ucsframe (prop (o, "UCS"));
        vector<int> m = regionitems (wr, wr.model, o, a, w.fill, true,
                                     "SOLID", 0, 1, true);
        groupof (wr, m, Writer::xdataframe ("geom.Region", &F, true));
      }
    }
  writefile (file, wr.text ());
}

////////////////////////////////////////////////////////////////////////////////
// Reading

// One record of the file, with our application's extended data apart
struct Rec
{
  string type;
  vector<Tag> tags;
  vector<Tag> xdata;
  vector<Rec> sub;
  string handle;
  string layer = "0";
  string ltype = "BYLAYER";
  int colour = 256;
  bool paper = false;

  bool has (int c) const
  {
    for (const auto& t : tags)
      if (t.first == c)
        return true;
    return false;
  }
  string str (int c, const string& dflt = "") const
  {
    for (const auto& t : tags)
      if (t.first == c)
        return t.second;
    return dflt;
  }
  double num (int c, double dflt = 0) const
  {
    for (const auto& t : tags)
      if (t.first == c)
      {
        char *end;
        double v = strtod (t.second.c_str (), &end);
        return end == t.second.c_str () ? dflt : v;
      }
    return dflt;
  }
  V3 pt (int c, const V3& dflt = v3 (0, 0, 0)) const
  {
    if (! has (c))
      return dflt;
    return v3 (num (c), num (c + 10), num (c + 20));
  }
};

static double
tonum (const string& s)
{
  return strtod (s.c_str (), nullptr);
}

// The frame our extended data records, if it does
struct XFrame
{
  string cls;
  bool has = false;
  V3 o, x, n;
  bool hasn = false;
};

static XFrame
xframe (const vector<Tag>& x)
{
  XFrame f;
  int n13 = 0;
  for (size_t k = 0; k < x.size (); k++)
  {
    int c = x[k].first;
    double v = tonum (x[k].second);
    if (c == 1000)
      f.cls = x[k].second;
    else if (c == 1011)
    {
      f.o.x = v;
      f.has = true;
    }
    else if (c == 1021)
      f.o.y = v;
    else if (c == 1031)
      f.o.z = v;
    else if (c == 1013)
    {
      if (n13 == 0)
        f.x.x = v;
      else
      {
        f.n.x = v;
        f.hasn = true;
      }
      n13++;
    }
    else if (c == 1023)
      (n13 <= 1 ? f.x.y : f.n.y) = v;
    else if (c == 1033)
      (n13 <= 1 ? f.x.z : f.n.z) = v;
  }
  return f;
}

// What was skipped, counted by label in the order first met
class Skips
{
public:
  void add (const string& label)
  {
    for (size_t k = 0; k < m_l.size (); k++)
      if (m_l[k] == label)
      {
        m_n[k]++;
        return;
      }
    m_l.push_back (label);
    m_n.push_back (1);
  }
  octave_value labels () const
  {
    Cell c (1, m_l.size ());
    for (size_t k = 0; k < m_l.size (); k++)
      c(k) = m_l[k];
    return c;
  }
  octave_value counts () const
  {
    RowVector r (m_n.size ());
    for (size_t k = 0; k < m_n.size (); k++)
      r(k) = m_n[k];
    return r;
  }
private:
  vector<string> m_l;
  vector<double> m_n;
};

static void
utf8put (string& out, unsigned cp)
{
  if (cp < 0x80)
    out += static_cast<char> (cp);
  else if (cp < 0x800)
  {
    out += static_cast<char> (0xC0 | (cp >> 6));
    out += static_cast<char> (0x80 | (cp & 0x3F));
  }
  else if (cp < 0x10000)
  {
    out += static_cast<char> (0xE0 | (cp >> 12));
    out += static_cast<char> (0x80 | ((cp >> 6) & 0x3F));
    out += static_cast<char> (0x80 | (cp & 0x3F));
  }
  else
  {
    out += static_cast<char> (0xF0 | (cp >> 18));
    out += static_cast<char> (0x80 | ((cp >> 12) & 0x3F));
    out += static_cast<char> (0x80 | ((cp >> 6) & 0x3F));
    out += static_cast<char> (0x80 | (cp & 0x3F));
  }
}

class Reader
{
public:
  string file;
  string version = "AC1009";
  string codepage;
  double scale = 1;
  vector<Rec> ents;
  struct Blk
  {
    string name;
    vector<Rec> ents;
  };
  vector<Blk> blocks;
  struct Grp
  {
    vector<string> members;
    vector<Tag> xdata;
  };
  vector<Grp> groups;
  // The colour and line type of each layer the table defines, by the name
  // in upper case, as layer names are compared
  struct Lay
  {
    int colour = 7;
    string ltype = "CONTINUOUS";
  };
  map<string, Lay> layers;

  void load (const string& f);
  string decode (const string& s) const;

private:
  vector<Tag> m_t;
  vector<Rec> records (size_t a, size_t b) const;
};

// Text as Octave holds it: the code page of a file before R2007, UTF-8
// from R2007 on, and the \U+XXXX escapes of either
string
Reader::decode (const string& s) const
{
  string t = s;
  bool high = false;
  for (unsigned char c : t)
    if (c >= 0x80)
      high = true;
  if (high && version < "AC1021" && ! codepage.empty ())
  {
    string cp = codepage;
    if (upper (cp).compare (0, 5, "ANSI_") == 0)
      cp = "CP" + cp.substr (5);
    try
    {
      uint8NDArray b (dim_vector (1, t.size ()));
      for (size_t k = 0; k < t.size (); k++)
        b(k) = static_cast<unsigned char> (t[k]);
      t = call ("native2unicode", ovl (b, cp)).string_value ();
    }
    catch (const octave::execution_exception&)
    {
      recover ();
    }
  }
  if (t.find ("\\U+") == string::npos)
    return t;
  string out;
  for (size_t i = 0; i < t.size (); i++)
  {
    if (t.compare (i, 3, "\\U+") == 0 && i + 7 <= t.size ()
        && isxdigit (t[i+3]) && isxdigit (t[i+4]) && isxdigit (t[i+5])
        && isxdigit (t[i+6]))
      {
        unsigned cp = strtoul (t.substr (i + 3, 4).c_str (), nullptr, 16);
        i += 6;
        // A surrogate pair carries a character past the first plane
        if (cp >= 0xD800 && cp < 0xDC00 && t.compare (i + 1, 3, "\\U+") == 0
            && i + 8 <= t.size ())
          {
            unsigned lo = strtoul (t.substr (i + 4, 4).c_str (), nullptr,
                                   16);
            if (lo >= 0xDC00 && lo < 0xE000)
            {
              cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
              i += 7;
            }
          }
        utf8put (out, cp);
      }
    else
      out += t[i];
  }
  return out;
}

// The records between two tokens, with the vertices of a POLYLINE and the
// attributes of an INSERT folded into the record that owns them
vector<Rec>
Reader::records (size_t a, size_t b) const
{
  vector<Rec> out;
  size_t i = a;
  while (i < b)
  {
    if (m_t[i].first != 0)
    {
      i++;
      continue;
    }
    Rec r;
    r.type = upper (trim (m_t[i].second));
    i++;
    bool inx = false, ours = false, brace = false;
    for (; i < b && m_t[i].first != 0; i++)
    {
      int c = m_t[i].first;
      const string& v = m_t[i].second;
      if (c == 1001)
      {
        inx = true;
        ours = trim (v) == "DRAFTING";
        if (ours)
          r.xdata.push_back (Tag (c, trim (v)));
        continue;
      }
      if (inx)
      {
        if (ours)
          r.xdata.push_back (Tag (c, v));
        continue;
      }
      if (c == 102)
      {
        brace = ! v.empty () && v[0] == '{';
        continue;
      }
      if (brace)
        continue;
      if (c == 5 || c == 105)
        r.handle = upper (trim (v));
      else if (c == 8)
        r.layer = trim (v);
      else if (c == 6)
        r.ltype = trim (v);
      else if (c == 62)
        r.colour = atoi (v.c_str ());
      else if (c == 67)
        r.paper = atoi (v.c_str ()) == 1;
      r.tags.push_back (Tag (c, v));
    }
    if (r.type == "VERTEX" || r.type == "SEQEND" || r.type == "ATTRIB")
    {
      if (! out.empty () && (out.back ().type == "POLYLINE"
                             || out.back ().type == "INSERT"))
        {
          if (r.type == "VERTEX")
            out.back ().sub.push_back (r);
          continue;
        }
      continue;
    }
    out.push_back (r);
  }
  return out;
}

void
Reader::load (const string& f)
{
  file = f;
  ifstream in (f.c_str (), ios::in | ios::binary);
  if (! in)
    error ("%s: cannot find file '%s'.", g_caller.c_str (), f.c_str ());
  string txt ((istreambuf_iterator<char> (in)), istreambuf_iterator<char> ());
  if (txt.compare (0, 18, "AutoCAD Binary DXF") == 0)
    error ("%s: '%s' is a binary DXF; only ASCII DXF is read.",
           g_caller.c_str (), f.c_str ());
  // Lines, tolerating CRLF; a trailing newline is not a pair
  vector<string> lines;
  size_t p = 0;
  while (p < txt.size ())
  {
    size_t q = txt.find ('\n', p);
    if (q == string::npos)
      q = txt.size ();
    string ln = txt.substr (p, q - p);
    if (! ln.empty () && ln.back () == '\r')
      ln.pop_back ();
    lines.push_back (ln);
    p = q + 1;
  }
  if (lines.empty ())
    error ("%s: '%s' is empty.", g_caller.c_str (), f.c_str ());
  if (lines.size () % 2 != 0)
  {
    // A file may end on a blank line after EOF
    if (trim (lines.back ()).empty ())
      lines.pop_back ();
    else
      error ("%s: '%s' is malformed; group codes and values do not pair up.",
             g_caller.c_str (), f.c_str ());
  }
  for (size_t k = 0; k + 1 < lines.size (); k += 2)
  {
    string c = trim (lines[k]);
    char *end;
    long code = strtol (c.c_str (), &end, 10);
    if (c.empty () || *end != '\0')
      error ("%s: '%s' is malformed; line %d is not a group code.",
             g_caller.c_str (), f.c_str (), static_cast<int> (k + 1));
    m_t.push_back (Tag (static_cast<int> (code), lines[k+1]));
  }

  // The sections
  int units = 0;
  for (size_t i = 0; i < m_t.size (); i++)
  {
    if (m_t[i].first != 0 || upper (trim (m_t[i].second)) != "SECTION")
      continue;
    if (i + 1 >= m_t.size () || m_t[i+1].first != 2)
      continue;
    string name = upper (trim (m_t[i+1].second));
    size_t j = i + 2;
    while (j < m_t.size () && ! (m_t[j].first == 0
                                 && upper (trim (m_t[j].second)) == "ENDSEC"))
      j++;
    if (name == "HEADER")
    {
      for (size_t k = i + 2; k + 1 < j; k++)
      {
        if (m_t[k].first != 9)
          continue;
        string var = upper (trim (m_t[k].second));
        if (var == "$ACADVER")
          version = upper (trim (m_t[k+1].second));
        else if (var == "$INSUNITS")
          units = atoi (m_t[k+1].second.c_str ());
        else if (var == "$DWGCODEPAGE")
          codepage = trim (m_t[k+1].second);
      }
    }
    else if (name == "ENTITIES")
      ents = records (i + 2, j);
    else if (name == "TABLES")
    {
      for (const auto& r : records (i + 2, j))
        if (r.type == "LAYER" && ! trim (r.str (2)).empty ())
        {
          Lay l;
          // A negative colour is a layer switched off, in its colour
          int c = abs (static_cast<int> (r.num (62, 7)));
          if (c >= 1 && c <= 255)
            l.colour = c;
          string lt = trim (r.str (6));
          if (! lt.empty ())
            l.ltype = lt;
          layers[upper (trim (r.str (2)))] = l;
        }
    }
    else if (name == "BLOCKS")
    {
      vector<Rec> all = records (i + 2, j);
      Blk *cur = nullptr;
      for (auto& r : all)
      {
        if (r.type == "BLOCK")
        {
          blocks.push_back (Blk ());
          cur = &blocks.back ();
          cur->name = trim (r.str (2));
        }
        else if (r.type == "ENDBLK")
          cur = nullptr;
        else if (cur)
          cur->ents.push_back (r);
      }
    }
    else if (name == "OBJECTS")
    {
      vector<Rec> all = records (i + 2, j);
      for (const auto& r : all)
        if (r.type == "GROUP" && ! r.xdata.empty ())
        {
          Grp g;
          for (const auto& t : r.tags)
            if (t.first == 340)
              g.members.push_back (upper (trim (t.second)));
          g.xdata = r.xdata;
          groups.push_back (g);
        }
    }
    i = j;
  }
  switch (units)
  {
    case 1: scale = 25.4; break;
    case 2: scale = 304.8; break;
    case 4: scale = 1; break;
    case 5: scale = 10; break;
    case 6: scale = 1000; break;
    case 7: scale = 1e6; break;
    case 8: scale = 25.4e-6; break;
    case 9: scale = 0.0254; break;
    case 10: scale = 914.4; break;
    case 13: scale = 1e-3; break;
    case 14: scale = 100; break;
    default: scale = 1; break;
  }
  for (auto& r : ents)
    r.layer = decode (r.layer);
  for (auto& b : blocks)
    for (auto& r : b.ents)
      r.layer = decode (r.layer);
}

// A reason to skip an entity, carried out of the builders below
struct Bad
{
  string why;
};

// The frame a flat entity is returned in: the world, moved to its height,
// for a normal along z either way up, mirrored into +Z when it faces down;
// otherwise the entity's own object coordinate system
static Frame
flatframe (const V3& n, double elev, bool& flip)
{
  Frame T;
  V3 u = unit (n);
  if (isz (u))
  {
    T = worldframe ();
    T.o = v3 (0, 0, u.z > 0 ? elev : -elev);
    flip = u.z < 0;
  }
  else
  {
    T = ocsframe (u);
    T.o = T.n * elev;
    flip = false;
  }
  return T;
}

static double
scaleof (const vector<V3>& p)
{
  double s = 1;
  for (const auto& q : p)
    s = max (s, max (fabs (q.x), max (fabs (q.y), fabs (q.z))));
  return s;
}

// A geom.Polyline from vertices in the object coordinate system of N, at
// elevation ELEV, kept in the frame our extended data names if it fits
static octave_value
ocspolyline (vector<PV> v, bool closed, const V3& n, double elev,
             const XFrame *xf)
{
  Frame f = ocsframe (n);
  bool flip;
  Frame T = flatframe (n, elev, flip);
  vector<V3> w;
  for (const auto& p : v)
    w.push_back (toworld (f, v3 (p.x, p.y, elev)));
  double sc = scaleof (w);
  if (xf && xf->has && ! xf->hasn)
  {
    V3 x = unit (xf->x);
    if (fabs (dot (x, f.n)) < 1e-9 && fabs (norm (xf->x) - 1) < 1e-6
        && fabs (dot (xf->o - f.n * elev, f.n)) <= 1e-9 * sc)
      {
        T.o = xf->o;
        T.x = x;
        T.n = f.n;
        T.y = unit (cross (f.n, x));
        flip = false;
      }
  }
  // What a file may hold that a polyline may not, and that changes no
  // geometry, is tidied: a vertex repeated in place, the first vertex of a
  // closed polyline repeated at its end, a bulge after an open polyline's end
  vector<PV> q;
  for (size_t k = 0; k < v.size (); k++)
  {
    V3 l = tolocal (T, w[k]);
    PV p = {l.x, l.y, flip ? -v[k].b : v[k].b};
    if (! q.empty () && fabs (q.back ().x - p.x) <= 1e-12 * sc
        && fabs (q.back ().y - p.y) <= 1e-12 * sc)
      {
        q.back ().b = p.b;
        continue;
      }
    q.push_back (p);
  }
  if (closed && q.size () > 2 && fabs (q.front ().x - q.back ().x) <= 1e-12 * sc
      && fabs (q.front ().y - q.back ().y) <= 1e-12 * sc)
    q.pop_back ();
  if (q.size () < 2)
    throw Bad {"invalid"};
  if (! closed)
    q.back ().b = 0;
  Matrix V (q.size (), 3);
  for (size_t k = 0; k < q.size (); k++)
  {
    V(k,0) = q[k].x;
    V(k,1) = q[k].y;
    V(k,2) = q[k].b;
  }
  return call ("geom.Polyline", ovl (V, "Closed", closed, "UCS",
                                     ucsobject (T)));
}

// The control points, knots and weights of an elliptical arc, anticlockwise
// from U0 to U1 about the normal of X and Y, as rational quadratic pieces
static octave_value
ellipsespline (const V3& c, const V3& X, const V3& Y, double a, double b,
               double u0, double u1)
{
  while (u1 <= u0)
    u1 += 2 * M_PI;
  int nseg = max (1, static_cast<int> (ceil ((u1 - u0) / (M_PI / 2) - 1e-9)));
  double d = (u1 - u0) / nseg;
  double wm = cos (d / 2);
  Matrix P (2 * nseg + 1, 3);
  ColumnVector W (2 * nseg + 1);
  RowVector K (2 * nseg + 4);
  auto at = [&] (double t, double s) {
    return c + X * (a * cos (t) * s) + Y * (b * sin (t) * s);
  };
  for (int j = 0; j <= nseg; j++)
  {
    V3 p = at (u0 + j * d, 1);
    P(2*j,0) = p.x;
    P(2*j,1) = p.y;
    P(2*j,2) = p.z;
    W(2*j) = 1;
    if (j < nseg)
    {
      V3 m = at (u0 + (j + 0.5) * d, 1 / wm);
      P(2*j+1,0) = m.x;
      P(2*j+1,1) = m.y;
      P(2*j+1,2) = m.z;
      W(2*j+1) = wm;
    }
  }
  K(0) = K(1) = K(2) = 0;
  for (int j = 1; j < nseg; j++)
  {
    K(2*j+1) = j;
    K(2*j+2) = j;
  }
  K(2*nseg+1) = K(2*nseg+2) = K(2*nseg+3) = nseg;
  return callstatic ("geom.Spline.nurbs", ovl (P, K, W));
}

// Insert the knot U once into a B-spline of degree P, in homogeneous form,
// in the knot span that begins at U, or with LEFT the span that ends at it,
// which keeps the span among the control points at the end of the domain
static void
insertknot (int p, vector<double>& K, vector<vector<double>>& Q, double u,
            bool left)
{
  int k = 0;
  for (size_t i = 0; i + 1 < K.size (); i++)
    if (left ? (K[i] < u && u <= K[i+1]) : (K[i] <= u && u < K[i+1]))
      k = i;
  if (k > static_cast<int> (Q.size ()) - 1)
    throw Bad {"invalid"};
  vector<vector<double>> R;
  for (int i = 0; i <= static_cast<int> (Q.size ()); i++)
  {
    if (i <= k - p)
      R.push_back (Q[i]);
    else if (i <= k)
    {
      double den = K[i+p] - K[i];
      double al = den == 0 ? 0 : (u - K[i]) / den;
      vector<double> r (4);
      for (int c = 0; c < 4; c++)
        r[c] = al * Q[i][c] + (1 - al) * Q[i-1][c];
      R.push_back (r);
    }
    else
      R.push_back (Q[i-1]);
  }
  K.insert (K.begin () + k + 1, u);
  Q = R;
}

// Clamp an unclamped knot vector, as a periodic spline from another program
// has, so the curve begins and ends on its control points
static void
clampspline (int p, vector<double>& K, vector<V3>& C, vector<double>& W)
{
  size_t n = C.size ();
  if (K.size () != n + p + 1 || n < static_cast<size_t> (p + 1))
    throw Bad {"invalid"};
  bool clamped = true;
  for (int i = 1; i <= p; i++)
    if (K[i] != K[0] || K[K.size () - 1 - i] != K.back ())
      clamped = false;
  if (clamped)
    return;
  vector<vector<double>> Q;
  for (size_t i = 0; i < n; i++)
    Q.push_back ({C[i].x * W[i], C[i].y * W[i], C[i].z * W[i], W[i]});
  double a = K[p], b = K[K.size () - 1 - p];
  auto mult = [&] (double u) {
    int m = 0;
    for (double k : K)
      if (k == u)
        m++;
    return m;
  };
  while (mult (a) < p)
    insertknot (p, K, Q, a, false);
  while (mult (b) < p)
    insertknot (p, K, Q, b, true);
  // The control points whose basis functions reach into [a, b]: those
  // beginning before b's first knot and ending after a's last; the knots
  // beyond them take a's and b's values
  size_t l0 = K.size () - 1;
  while (K[l0] != a)
    l0--;
  size_t f1 = 0;
  while (K[f1] != b)
    f1++;
  size_t c0 = l0 - p, c1 = f1 - 1;
  vector<double> K2 (K.begin () + c0, K.begin () + c1 + p + 2);
  K2.front () = a;
  K2.back () = b;
  vector<V3> C2;
  vector<double> W2;
  for (size_t i = c0; i <= c1; i++)
  {
    double w = Q[i][3];
    C2.push_back (v3 (Q[i][0] / w, Q[i][1] / w, Q[i][2] / w));
    W2.push_back (w);
  }
  K = K2;
  C = C2;
  W = W2;
}

static Matrix
ptsmat (const vector<V3>& p)
{
  Matrix m (p.size (), 3);
  for (size_t k = 0; k < p.size (); k++)
  {
    m(k,0) = p[k].x;
    m(k,1) = p[k].y;
    m(k,2) = p[k].z;
  }
  return m;
}

static RowVector
rowvec (const vector<double>& v)
{
  RowVector r (v.size ());
  for (size_t k = 0; k < v.size (); k++)
    r(k) = v[k];
  return r;
}

// A geom.Spline from DXF spline data in world coordinates: through its fit
// points where they rebuild the same control points, which keeps the fit
// data, otherwise from its control points; in the frame T
static octave_value
buildspline (int p, vector<double> K, vector<V3> C, vector<double> W,
             const vector<V3>& fit, const V3 *t1, const V3 *t2, bool closed,
             const Frame& T, bool framed)
{
  octave_value U = framed ? ucsobject (T) : call ("geom.UCS",
                                                   octave_value_list ());
  auto loc = [&] (const vector<V3>& w) {
    vector<V3> l;
    for (const auto& q : w)
      l.push_back (framed ? tolocal (T, q) : q);
    return l;
  };
  auto dir = [&] (const V3& d) {
    return framed ? v3 (dot (d, T.x), dot (d, T.y), dot (d, T.n)) : d;
  };
  octave_value fromfit;
  if (fit.size () >= 2 && p == 3)
  {
    Matrix Tg (2, 3);
    Tg.fill (octave_NaN);
    if (t1 && ! closed)
    {
      V3 d = dir (*t1);
      Tg(0,0) = d.x;
      Tg(0,1) = d.y;
      Tg(0,2) = d.z;
    }
    if (t2 && ! closed)
    {
      V3 d = dir (*t2);
      Tg(1,0) = d.x;
      Tg(1,1) = d.y;
      Tg(1,2) = d.z;
    }
    try
    {
      fromfit = call ("geom.Spline", ovl (ptsmat (loc (fit)), "Tangents",
                                          Tg, "Closed", closed, "UCS",
                                          U));
    }
    catch (const octave::execution_exception&)
    {
      recover ();
      fromfit = octave_value ();
    }
  }
  if (C.empty ())
  {
    if (fromfit.is_defined ())
      return fromfit;
    throw Bad {"invalid"};
  }
  if (W.size () != C.size ())
    W.assign (C.size (), 1);
  clampspline (p, K, C, W);
  vector<V3> Cl = loc (C);
  if (fromfit.is_defined ())
  {
    Matrix C2 = prop (fromfit, "ControlPoints").matrix_value ();
    Matrix K2 = prop (fromfit, "Knots").matrix_value ();
    bool same = static_cast<size_t> (C2.rows ()) == Cl.size ()
                && static_cast<size_t> (K2.numel ()) == K.size ();
    double sc = scaleof (Cl);
    for (size_t k = 0; same && k < Cl.size (); k++)
      same = norm (row3 (C2, k) - Cl[k]) <= 1e-6 * sc;
    for (size_t k = 0; same && k < K.size (); k++)
      same = fabs (K2(k) - K[k]) <= 1e-6 * max (1.0, fabs (K[k]));
    if (same)
      return fromfit;
  }
  ColumnVector Wc (W.size ());
  for (size_t k = 0; k < W.size (); k++)
    Wc(k) = W[k];
  return callstatic ("geom.Spline.nurbs", ovl (ptsmat (Cl), rowvec (K), Wc,
                                               "UCS", U));
}

// The normal of a record, the world z axis when it gives none
static V3
normalof (const Rec& r)
{
  V3 n = r.pt (210, v3 (0, 0, 1));
  return norm (n) > 0 ? unit (n) : v3 (0, 0, 1);
}

// The vertices of an LWPOLYLINE, which repeats groups 10, 20 and 42
static vector<PV>
lwverts (const Rec& r, double sc)
{
  vector<PV> v;
  for (const auto& t : r.tags)
  {
    if (t.first == 10)
      v.push_back ({tonum (t.second) * sc, 0, 0});
    else if (t.first == 20 && ! v.empty ())
      v.back ().y = tonum (t.second) * sc;
    else if (t.first == 42 && ! v.empty ())
      v.back ().b = tonum (t.second);
  }
  return v;
}

struct SplineIn
{
  int degree = 3;
  int flags = 0;
  vector<double> K, W;
  vector<V3> C, F;
  bool h1 = false, h2 = false;
  V3 t1, t2;
};

static SplineIn
splinetags (const Rec& r, double sc)
{
  SplineIn s;
  for (size_t k = 0; k < r.tags.size (); k++)
  {
    int c = r.tags[k].first;
    double v = tonum (r.tags[k].second);
    switch (c)
    {
      case 70: s.flags = static_cast<int> (v); break;
      case 71: s.degree = static_cast<int> (v); break;
      case 40: s.K.push_back (v); break;
      case 41: s.W.push_back (v); break;
      case 10: s.C.push_back (v3 (v * sc, 0, 0)); break;
      case 20: if (! s.C.empty ()) s.C.back ().y = v * sc; break;
      case 30: if (! s.C.empty ()) s.C.back ().z = v * sc; break;
      case 11: s.F.push_back (v3 (v * sc, 0, 0)); break;
      case 21: if (! s.F.empty ()) s.F.back ().y = v * sc; break;
      case 31: if (! s.F.empty ()) s.F.back ().z = v * sc; break;
      case 12: s.h1 = true; s.t1.x = v; break;
      case 22: s.t1.y = v; break;
      case 32: s.t1.z = v; break;
      case 13: s.h2 = true; s.t2.x = v; break;
      case 23: s.t2.y = v; break;
      case 33: s.t2.z = v; break;
      default: break;
    }
  }
  if (s.h1 && norm (s.t1) == 0)
    s.h1 = false;
  if (s.h2 && norm (s.t2) == 0)
    s.h2 = false;
  return s;
}

// One boundary loop of a hatch, read as geom objects in world coordinates
struct HLoop
{
  int flags;
  vector<octave_value> pieces;
};

struct HatchIn
{
  string pattern;
  bool solid = false;
  double angle = 0, scl = 1, offset = 0;
  V3 n;
  double elev = 0;
  vector<HLoop> loops;
};

static HatchIn
hatchtags (const Rec& r, double sc)
{
  HatchIn h;
  const vector<Tag>& t = r.tags;
  size_t i = 0, N = t.size ();
  h.n = normalof (r);
  // Up to the loop count: the elevation, the normal, the pattern name
  for (; i < N && t[i].first != 91; i++)
  {
    if (t[i].first == 30)
      h.elev = tonum (t[i].second) * sc;
    else if (t[i].first == 2)
      h.pattern = trim (t[i].second);
    else if (t[i].first == 70)
      h.solid = tonum (t[i].second) != 0;
  }
  if (i >= N)
    return h;
  int nloops = static_cast<int> (tonum (t[i].second));
  i++;
  auto next = [&] (int code) -> double {
    while (i < N && t[i].first != code)
      i++;
    return i < N ? tonum (t[i++].second) : 0;
  };
  auto get = [&] (int code, double dflt) -> double {
    if (i < N && t[i].first == code)
      return tonum (t[i++].second);
    return dflt;
  };
  for (int L = 0; L < nloops && i < N; L++)
  {
    HLoop lp;
    lp.flags = static_cast<int> (next (92));
    if (lp.flags & 2)
    {
      bool hasb = get (72, 0) != 0;
      bool closed = get (73, 1) != 0;
      (void) closed;
      int nv = static_cast<int> (get (93, 0));
      vector<PV> v;
      for (int k = 0; k < nv && i < N; k++)
      {
        double x = get (10, 0) * sc, y = get (20, 0) * sc, b = 0;
        if (hasb)
          b = get (42, 0);
        v.push_back ({x, y, b});
      }
      lp.pieces.push_back (ocspolyline (v, true, h.n, h.elev, nullptr));
    }
    else
    {
      int ne = static_cast<int> (get (93, 0));
      Frame f = ocsframe (h.n);
      for (int k = 0; k < ne && i < N; k++)
      {
        int type = static_cast<int> (get (72, 0));
        if (type == 1)
        {
          double x1 = get (10, 0) * sc, y1 = get (20, 0) * sc;
          double x2 = get (11, 0) * sc, y2 = get (21, 0) * sc;
          lp.pieces.push_back (ocspolyline ({{x1, y1, 0}, {x2, y2, 0}},
                                            false, h.n, h.elev,
                                            nullptr));
        }
        else if (type == 2)
        {
          double cx = get (10, 0) * sc, cy = get (20, 0) * sc;
          double R = get (40, 0) * sc;
          double s0 = get (50, 0), s1 = get (51, 0);
          bool ccw = get (73, 1) != 0;
          // A clockwise arc is stored by the complements of its
          // angles, swapped
          double as = ccw ? s0 : 360 - s0, ae = ccw ? s1 : 360 - s1;
          double span = ccw ? fmod (fmod (ae - as, 360) + 360, 360)
                            : fmod (fmod (as - ae, 360) + 360, 360);
          if (span == 0)
            span = 360;
          double b = tan (rad (span) / 4) * (ccw ? 1 : -1);
          if (span >= 360)
          {
            // A whole circle, as two half arcs
            double am = as + (ccw ? 180 : -180);
            vector<PV> v = {
              {cx + R * cos (rad (as)), cy + R * sin (rad (as)),
               ccw ? 1.0 : -1.0},
              {cx + R * cos (rad (am)), cy + R * sin (rad (am)),
               ccw ? 1.0 : -1.0}};
            lp.pieces.push_back (ocspolyline (v, true, h.n, h.elev,
                                              nullptr));
            continue;
          }
          vector<PV> v = {
            {cx + R * cos (rad (as)), cy + R * sin (rad (as)), b},
            {cx + R * cos (rad (ae)), cy + R * sin (rad (ae)), 0}};
          lp.pieces.push_back (ocspolyline (v, false, h.n, h.elev,
                                            nullptr));
        }
        else if (type == 3)
        {
          double cx = get (10, 0) * sc, cy = get (20, 0) * sc;
          double mx = get (11, 0) * sc, my = get (21, 0) * sc;
          double ratio = get (40, 1);
          double s0 = get (50, 0), s1 = get (51, 360);
          bool ccw = get (73, 1) != 0;
          V3 c = toworld (f, v3 (cx, cy, h.elev));
          V3 X = unit (rotate (f, v3 (mx, my, 0)));
          V3 Y = unit (cross (f.n, X));
          double a = sqrt (mx * mx + my * my);
          // The angles are geometric, not the ellipse's parameter;
          // a clockwise edge is anticlockwise in the mirrored frame
          auto par = [&] (double ang) {
            return atan2 (sin (rad (ang)) / ratio, cos (rad (ang)));
          };
            lp.pieces.push_back (ellipsespline (c, X, ccw ? Y : Y * -1.0,
                                                a, ratio * a, par (s0),
                                                par (s1)));
          }
          else if (type == 4)
          {
            int p = static_cast<int> (get (94, 3));
            bool rat = get (73, 0) != 0;
            get (74, 0);
            int nk = static_cast<int> (get (95, 0));
            int nc = static_cast<int> (get (96, 0));
            vector<double> K, W;
            vector<V3> C;
            for (int j = 0; j < nk; j++)
              K.push_back (get (40, 0));
            for (int j = 0; j < nc; j++)
            {
              double x = get (10, 0) * sc, y = get (20, 0) * sc;
              C.push_back (toworld (f, v3 (x, y, h.elev)));
              W.push_back (rat ? get (42, 1) : 1);
            }
            // Fit data, which R2010 on adds to a spline edge
            if (i < N && t[i].first == 97)
            {
              int nf = static_cast<int> (get (97, 0));
              for (int j = 0; j < nf; j++)
              {
                get (11, 0);
                get (21, 0);
              }
              get (12, 0);
              get (22, 0);
              get (13, 0);
              get (23, 0);
            }
            lp.pieces.push_back (buildspline (p, K, C, W, {}, nullptr,
                                              nullptr, false,
                                              worldframe (), false));
          }
        }
      }
      // The boundary objects a hatch may name
      int ns = static_cast<int> (get (97, 0));
      for (int k = 0; k < ns; k++)
        get (330, 0);
      h.loops.push_back (lp);
    }
  for (; i < N; i++)
  {
    if (t[i].first == 52)
      h.angle = tonum (t[i].second);
    else if (t[i].first == 41)
      h.scl = tonum (t[i].second);
    else if (t[i].first == 45 && h.offset == 0 && i + 1 < N
             && t[i+1].first == 46)
      {
        double ox = tonum (t[i].second), oy = tonum (t[i+1].second);
        h.offset = sqrt (ox * ox + oy * oy) * sc;
      }
    else if (t[i].first == 98)
      break;
  }
  return h;
}

static octave_value
cellof (const vector<octave_value>& v)
{
  Cell c (1, v.size ());
  for (size_t k = 0; k < v.size (); k++)
    c(k) = v[k];
  return c;
}

// The regions a hatch fills
static vector<octave_value>
hatchregions (const HatchIn& h)
{
  vector<octave_value> loops;
  for (const auto& L : h.loops)
  {
    if (L.pieces.size () == 1 && prop (L.pieces[0], "Closed").bool_value ())
    {
      loops.push_back (L.pieces[0]);
      continue;
    }
    Cell ch = callstatic ("geom.Path.chain", ovl (cellof (L.pieces)))
              .cell_value ();
    if (ch.numel () != 1 || ! prop (ch(0), "Closed").bool_value ())
      throw Bad {"invalid"};
    loops.push_back (ch(0));
  }
  if (loops.empty ())
    throw Bad {"invalid"};
  Cell R = callstatic ("geom.Region.nest", ovl (cellof (loops))).cell_value ();
  vector<octave_value> out;
  for (octave_idx_type k = 0; k < R.numel (); k++)
    out.push_back (R(k));
  return out;
}

// The geom objects an entity holds as itself: a LINE, ARC, CIRCLE or
// polyline is a geom.Polyline, a SPLINE or ELLIPSE a geom.Spline, a HATCH
// its regions; a slanting LINE and a 3-D POLYLINE a geom.Path.  Our
// extended data restores a frame where it still fits.
static vector<octave_value>
natural (const Rec& r, double sc, bool useframe)
{
  vector<octave_value> out;
  const string& T = r.type;
  XFrame xf = xframe (r.xdata);
  const XFrame *xp = useframe ? &xf : nullptr;
  if (T == "LINE")
  {
    V3 p = r.pt (10) * sc, q = r.pt (11) * sc;
    double s = scaleof ({p, q});
    if (norm (p - q) <= 1e-12 * s)
      throw Bad {"invalid"};
    if (fabs (p.z - q.z) <= 1e-9 * s)
    {
      Frame F = worldframe ();
      F.o = v3 (0, 0, p.z);
      Matrix V (2, 3, 0.0);
      V(0,0) = p.x;
      V(0,1) = p.y;
      V(1,0) = q.x;
      V(1,1) = q.y;
      out.push_back (call ("geom.Polyline", ovl (V, "UCS",
                                                 ucsobject (F))));
    }
    else
      out.push_back (call ("geom.Path", ovl (ptsmat ({p, q}))));
  }
  else if (T == "CIRCLE" || T == "ARC")
  {
    V3 n = normalof (r);
    V3 c = r.pt (10) * sc;
    double R = r.num (40) * sc;
    if (! (R > 0))
      throw Bad {"invalid"};
    if (T == "CIRCLE")
      out.push_back (ocspolyline ({{c.x + R, c.y, 1}, {c.x - R, c.y, 1}},
                                  true, n, c.z, nullptr));
    else
    {
      double a0 = r.num (50), a1 = r.num (51);
      double span = fmod (fmod (a1 - a0, 360) + 360, 360);
      if (span == 0)
        throw Bad {"invalid"};
      double b = tan (rad (span) / 4);
      out.push_back (ocspolyline (
        {{c.x + R * cos (rad (a0)), c.y + R * sin (rad (a0)), b},
         {c.x + R * cos (rad (a1)), c.y + R * sin (rad (a1)), 0}},
        false, n, c.z, nullptr));
    }
  }
  else if (T == "ELLIPSE")
  {
    V3 n = normalof (r);
    V3 c = r.pt (10) * sc, m = r.pt (11) * sc;
    double ratio = r.num (40, 1);
    double a = norm (m);
    if (! (a > 0) || ! (ratio > 0))
      throw Bad {"invalid"};
    V3 X = unit (m), Y = unit (cross (n, X));
    out.push_back (ellipsespline (c, X, Y, a, ratio * a, r.num (41, 0),
                                  r.num (42, 2 * M_PI)));
  }
  else if (T == "LWPOLYLINE")
  {
    bool closed = (static_cast<int> (r.num (70)) & 1) != 0;
    out.push_back (ocspolyline (lwverts (r, sc), closed, normalof (r),
                                r.num (38) * sc, xp));
  }
  else if (T == "POLYLINE")
  {
    int fl = static_cast<int> (r.num (70));
    bool closed = (fl & 1) != 0;
    if (fl & (16 | 64))
      throw Bad {"mesh"};
    if (fl & 8)
    {
      vector<V3> V;
      for (const auto& v : r.sub)
        if (! (static_cast<int> (v.num (70)) & 16))
          V.push_back (v.pt (10) * sc);
      if (V.size () < 2)
        throw Bad {"invalid"};
      out.push_back (call ("geom.Path", ovl (ptsmat (V), "Closed",
                                             closed)));
    }
    else
    {
      vector<PV> v;
      for (const auto& x : r.sub)
        if (! (static_cast<int> (x.num (70)) & 16))
          v.push_back ({x.num (10) * sc, x.num (20) * sc, x.num (42)});
      out.push_back (ocspolyline (v, closed, normalof (r),
                                  r.pt (10).z * sc, xp));
    }
  }
  else if (T == "SPLINE")
  {
    SplineIn s = splinetags (r, sc);
    Frame F = worldframe ();
    bool framed = false;
    if (xp && xf.has && xf.hasn)
    {
      V3 x = unit (xf.x), nn = unit (xf.n);
      if (fabs (dot (x, nn)) < 1e-9 && fabs (norm (xf.x) - 1) < 1e-6)
      {
        F.o = xf.o;
        F.x = x;
        F.n = nn;
        F.y = unit (cross (nn, x));
        framed = true;
      }
    }
    out.push_back (buildspline (s.degree, s.K, s.C, s.W, s.F,
                                s.h1 ? &s.t1 : nullptr,
                                s.h2 ? &s.t2 : nullptr,
                                (s.flags & 1) != 0, F, framed));
  }
  else if (T == "HATCH")
    out = hatchregions (hatchtags (r, sc));
  else
    throw Bad {"skip"};
  return out;
}

// Whether the polyline R has a width, which the package does not draw: a
// constant width, a default width, or a width at any vertex
static bool
haswidth (const Rec& r)
{
  if (r.type != "LWPOLYLINE" && r.type != "POLYLINE")
    return false;
  for (const auto& t : r.tags)
    if ((t.first == 40 || t.first == 41 || t.first == 43)
        && tonum (t.second) != 0)
      return true;
  for (const auto& v : r.sub)
    if (v.num (40) != 0 || v.num (41) != 0)
      return true;
  return false;
}

static string
skiplabel (const Rec& r, const string& why)
{
  if (why == "invalid")
    return "invalid " + r.type;
  if (why == "mesh")
    return "mesh " + r.type;
  return r.type;
}

// Every record of our groups, by handle
static map<string, size_t>
handles (const vector<Rec>& ents)
{
  map<string, size_t> h;
  for (size_t k = 0; k < ents.size (); k++)
    if (! ents[k].handle.empty ())
      h[ents[k].handle] = k;
  return h;
}

// The object a group of ours holds, rebuilt from its members: a path
// chained from its pieces, a region nested from its loops; in the frame its
// extended data names, where that still fits
static octave_value
groupobject (const Reader& rd, const Reader::Grp& g, const vector<size_t>& m,
             bool useframe)
{
  XFrame xf = xframe (g.xdata);
  vector<octave_value> pieces;
  for (size_t k : m)
  {
    const Rec& r = rd.ents[k];
    if (r.type == "HATCH")
      continue;
    vector<octave_value> o = natural (r, rd.scale, false);
    pieces.insert (pieces.end (), o.begin (), o.end ());
  }
  if (pieces.empty ())
    throw Bad {"invalid"};
  bool framed = useframe && xf.has && xf.hasn
                && fabs (norm (xf.x) - 1) < 1e-6
                && fabs (dot (unit (xf.x), unit (xf.n))) < 1e-9;
  Frame F;
  if (framed)
  {
    F.o = xf.o;
    F.x = unit (xf.x);
    F.n = unit (xf.n);
    F.y = unit (cross (F.n, F.x));
  }
  if (xf.cls == "geom.Path")
  {
    Cell ch = callstatic ("geom.Path.chain", ovl (cellof (pieces)))
              .cell_value ();
    if (ch.numel () != 1)
      throw Bad {"invalid"};
    octave_value P = ch(0);
    if (framed)
      P = call ("__into__", ovl (P, ucsobject (F)));
    return P;
  }
  if (xf.cls != "geom.Region")
    throw Bad {"invalid"};
  vector<octave_value> loops, open;
  for (const auto& p : pieces)
  {
    if (prop (p, "Closed").bool_value ())
      loops.push_back (p);
    else
      open.push_back (p);
  }
  if (! open.empty ())
  {
    Cell ch = callstatic ("geom.Path.chain", ovl (cellof (open)))
              .cell_value ();
    for (octave_idx_type k = 0; k < ch.numel (); k++)
    {
      if (! prop (ch(k), "Closed").bool_value ())
        throw Bad {"invalid"};
      loops.push_back (ch(k));
    }
  }
  Cell R = callstatic ("geom.Region.nest", ovl (cellof (loops))).cell_value ();
  if (R.numel () != 1)
    throw Bad {"invalid"};
  octave_value reg = R(0);
  if (framed)
  {
    Frame G = ucsframe (prop (reg, "UCS"));
    if (fabs (fabs (dot (G.n, F.n)) - 1) < 1e-9
        && fabs (dot (F.o - G.o, G.n)) <= 1e-9 * max (1.0, norm (G.o)))
      {
        octave_value U = ucsobject (F);
        octave_value out = call ("__into__", ovl (prop (reg, "Outline"), U));
        Cell H = prop (reg, "Holes").cell_value ();
        Cell H2 (1, H.numel ());
        for (octave_idx_type k = 0; k < H.numel (); k++)
          H2(k) = call ("__into__", ovl (H(k), U));
        reg = call ("geom.Region", ovl (out, H2));
      }
  }
  return reg;
}

// Members of our groups that rebuild, by the record that leads each
struct GroupHit
{
  map<size_t, octave_value> lead;
  set<size_t> taken;
};

static GroupHit
restoregroups (const Reader& rd, bool useframe, Skips& sk)
{
  GroupHit gh;
  map<string, size_t> h = handles (rd.ents);
  for (const auto& g : rd.groups)
  {
    XFrame xf = xframe (g.xdata);
    if (xf.cls != "geom.Path" && xf.cls != "geom.Region")
      continue;
    vector<size_t> m;
    bool ok = true;
    for (const auto& hd : g.members)
    {
      auto it = h.find (hd);
      if (it == h.end () || gh.taken.count (it->second)
          || rd.ents[it->second].paper)
        ok = false;
      else
        m.push_back (it->second);
    }
    if (! ok || m.empty ())
      continue;
    try
    {
      octave_value o = groupobject (rd, g, m, useframe);
      size_t first = *min_element (m.begin (), m.end ());
      gh.lead[first] = o;
      for (size_t k : m)
        gh.taken.insert (k);
    }
    catch (const Bad&)
    {
      // A group that no longer rebuilds leaves its members as they are
    }
    catch (const octave::execution_exception&)
    {
      recover ();
    }
  }
  (void) sk;
  return gh;
}

static void
cmdreadgeom (const octave_value_list& args, octave_value_list& out)
{
  if (args.length () != 3)
    error ("__dxf__: invalid number of input arguments.");
  g_caller = args(2).string_value ();
  if (! ischarrow (args(1)))
    error ("%s: FILE must be a non-empty character vector.",
           g_caller.c_str ());
  Reader rd;
  rd.load (args(1).string_value ());
  Skips sk;
  GroupHit gh = restoregroups (rd, true, sk);
  vector<octave_value> objs;
  vector<string> layers, types;
  for (size_t k = 0; k < rd.ents.size (); k++)
  {
    const Rec& r = rd.ents[k];
    if (r.paper)
    {
      sk.add (r.type + " in paper space");
      continue;
    }
    auto lead = gh.lead.find (k);
    if (lead != gh.lead.end ())
    {
      objs.push_back (lead->second);
      layers.push_back (r.layer);
      types.push_back ("GROUP");
      continue;
    }
    if (gh.taken.count (k))
      continue;
    try
    {
      vector<octave_value> o = natural (r, rd.scale, true);
      for (const auto& x : o)
      {
        objs.push_back (x);
        layers.push_back (r.layer);
        types.push_back (r.type);
      }
      if (haswidth (r))
        sk.add (r.type + " width");
    }
    catch (const Bad& b)
    {
      sk.add (skiplabel (r, b.why));
    }
    catch (const octave::execution_exception&)
    {
      recover ();
      sk.add ("invalid " + r.type);
    }
  }
  Cell L (1, layers.size ()), Ty (1, types.size ());
  for (size_t k = 0; k < layers.size (); k++)
  {
    L(k) = layers[k];
    Ty(k) = types[k];
  }
  out = ovl (cellof (objs), L, Ty, sk.labels (), sk.counts ());
}

// The plain text an MTEXT shows, its formatting codes removed
static string
mtextplain (const string& s)
{
  string out;
  size_t i = 0;
  while (i < s.size ())
  {
    char c = s[i];
    if (c == '{' || c == '}')
    {
      i++;
      continue;
    }
    if (c != '\\' || i + 1 >= s.size ())
    {
      out += c;
      i++;
      continue;
    }
    char d = s[i+1];
    switch (d)
    {
      case 'P':
      case 'X':
      case '~':
        out += ' ';
        i += 2;
        break;
      case '\\':
      case '{':
      case '}':
        out += d;
        i += 2;
        break;
      case 'L':
      case 'l':
      case 'O':
      case 'o':
      case 'K':
      case 'k':
        i += 2;
        break;
      case 'S':
      {
        size_t e = s.find (';', i);
        string f = s.substr (i + 2, e == string::npos ? string::npos
                                                      : e - i - 2);
        for (auto& ch : f)
          if (ch == '^' || ch == '#')
            ch = '/';
        out += f;
        i = e == string::npos ? s.size () : e + 1;
        break;
      }
      default:
      {
        size_t e = s.find (';', i);
        i = e == string::npos ? s.size () : e + 1;
      }
    }
  }
  return trim (out);
}

static Matrix
xy (double x, double y)
{
  Matrix m (1, 2);
  m(0) = x;
  m(1) = y;
  return m;
}

static Matrix
xy (const V3& p)
{
  return xy (p.x, p.y);
}

// Rebuild the dimension its definition points describe.  Which method made
// it is recoverable from the DXF type alone: the six points mean different
// things for each.
static octave_value
raisedim (const octave_value& D, const Rec& r, double sc, const string& txt)
{
  V3 L = r.pt (10) * sc, P1 = r.pt (13) * sc, P2 = r.pt (14) * sc;
  V3 Q = r.pt (15) * sc, A = r.pt (16) * sc;
  L.z = P1.z = P2.z = Q.z = A.z = 0;
  string lbl = txt == "<>" ? "" : txt;
  int t = static_cast<int> (r.num (70));
  int type = (t & 7) + (t & 64);
  auto cr = [] (const V3& a, const V3& b) { return a.x * b.y - a.y * b.x; };
  switch (type)
  {
    case 0:
    {
      // The offset is the signed distance from the measured points out to
      // the dimension line, along the normal of the direction measured
      double rot = r.num (50);
      V3 N = v3 (-sin (rad (rot)), cos (rad (rot)), 0);
      double off = dot (L - P1, N);
      string dir = "aligned";
      if (fabs (rot) < 1e-9)
        dir = "horizontal";
      else if (fabs (fabs (rot) - 90) < 1e-9)
        dir = "vertical";
      return call ("dim", ovl (D, xy (P1), xy (P2), off, dir, lbl));
    }
    case 1:
    {
      // Its dimension line runs parallel to the points it measures
      V3 U = P2 - P1;
      if (norm (U) < 1e-12)
        throw Bad {"invalid"};
      U = unit (U);
      V3 N = v3 (-U.y, U.x, 0);
      return call ("dim", ovl (D, xy (P1), xy (P2), dot (L - P1, N),
                               "aligned", lbl));
    }
    case 2:
    {
      // Two lines, 13 to 14 and 15 to 10, and a point on the arc, 16.  The
      // vertex is where they meet, the arms each way along them that
      // bounds the angle holding the arc.
      V3 r1 = P2 - P1, r2 = L - Q;
      double det = cr (r1, r2);
      if (norm (r1) == 0 || norm (r2) == 0
          || fabs (det) <= 1e-12 * norm (r1) * norm (r2))
        throw Bad {"invalid"};
      V3 d = Q - P1;
      double t1 = cr (d, r2) / det;
      V3 V = P1 + r1 * t1;
      if (norm (A - V) == 0)
        throw Bad {"invalid"};
      V3 e = A - V;
      double c1 = cr (e, r2) / det, c2 = cr (r1, e) / det;
      V3 u1 = r1 * (c1 >= 0 ? 1.0 : -1.0), u2 = r2 * (c2 >= 0 ? 1.0 : -1.0);
      if (cr (u1, u2) < 0)
        swap (u1, u2);
      return call ("angdim", ovl (D, xy (V), xy (V + u1), xy (V + u2),
                                  norm (A - V), lbl));
    }
    case 5:
    {
      // The vertex, 15, an arm point each, 13 and 14, and a point on the
      // arc, 10, which tells which of the two angles is measured
      V3 V = Q;
      if (norm (P1 - V) == 0 || norm (P2 - V) == 0 || norm (L - V) == 0)
        throw Bad {"invalid"};
      double a1 = deg (atan2 (P1.y - V.y, P1.x - V.x));
      double a2 = deg (atan2 (P2.y - V.y, P2.x - V.x));
      double aa = deg (atan2 (L.y - V.y, L.x - V.x));
      auto md = [] (double x) { return fmod (fmod (x, 360) + 360, 360); };
      if (md (aa - a1) <= md (a2 - a1))
        return call ("angdim", ovl (D, xy (V), xy (P1), xy (P2),
                                    norm (L - V), lbl));
      return call ("angdim", ovl (D, xy (V), xy (P2), xy (P1),
                                  norm (L - V), lbl));
    }
    case 3:
    {
      V3 C = (L + Q) * 0.5;
      double R = norm (L - Q) / 2;
      double a = deg (atan2 (L.y - C.y, L.x - C.x));
      return call ("diam", ovl (D, xy (C), R, a, lbl));
    }
    case 4:
    {
      double R = norm (L - Q);
      double a = deg (atan2 (L.y - Q.y, L.x - Q.x));
      return call ("radius", ovl (D, xy (Q), R, a, lbl));
    }
    case 6:
    case 70:
    {
      // The datum, 10, the feature, 13, and the end of the leader, 14
      string ax = type == 70 ? "x" : "y";
      bool alongy = type == 70;
      if ((alongy ? P2.y == P1.y : P2.x == P1.x))
        throw Bad {"invalid"};
      return call ("ordinate", ovl (D, xy (L), xy (P1), ax, xy (P2), lbl));
    }
    default:
      throw Bad {"type"};
  }
}

static string
drawltype (const string& s)
{
  string u = upper (s);
  if (u.empty () || u == "BYLAYER" || u == "BYBLOCK" || u == "CONTINUOUS")
    return "CONTINUOUS";
  return s;
}

class Replay
{
public:
  Replay (const Reader& rd, Skips& sk) : m_rd (rd), m_sk (sk) { }

  octave_value run (octave_value D, const vector<Rec>& recs,
                    const set<string>& defined, const GroupHit *gh)
  {
    m_layer = "0";
    m_ltype = "CONTINUOUS";
    m_colour = 256;
    for (size_t k = 0; k < recs.size (); k++)
    {
      const Rec& r = recs[k];
      if (r.paper)
      {
        m_sk.add (r.type + " in paper space");
        continue;
      }
      if (gh)
      {
        auto lead = gh->lead.find (k);
        if (lead != gh->lead.end ())
        {
          D = attrs (D, r);
          try
          {
            D = call (isclass (lead->second, "geom.Path") ? "path"
                                                         : "region",
                      ovl (D, lead->second));
          }
          catch (const octave::execution_exception&)
          {
            recover ();
            m_sk.add ("invalid GROUP");
          }
          continue;
        }
        if (gh->taken.count (k))
          continue;
      }
      try
      {
        D = attrs (D, r);
        D = one (D, r, defined);
      }
      catch (const Bad& b)
      {
        if (b.why == "skip")
          m_sk.add (r.type);
        else if (b.why == "type")
          m_sk.add ("DIMENSION of a type not drawn");
        else if (b.why == "tilted")
          m_sk.add (r.type + " off the xy plane");
        else if (b.why == "undefined")
          m_sk.add ("INSERT of an undefined block");
        else
          m_sk.add (skiplabel (r, b.why));
      }
      catch (const octave::execution_exception&)
      {
        recover ();
        m_sk.add ("invalid " + r.type);
      }
    }
    // Leave the drawing on its defaults rather than on whatever the last
    // entity happened to carry
    D = setprop (D, "Layer", octave_value ("0"));
    D = setprop (D, "Linetype", octave_value ("CONTINUOUS"));
    D = setprop (D, "Colour", octave_value (256.0));
    return D;
  }

private:
  const Reader& m_rd;
  Skips& m_sk;
  string m_layer, m_ltype;
  int m_colour;

  // Layer, line type and colour are properties of the drawing at the moment
  // an entity is appended: set them, then draw, as a draughtsman does
  octave_value attrs (octave_value D, const Rec& r)
  {
    string layer = r.layer.empty () ? "0" : r.layer;
    string lt = r.ltype;
    int c = abs (r.colour);
    if (c > 256)
      c = 256;

    // What the entity takes from its layer, the layer's own colour and line
    // type, since a drawing has no layer table to defer to
    auto lay = m_rd.layers.find (upper (layer));
    if (lay != m_rd.layers.end ())
    {
      string u = upper (trim (lt));
      if (u.empty () || u == "BYLAYER")
        lt = lay->second.ltype;
      if (c == 256)
        c = lay->second.colour;
    }
    lt = drawltype (lt);
    if (layer != m_layer)
    {
      D = setprop (D, "Layer", octave_value (layer));
      m_layer = layer;
    }
    if (lt != m_ltype)
    {
      D = setprop (D, "Linetype", octave_value (lt));
      m_ltype = lt;
    }
    if (c != m_colour)
    {
      D = setprop (D, "Colour", octave_value (static_cast<double> (c)));
      m_colour = c;
    }
    return D;
  }

  octave_value one (octave_value D, const Rec& r, const set<string>& defined)
  {
    double sc = m_rd.scale;
    const string& T = r.type;
    if (T == "LINE")
    {
      V3 p = r.pt (10) * sc, q = r.pt (11) * sc;
      if (p.x == q.x && p.y == q.y)
        throw Bad {"invalid"};
      return call ("line", ovl (D, xy (p), xy (q)));
    }
    if (T == "POINT")
      return call ("point", ovl (D, xy (r.pt (10) * sc)));
    if (T == "CIRCLE" || T == "ARC")
    {
      V3 n = normalof (r);
      if (! isz (n))
        throw Bad {"tilted"};
      V3 c = toworld (ocsframe (n), r.pt (10) * sc);
      double R = r.num (40) * sc;
      if (T == "CIRCLE")
        return call ("circle", ovl (D, xy (c), R));
      double a0 = r.num (50), a1 = r.num (51);
      if (n.z < 0)
        return call ("arc", ovl (D, xy (c), R, 180 - a1, 180 - a0));
      return call ("arc", ovl (D, xy (c), R, a0, a1));
    }
    if (T == "ELLIPSE")
    {
      V3 n = normalof (r);
      if (! isz (n))
        throw Bad {"tilted"};
      V3 c = r.pt (10) * sc, m = r.pt (11) * sc;
      double p0 = r.num (41, 0), p1 = r.num (42, 2 * M_PI);
      double span = p1 - p0;
      if (fabs (span - 2 * M_PI) < 1e-9 || fabs (span) < 1e-12)
      {
        double A = norm (m);
        return call ("ellipse", ovl (D, xy (c), A, r.num (40, 1) * A,
                                     deg (atan2 (m.y, m.x))));
      }
      vector<octave_value> o = natural (r, sc, false);
      return call ("spline", ovl (D, o[0]));
    }
    if (T == "LWPOLYLINE" || T == "POLYLINE")
    {
      V3 n = normalof (r);
      int fl = static_cast<int> (r.num (70));
      if (T == "POLYLINE" && (fl & (8 | 16 | 64)))
        throw Bad {"mesh"};
      if (! isz (n))
        throw Bad {"tilted"};
      bool closed = (fl & 1) != 0;
      vector<PV> v;
      if (T == "LWPOLYLINE")
        v = lwverts (r, sc);
      else
        for (const auto& x : r.sub)
          if (! (static_cast<int> (x.num (70)) & 16))
            v.push_back ({x.num (10) * sc, x.num (20) * sc, x.num (42)});
      octave_value out = call ("polyline", ovl (D, ocspolyline (v, closed,
                                                                 n, 0,
                                                                 nullptr)));
      if (haswidth (r))
        m_sk.add (T + " width");
      return out;
    }
    if (T == "SPLINE")
    {
      vector<octave_value> o = natural (r, sc, false);
      return call ("spline", ovl (D, o[0]));
    }
    if (T == "TEXT" || T == "MTEXT")
    {
      string s;
      if (T == "TEXT")
        s = m_rd.decode (r.str (1));
      else
      {
        for (const auto& t : r.tags)
          if (t.first == 3)
            s += t.second;
        s = mtextplain (m_rd.decode (s + r.str (1)));
      }
      if (s.empty ())
        throw Bad {"skip"};
      double h = r.num (40, 2.5 / sc) * sc;
      double rot = r.num (50);
      if (T == "MTEXT" && ! r.has (50) && r.has (11))
        rot = deg (atan2 (r.num (21), r.num (11)));
      return call ("text", ovl (D, xy (r.pt (10) * sc), s, h, rot));
    }
    if (T == "INSERT")
    {
      string nm = trim (r.str (2));
      if (! defined.count (upper (nm)))
        throw Bad {"undefined"};
      return call ("insert", ovl (D, nm, xy (r.pt (10) * sc), r.num (50),
                                  r.num (41, 1)));
    }
    if (T == "DIMENSION")
      return raisedim (D, r, sc, m_rd.decode (r.str (1, "<>")));
    if (T == "HATCH")
    {
      HatchIn h = hatchtags (r, sc);
      vector<octave_value> regs = hatchregions (h);
      const Pattern *p = h.solid ? nullptr : findpattern (h.pattern);
      string name = p ? p->name : "ANSI31";
      double spacing = p ? p->spacing * h.scl
                         : (h.offset > 0 ? h.offset : 3.175);
      if (! p)
        m_sk.add ("HATCH pattern '" + h.pattern + "' drawn as ANSI31");
      for (const auto& R : regs)
        D = call ("hatch", ovl (D, R, name, h.angle, spacing));
      return D;
    }
    throw Bad {"skip"};
  }
};

// The block names an entity list places
static vector<string>
insertnames (const vector<Rec>& recs)
{
  vector<string> n;
  for (const auto& r : recs)
    if (r.type == "INSERT")
      n.push_back (upper (trim (r.str (2))));
  return n;
}

static void
cmdreaddraw (const octave_value_list& args, octave_value_list& out)
{
  if (args.length () != 3)
    error ("__dxf__: invalid number of input arguments.");
  g_caller = args(2).string_value ();
  if (! ischarrow (args(1)))
    error ("%s: FILE must be a non-empty character vector.",
           g_caller.c_str ());
  Reader rd;
  rd.load (args(1).string_value ());
  Skips sk;

  // Which blocks are placed, and by what.  The picture of a dimension lives
  // in a block no INSERT refers to, and the dimension is raised from its
  // definition points, so keeping the picture would carry it twice; the
  // layout containers go the same way.  A placed block is kept, since
  // nothing else holds its geometry.
  set<string> placed;
  for (const auto& n : insertnames (rd.ents))
    placed.insert (n);
  for (const auto& b : rd.blocks)
    for (const auto& n : insertnames (b.ents))
      placed.insert (n);
  vector<size_t> keep;
  for (size_t k = 0; k < rd.blocks.size (); k++)
  {
    string nm = upper (rd.blocks[k].name);
    if (nm.empty ())
      continue;
    if (placed.count (nm) || ! (nm[0] == '*' || nm == "$MODEL_SPACE"
                                || nm == "$PAPER_SPACE"))
      keep.push_back (k);
  }
  set<string> names;
  for (size_t k : keep)
    names.insert (upper (rd.blocks[k].name));

  // A block may place another, so raise them in dependency order; a cycle,
  // which DXF forbids but a file may hold, is taken in file order
  vector<size_t> order, pending = keep;
  set<string> done;
  while (! pending.empty ())
  {
    vector<size_t> ready, rest;
    for (size_t k : pending)
    {
      bool ok = true;
      for (const auto& n : insertnames (rd.blocks[k].ents))
        if (names.count (n) && ! done.count (n))
          ok = false;
      (ok ? ready : rest).push_back (k);
    }
    if (ready.empty ())
    {
      order.insert (order.end (), rest.begin (), rest.end ());
      break;
    }
    for (size_t k : ready)
    {
      order.push_back (k);
      done.insert (upper (rd.blocks[k].name));
    }
    pending = rest;
  }

  Replay rp (rd, sk);
  map<string, octave_value> built;
  map<string, string> spelt;
  for (size_t k : order)
  {
    const Reader::Blk& b = rd.blocks[k];
    octave_value B = call ("draw.Drawing", ovl (b.name));
    set<string> defined;
    vector<string> deps = insertnames (b.ents);
    for (const auto& d : deps)
      if (built.count (d) && ! defined.count (d))
      {
        B = call ("block", ovl (B, spelt[d], built[d]));
        defined.insert (d);
      }
    B = rp.run (B, b.ents, defined, nullptr);
    built[upper (b.name)] = B;
    spelt[upper (b.name)] = b.name;
  }

  octave_value D = call ("draw.Drawing", ovl ("imported"));
  set<string> defined;
  for (size_t k : keep)
  {
    string u = upper (rd.blocks[k].name);
    if (built.count (u))
    {
      D = call ("block", ovl (D, rd.blocks[k].name, built[u]));
      defined.insert (u);
    }
  }
  GroupHit gh = restoregroups (rd, false, sk);
  D = rp.run (D, rd.ents, defined, &gh);
  out = ovl (D, sk.labels (), sk.counts ());
}

////////////////////////////////////////////////////////////////////////////////

DEFUN_DLD (__dxf__, args, nargout,
           "-*- texinfo -*-\n\
@deftypefn {} {} __dxf__ (@dots{})\n\
Read and write ASCII DXF for the drafting package.  Internal.\n\
@end deftypefn")
{
  if (args.length () < 1 || ! args(0).is_string ())
    error ("__dxf__: invalid number of input arguments.");
  string cmd = args(0).string_value ();
  octave_value_list out;
  if (cmd == "write")
    cmdwrite (args);
  else if (cmd == "readgeom")
    cmdreadgeom (args, out);
  else if (cmd == "readdraw")
    cmdreaddraw (args, out);
  else
    error ("__dxf__: unknown command '%s'.", cmd.c_str ());
  (void) nargout;
  return out;
}
