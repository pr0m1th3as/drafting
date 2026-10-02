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

#include <cmath>
#include <functional>
#include <sstream>
#include <string>
#include <vector>

#include <octave/oct.h>

#include <APIHeaderSection_MakeHeader.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_BooleanOperation.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepTools.hxx>
#include <BRepTools_ReShape.hxx>
#include <BRepLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffset_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepPrimAPI_MakeWedge.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRep_Tool.hxx>
#include <BinTools.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <GProp_GProps.hxx>
#include <Interface_Static.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <Standard_Failure.hxx>
#include <StlAPI_Writer.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>

using namespace std;

// Every shape crosses into Octave as the bytes of OCCT's binary format, which
// begin with this signature.  Bytes without it never reach the reader.
static const char signature[] = "\nOpen CASCADE Topology V";

// OCCT prints progress to stdout through its default messenger.  A library
// call has no business writing to the command window, so the printers are
// removed once, before the first call that could use them.
static void
quiet ()
{
  static bool done = false;
  if (! done)
  {
    Message::DefaultMessenger ()->ChangePrinters ().Clear ();
    done = true;
  }
}

// The number of distinct sub-shapes of one kind.  A shared edge is counted
// once, which a plain explorer does not do.
static octave_idx_type
count (const TopoDS_Shape& s, TopAbs_ShapeEnum type)
{
  if (s.IsNull ())
  {
    return 0;
  }
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, type, map);
  return map.Extent ();
}

// A shape from the bytes held by a solid.Shape; empty bytes are the empty
// shape.
static TopoDS_Shape
toshape (const octave_value& v, const string& caller)
{
  TopoDS_Shape s;
  if (v.isempty ())
  {
    return s;
  }
  if (! v.is_uint8_type ())
  {
    error ("%s: shape data must be uint8.", caller.c_str ());
  }
  const uint8NDArray a = v.uint8_array_value ();
  const size_t n = a.numel ();
  const size_t m = sizeof (signature) - 1;
  string bytes (n, '\0');
  for (size_t i = 0; i < n; i++)
  {
    bytes[i] = static_cast<char> (a(i).value ());
  }
  if (n < m || bytes.compare (0, m, signature) != 0)
  {
    error ("%s: shape data is not an Open CASCADE shape.", caller.c_str ());
  }
  istringstream is (bytes);
  BinTools::Read (s, is);
  return s;
}

// The bytes of a shape.  A shape with no faces, such as the result of
// intersecting two solids that do not meet, is returned as the empty shape.
static octave_value
todata (const TopoDS_Shape& s)
{
  if (count (s, TopAbs_FACE) == 0)
  {
    return octave_value (uint8NDArray (dim_vector (0, 0)));
  }
  ostringstream os;
  BinTools::Write (s, os, Standard_False, Standard_False,
                   BinTools_FormatVersion_CURRENT);
  const string bytes = os.str ();
  uint8NDArray a (dim_vector (1, bytes.size ()));
  for (size_t i = 0; i < bytes.size (); i++)
  {
    a(i) = static_cast<unsigned char> (bytes[i]);
  }
  return octave_value (a);
}

static gp_Pnt
topoint (const octave_value& v)
{
  const NDArray a = v.array_value ();
  return gp_Pnt (a(0), a(1), a(2));
}

static gp_Dir
todir (const octave_value& v)
{
  const NDArray a = v.array_value ();
  return gp_Dir (a(0), a(1), a(2));
}

// The cubic B-spline made of the Bezier pieces whose control points are the
// rows of P, end to end, the pieces meeting at the parameters T.  Where they
// meet smoothly, as a geom.Spline's do, the knot is made simple again.
static Handle (Geom_BSplineCurve)
bspline (const Matrix& p, const ColumnVector& t)
{
  const octave_idx_type k = t.numel ();
  TColgp_Array1OfPnt poles (1, p.rows ());
  for (octave_idx_type i = 0; i < p.rows (); i++)
  {
    poles.SetValue (i + 1, gp_Pnt (p(i,0), p(i,1), p(i,2)));
  }
  TColStd_Array1OfReal knots (1, k);
  TColStd_Array1OfInteger mults (1, k);
  for (octave_idx_type i = 0; i < k; i++)
  {
    knots.SetValue (i + 1, t(i));
    mults.SetValue (i + 1, (i == 0 || i == k - 1) ? 4 : 3);
  }
  Handle (Geom_BSplineCurve) c
    = new Geom_BSplineCurve (poles, knots, mults, 3);
  for (octave_idx_type i = 2; i < k; i++)
  {
    c->RemoveKnot (i, 1, 1e-9 * t(k-1));
  }
  return c;
}

// The wire of a geom.Path as solid.__path__ hands it over, in world
// coordinates: its vertices; the midpoints of its arcs, NaN for a segment
// that is not an arc; for each spline segment the control points of its cubic
// pieces and the parameters where they meet; and whether it is closed, its
// last segment then running back to the first vertex, or for a path of one
// vertex its one spline running round to it
static TopoDS_Wire
chain (const octave_value& p)
{
  const octave_scalar_map s = p.scalar_map_value ();
  const Matrix v = s.contents ("vertices").matrix_value ();
  const Matrix m = s.contents ("midpoints").matrix_value ();
  const Cell sp = s.contents ("splines").cell_value ();
  const bool closed = s.contents ("closed").bool_value ();
  const octave_idx_type n = v.rows ();
  BRepBuilderAPI_MakeWire w;
  for (octave_idx_type i = 0; i < (closed ? n : n - 1); i++)
  {
    const octave_idx_type j = (i + 1) % n;
    const gp_Pnt a (v(i,0), v(i,1), v(i,2));
    const gp_Pnt b (v(j,0), v(j,1), v(j,2));
    if (! sp(i).isempty ())
    {
      const octave_scalar_map c = sp(i).scalar_map_value ();
      w.Add (BRepBuilderAPI_MakeEdge
               (bspline (c.contents ("poles").matrix_value (),
                         c.contents ("knots").column_vector_value ()))
             .Edge ());
    }
    else if (octave::math::isnan (m(i,0)))
    {
      w.Add (BRepBuilderAPI_MakeEdge (a, b).Edge ());
    }
    else
    {
      const Handle (Geom_TrimmedCurve) arc
        = GC_MakeArcOfCircle (a, gp_Pnt (m(i,0), m(i,1), m(i,2)), b)
          .Value ();
      w.Add (BRepBuilderAPI_MakeEdge (arc).Edge ());
    }
  }
  return w.Wire ();
}

// A geom.Region as Octave hands it over: the outline and a cell of the
// holes, each a path as chain reads it, and the frame of its plane, rows
// origin, x axis, y axis and normal.  The outline runs anticlockwise and the
// holes clockwise.
struct region
{
  TopoDS_Wire outer;
  vector<TopoDS_Wire> holes;
  gp_Pnt origin;
  gp_Dir x, y, normal;
};

static region
toregion (const octave_value& v)
{
  const octave_scalar_map m = v.scalar_map_value ();
  const Matrix f = m.contents ("frame").matrix_value ();
  const gp_XYZ o (f(0,0), f(0,1), f(0,2));
  const gp_XYZ u (f(1,0), f(1,1), f(1,2));
  const gp_XYZ w (f(2,0), f(2,1), f(2,2));
  region r;
  r.origin = gp_Pnt (o);
  r.x = gp_Dir (u);
  r.y = gp_Dir (w);
  r.normal = gp_Dir (f(3,0), f(3,1), f(3,2));
  r.outer = chain (m.contents ("outline"));
  const Cell h = m.contents ("holes").cell_value ();
  for (octave_idx_type i = 0; i < h.numel (); i++)
  {
    r.holes.push_back (chain (h(i)));
  }
  return r;
}

// The planar face a region bounds, its holes as inner wires
static TopoDS_Face
planarface (const region& r)
{
  BRepBuilderAPI_MakeFace f (r.outer, Standard_True);
  for (const TopoDS_Wire& h : r.holes)
  {
    f.Add (h);
  }
  return f.Face ();
}

// One side of an extrusion of R, height H along its normal, its walls leaning
// in by A radians (out when A is negative), corners kept sharp as a drafted
// wall's are: each outline is joined by straight lines to its offset at the
// top, and the holes are cut from the outline.
static TopoDS_Shape
taperedside (const region& r, double h, double a, const string& caller);

// S less every shape in TOOLS, in one operation
static TopoDS_Shape
cutall (const TopoDS_Shape& s, const vector<TopoDS_Shape>& tools,
        const string& caller);

// The sub-shapes of one kind picked by 1-based indices into the map of all of
// them, which is the order in which the queries report them.  The indices have
// been checked against the count by the caller.
static TopTools_ListOfShape
picked (const TopoDS_Shape& s, TopAbs_ShapeEnum type, const NDArray& idx)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, type, map);
  TopTools_ListOfShape list;
  for (octave_idx_type i = 0; i < idx.numel (); i++)
  {
    list.Append (map (static_cast<int> (idx(i))));
  }
  return list;
}

// The bounding box of a sub-shape as a row of a matrix
static void
boxrow (const TopoDS_Shape& s, Matrix& m, octave_idx_type i)
{
  Bnd_Box b;
  BRepBndLib::AddOptimal (s, b, Standard_False, Standard_False);
  double x0, y0, z0, x1, y1, z1;
  b.Get (x0, y0, z0, x1, y1, z1);
  m(i,0) = x0;
  m(i,1) = y0;
  m(i,2) = z0;
  m(i,3) = x1;
  m(i,4) = y1;
  m(i,5) = z1;
}

static void
dirrow (const gp_Dir& d, Matrix& m, octave_idx_type i)
{
  m(i,0) = d.X ();
  m(i,1) = d.Y ();
  m(i,2) = d.Z ();
}

// The edges of a shape: the kind of curve each lies on, its direction (a
// line's, or the axis of a circle or ellipse), its bounding box, whether it is
// a seam or a degenerate edge, which bounds a face without being a feature of
// the part, and the indices of the faces it bounds.
static Cell
edgeinfo (const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, TopAbs_EDGE, map);
  TopTools_IndexedDataMapOfShapeListOfShape faces;
  TopExp::MapShapesAndAncestors (s, TopAbs_EDGE, TopAbs_FACE, faces);
  TopTools_IndexedMapOfShape fmap;
  TopExp::MapShapes (s, TopAbs_FACE, fmap);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Cell onfaces (n, 1);
  Matrix dir (n, 3, octave_NaN);
  Matrix box (n, 6);
  boolNDArray seam (dim_vector (n, 1), false);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Edge e = TopoDS::Edge (map (i + 1));
    boxrow (e, box, i);
    if (BRep_Tool::Degenerated (e))
    {
      type(i) = "degenerate";
      seam(i) = true;
      onfaces(i) = RowVector (0);
      continue;
    }
    const BRepAdaptor_Curve c (e);
    switch (c.GetType ())
    {
      case GeomAbs_Line:
        type(i) = "line";
        dirrow (c.Line ().Direction (), dir, i);
        break;
      case GeomAbs_Circle:
        type(i) = "circle";
        dirrow (c.Circle ().Axis ().Direction (), dir, i);
        break;
      case GeomAbs_Ellipse:
        type(i) = "ellipse";
        dirrow (c.Ellipse ().Axis ().Direction (), dir, i);
        break;
      case GeomAbs_BSplineCurve:
      case GeomAbs_BezierCurve:
        type(i) = "bspline";
        break;
      default:
        type(i) = "other";
    }
    const int k = faces.FindIndex (e);
    if (k > 0)
    {
      RowVector idx (0);
      for (const TopoDS_Shape& f : faces (k))
      {
        if (BRep_Tool::IsClosed (e, TopoDS::Face (f)))
        {
          seam(i) = true;
        }
        const int j = fmap.FindIndex (f);
        bool seen = false;
        for (octave_idx_type q = 0; q < idx.numel (); q++)
        {
          seen = seen || idx(q) == j;
        }
        if (! seen)
        {
          idx.resize (idx.numel () + 1, j);
        }
      }
      onfaces(i) = idx;
    }
    else
    {
      onfaces(i) = RowVector (0);
    }
  }
  return Cell (ovl (type, dir, box, seam, onfaces));
}

// The faces of a shape: the kind of surface each lies on, the outward normal
// of a plane, the axis of a surface of revolution, and its bounding box
static Cell
faceinfo (const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes (s, TopAbs_FACE, map);
  const octave_idx_type n = map.Extent ();
  Cell type (n, 1);
  Matrix normal (n, 3, octave_NaN);
  Matrix axis (n, 3, octave_NaN);
  Matrix box (n, 6);
  for (octave_idx_type i = 0; i < n; i++)
  {
    const TopoDS_Face f = TopoDS::Face (map (i + 1));
    boxrow (f, box, i);
    const BRepAdaptor_Surface a (f);
    switch (a.GetType ())
    {
      case GeomAbs_Plane:
      {
        type(i) = "plane";
        gp_Dir d = a.Plane ().Axis ().Direction ();
        if (f.Orientation () == TopAbs_REVERSED)
        {
          d.Reverse ();
        }
        dirrow (d, normal, i);
        break;
      }
      case GeomAbs_Cylinder:
        type(i) = "cylinder";
        dirrow (a.Cylinder ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_Cone:
        type(i) = "cone";
        dirrow (a.Cone ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_Sphere:
        type(i) = "sphere";
        break;
      case GeomAbs_Torus:
        type(i) = "torus";
        dirrow (a.Torus ().Axis ().Direction (), axis, i);
        break;
      case GeomAbs_SurfaceOfRevolution:
        type(i) = "revolution";
        dirrow (a.AxeOfRevolution ().Direction (), axis, i);
        break;
      case GeomAbs_SurfaceOfExtrusion:
        type(i) = "extrusion";
        break;
      case GeomAbs_BSplineSurface:
      case GeomAbs_BezierSurface:
        type(i) = "bspline";
        break;
      default:
        type(i) = "other";
    }
  }
  return Cell (ovl (type, normal, axis, box));
}

// The volume and centre of volume of S, integrated adaptively to a relative
// error of 1e-9 on every face.  The default integration, of fixed order, errs
// by up to a part in a thousand on spline faces.  The adaptive one computes
// the centre only when asked to.  Should it fail, the default is taken.
static GProp_GProps
volumeprops (const TopoDS_Shape& s)
{
  GProp_GProps p;
  if (BRepGProp::VolumePropertiesGK (s, p, 1e-9, Standard_False,
                                     Standard_False, Standard_True) < 0)
  {
    p = GProp_GProps ();
    BRepGProp::VolumeProperties (s, p);
  }
  return p;
}

// The area of S, face by face.  A planar face's area is the volume of the
// prism of unit height on it, which the adaptive volume integration finds
// exactly however its edges curve; a curved face takes Open CASCADE's surface
// integration, the only one it has.
static double
area (const TopoDS_Shape& s)
{
  double a = 0;
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face f = TopoDS::Face (x.Current ());
    const BRepAdaptor_Surface g (f, Standard_False);
    if (g.GetType () == GeomAbs_Plane)
    {
      BRepPrimAPI_MakePrism prism (f, gp_Vec (g.Plane ().Axis ().Direction ()));
      if (prism.IsDone ())
      {
        GProp_GProps p;
        if (BRepGProp::VolumePropertiesGK (prism.Shape (), p, 1e-9) >= 0)
        {
          a += std::abs (p.Mass ());
          continue;
        }
      }
    }
    GProp_GProps p;
    BRepGProp::SurfaceProperties (f, p);
    a += p.Mass ();
  }
  return a;
}

// A transformed copy of a shape
static TopoDS_Shape
transform (const TopoDS_Shape& s, const gp_Trsf& t)
{
  return BRepBuilderAPI_Transform (s, t, Standard_True).Shape ();
}

// The result of a boolean operation, its coplanar faces and collinear edges
// merged so that a union of two blocks reads as one block.
static TopoDS_Shape
boolean (BRepAlgoAPI_BooleanOperation& op, const string& caller,
         const char *what)
{
  op.Build ();
  if (op.HasErrors () || ! op.IsDone ())
  {
    error ("%s: Open CASCADE could not compute the %s.", caller.c_str (),
           what);
  }
  op.SimplifyResult ();
  return op.Shape ();
}

static TopoDS_Shape
cutall (const TopoDS_Shape& s, const vector<TopoDS_Shape>& tools,
        const string& caller)
{
  if (tools.empty ())
  {
    return s;
  }
  TopTools_ListOfShape objects, list;
  objects.Append (s);
  for (const TopoDS_Shape& t : tools)
  {
    list.Append (t);
  }
  BRepAlgoAPI_Cut op;
  op.SetArguments (objects);
  op.SetTools (list);
  return boolean (op, caller, "holes");
}

// A wire swept along SPINE into a solid, with sharp corners or, along a
// helix, the Frenet frame
static TopoDS_Shape
pipe (const TopoDS_Wire& spine, const TopoDS_Wire& w, bool frenet,
      const string& caller)
{
  BRepOffsetAPI_MakePipeShell op (spine);
  if (frenet)
  {
    op.SetMode (Standard_True);
  }
  else
  {
    op.SetTransitionMode (BRepBuilderAPI_RightCorner);
  }
  op.Add (w);
  op.Build ();
  if (! op.IsDone () || ! op.MakeSolid ())
  {
    error ("%s: Open CASCADE could not compute the sweep.", caller.c_str ());
  }
  return op.Shape ();
}

// A wire offset by D in its plane, outwards for a positive D whichever way
// it runs, its corners kept sharp; then lifted by V
static TopoDS_Wire
offsetwire (const TopoDS_Wire& w, double d, const gp_Vec& v,
            const string& caller)
{
  BRepOffsetAPI_MakeOffset op (w, GeomAbs_Intersection);
  op.Perform (d);
  TopExp_Explorer x;
  if (op.IsDone ())
  {
    x.Init (op.Shape (), TopAbs_WIRE);
  }
  if (! op.IsDone () || ! x.More ())
  {
    error ("%s: Open CASCADE could not compute the taper.", caller.c_str ());
  }
  gp_Trsf t;
  t.SetTranslation (v);
  return TopoDS::Wire (transform (x.Current (), t));
}

// S with every spline face that lies in a plane made a true plane on the
// same edges, so that a flat wall counts as flat when queried, picked or
// drawn.  A ruled loft makes even a flat wall a spline.
static TopoDS_Shape
planarize (const TopoDS_Shape& s)
{
  BRepTools_ReShape rs;
  bool changed = false;
  for (TopExp_Explorer x (s, TopAbs_FACE); x.More (); x.Next ())
  {
    const TopoDS_Face& f = TopoDS::Face (x.Current ());
    const BRepAdaptor_Surface a (f, Standard_False);
    if (a.GetType () != GeomAbs_BSplineSurface
        && a.GetType () != GeomAbs_BezierSurface)
    {
      continue;
    }
    GeomLib_IsPlanarSurface pl (BRep_Tool::Surface (f), 1e-7);
    if (! pl.IsPlanar ())
    {
      continue;
    }
    // The plane facing as the face does, then the face rebuilt on it
    gp_Pln p = pl.Plan ();
    const double u = (a.FirstUParameter () + a.LastUParameter ()) / 2;
    const double v = (a.FirstVParameter () + a.LastVParameter ()) / 2;
    BRepLProp_SLProps props (BRepAdaptor_Surface (f), u, v, 1, 1e-9);
    gp_Dir n = props.Normal ();
    if (f.Orientation () == TopAbs_REVERSED)
    {
      n.Reverse ();
    }
    if (p.Axis ().Direction ().Dot (n) < 0)
    {
      p = gp_Pln (p.Location (), p.Axis ().Direction ().Reversed ());
    }
    BRepBuilderAPI_MakeFace mf (p, BRepTools::OuterWire (f), Standard_True);
    for (TopExp_Explorer w (f, TopAbs_WIRE); w.More (); w.Next ())
    {
      if (! w.Current ().IsSame (BRepTools::OuterWire (f)))
      {
        mf.Add (TopoDS::Wire (w.Current ()));
      }
    }
    if (! mf.IsDone ())
    {
      continue;
    }
    TopoDS_Face nf = mf.Face ();
    nf.Orientation (f.Orientation ());
    rs.Replace (f, nf);
    changed = true;
  }
  return changed ? rs.Apply (s) : s;
}

// The solid between a wire and its offset lifted, by straight lines
static TopoDS_Shape
ruled (const TopoDS_Wire& a, const TopoDS_Wire& b, const string& caller)
{
  BRepOffsetAPI_ThruSections op (Standard_True, Standard_True);
  op.AddWire (a);
  op.AddWire (b);
  op.Build ();
  if (! op.IsDone ())
  {
    error ("%s: Open CASCADE could not compute the taper.", caller.c_str ());
  }
  return op.Shape ();
}

static TopoDS_Shape
taperedside (const region& r, double h, double a, const string& caller)
{
  const gp_Vec up = gp_Vec (r.normal) * h;
  if (a == 0)
  {
    return BRepPrimAPI_MakePrism (planarface (r), up).Shape ();
  }
  // The section at the top is the region offset by the run of the wall:
  // its outline in, its holes out, for walls leaning in
  const double d = h * tan (a);
  vector<TopoDS_Shape> holes;
  for (const TopoDS_Wire& w : r.holes)
  {
    holes.push_back (ruled (w, offsetwire (w, d, up, caller), caller));
  }
  return planarize (cutall (ruled (r.outer, offsetwire (r.outer, -d, up,
                                                       caller), caller),
                            holes, caller));
}

static void
writestep (const TopoDS_Shape& s, const string& file, const string& name,
           const string& caller)
{
  STEPControl_Writer w;
  Interface_Static::SetCVal ("write.step.unit", "MM");
  Interface_Static::SetCVal ("write.step.product.name", name.c_str ());
  if (w.Transfer (s, STEPControl_AsIs) != IFSelect_RetDone)
  {
    error ("%s: Open CASCADE could not translate the shape to STEP.",
           caller.c_str ());
  }
  APIHeaderSection_MakeHeader header (w.Model ());
  header.SetName (new TCollection_HAsciiString (name.c_str ()));
  header.SetAuthorValue (1, new TCollection_HAsciiString (""));
  header.SetOrganizationValue (1, new TCollection_HAsciiString (""));
  header.SetOriginatingSystem
    (new TCollection_HAsciiString ("GNU Octave drafting package"));
  header.SetAuthorisation (new TCollection_HAsciiString (""));
  if (w.Write (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot write '%s'.", caller.c_str (), file.c_str ());
  }
}

static void
writestl (const TopoDS_Shape& s, const string& file, double tol,
          double angle, const string& caller)
{
  BRepMesh_IncrementalMesh mesh (s, tol, Standard_False, angle,
                                 Standard_True);
  if (! mesh.IsDone ())
  {
    error ("%s: Open CASCADE could not triangulate the shape.",
           caller.c_str ());
  }
  StlAPI_Writer w;
  w.ASCIIMode () = Standard_False;
  if (! w.Write (s, file.c_str ()))
  {
    error ("%s: cannot write '%s'.", caller.c_str (), file.c_str ());
  }
}

static TopoDS_Shape
readstep (const string& file, const string& caller)
{
  STEPControl_Reader r;
  Interface_Static::SetCVal ("xstep.cascade.unit", "MM");
  if (r.ReadFile (file.c_str ()) != IFSelect_RetDone)
  {
    error ("%s: cannot read '%s' as a STEP file.", caller.c_str (),
           file.c_str ());
  }
  if (r.TransferRoots () == 0)
  {
    error ("%s: '%s' holds no shape.", caller.c_str (), file.c_str ());
  }
  return r.OneShape ();
}

DEFUN_DLD (__occt__, args, ,
           "-*- texinfo -*-\n\
 @deftypefn {} {@var{out} =} __occt__ (@var{cmd}, @var{caller}, @dots{})\n\
\n\
\n\
Run one Open CASCADE operation.  \n\
\n\
@var{cmd} names the operation and @var{caller} the function on whose behalf \
it runs, which is the name any error is raised under.  Shapes go in and come \
out as the uint8 bytes held by a @qcode{solid.Shape}.  The arguments are \
validated by the caller and are not checked again. \n\
\n\
This is a helper function for the @qcode{solid} namespace.  Do NOT use this \
function directly. \n\
\n\
@end deftypefn")
{
  // Validate input
  if (args.length () < 2 || ! args(0).is_string () || ! args(1).is_string ())
  {
    error ("__occt__: invalid number of input arguments.");
  }
  const string cmd = args(0).string_value ();
  const string caller = args(1).string_value ();

  quiet ();

  octave_value out;
  try
  {
    // Primitives
    if (cmd == "box")
    {
      out = todata (BRepPrimAPI_MakeBox (args(2).double_value (),
                                         args(3).double_value (),
                                         args(4).double_value ()).Shape ());
    }
    else if (cmd == "cylinder")
    {
      out = todata (BRepPrimAPI_MakeCylinder (args(2).double_value (),
                                              args(3).double_value ())
                    .Shape ());
    }
    // A wedge: a block DX by DY at the base, DZ high, its top face spanning
    // XMIN to XMAX and YMIN to YMAX.  Open CASCADE builds a wedge with its
    // height along y, so it is built in axes that turn that onto z.
    else if (cmd == "wedge")
    {
      const double dx = args(2).double_value ();
      const double dy = args(3).double_value ();
      const double dz = args(4).double_value ();
      const NDArray top = args(5).array_value ();
      const gp_Ax2 axes (gp_Pnt (0, dy, 0), gp_Dir (0, -1, 0),
                         gp_Dir (1, 0, 0));
      out = todata (BRepPrimAPI_MakeWedge (axes, dx, dz, dy, top(0),
                                           dy - top(3), top(2), dy - top(1))
                    .Shape ());
    }
    else if (cmd == "cone")
    {
      out = todata (BRepPrimAPI_MakeCone (args(2).double_value (),
                                          args(3).double_value (),
                                          args(4).double_value ()).Shape ());
    }
    else if (cmd == "sphere")
    {
      out = todata (BRepPrimAPI_MakeSphere (args(2).double_value ()).Shape ());
    }
    else if (cmd == "torus")
    {
      out = todata (BRepPrimAPI_MakeTorus (args(2).double_value (),
                                           args(3).double_value ()).Shape ());
    }
    // A primitive put in a UCS: its own axes laid on the frame's, whose rows
    // are the origin, x axis, y axis and normal
    else if (cmd == "place")
    {
      const Matrix f = args(3).matrix_value ();
      gp_Trsf t;
      t.SetDisplacement (gp_Ax3 (gp::XOY ()),
                         gp_Ax3 (gp_Pnt (f(0,0), f(0,1), f(0,2)),
                                 gp_Dir (f(3,0), f(3,1), f(3,2)),
                                 gp_Dir (f(1,0), f(1,1), f(1,2))));
      out = todata (transform (toshape (args(2), caller), t));
    }

    // Solids from regions, each made where the region's plane puts it.  An
    // extrusion rises along the normal; a revolution turns about the plane's
    // y axis through its origin; a loft passes through regions where they
    // lie; a sweep carries the region from where it lies along a path.
    // An extrusion runs H1 along the normal and H2 against it, each side's
    // walls leaning in by its own angle
    else if (cmd == "extrude")
    {
      const region r = toregion (args(2));
      const double h1 = args(3).double_value ();
      const double h2 = args(4).double_value ();
      const double a1 = args(5).double_value () * M_PI / 180;
      const double a2 = args(6).double_value () * M_PI / 180;
      if (a1 == 0 && a2 == 0)
      {
        gp_Trsf t;
        t.SetTranslation (gp_Vec (r.normal) * -h2);
        out = todata (BRepPrimAPI_MakePrism
                        (transform (planarface (r), t),
                         gp_Vec (r.normal) * (h1 + h2)).Shape ());
      }
      else
      {
        TopTools_ListOfShape sides;
        if (h1 > 0)
        {
          sides.Append (taperedside (r, h1, a1, caller));
        }
        if (h2 > 0)
        {
          // The far side is a near side mirrored in the region's plane
          gp_Trsf m;
          m.SetMirror (gp_Ax2 (r.origin, r.normal));
          sides.Append (transform (taperedside (r, h2, a2, caller), m));
        }
        if (sides.Extent () == 1)
        {
          out = todata (sides.First ());
        }
        else
        {
          TopTools_ListOfShape objects, tools;
          objects.Append (sides.First ());
          tools.Append (sides.Last ());
          BRepAlgoAPI_Fuse op;
          op.SetArguments (objects);
          op.SetTools (tools);
          out = todata (boolean (op, caller, "extrusion"));
        }
      }
    }
    else if (cmd == "revolve")
    {
      const region r = toregion (args(2));
      const gp_Ax1 axis (r.origin, r.y);
      const double angle = args(3).double_value ();
      if (angle >= 360)
      {
        out = todata (BRepPrimAPI_MakeRevol (planarface (r), axis).Shape ());
      }
      else
      {
        out = todata (BRepPrimAPI_MakeRevol (planarface (r), axis,
                                             angle * M_PI / 180).Shape ());
      }
    }
    else if (cmd == "loft")
    {
      const Cell R = args(2).cell_value ();
      const bool ruled = args(3).bool_value ();
      vector<region> rs;
      for (octave_idx_type i = 0; i < R.numel (); i++)
      {
        rs.push_back (toregion (R(i)));
      }
      // The outlines lofted, less each hole lofted through its sections
      auto loft = [&] (std::function<TopoDS_Wire (const region&)> pick)
      {
        BRepOffsetAPI_ThruSections op (Standard_True, ruled);
        for (const region& r : rs)
        {
          op.AddWire (pick (r));
        }
        op.Build ();
        if (! op.IsDone ())
        {
          error ("%s: Open CASCADE could not compute the loft.",
                 caller.c_str ());
        }
        return op.Shape ();
      };
      const TopoDS_Shape outer = loft ([] (const region& r)
                                       { return r.outer; });
      vector<TopoDS_Shape> holes;
      for (size_t k = 0; k < rs[0].holes.size (); k++)
      {
        holes.push_back (loft ([k] (const region& r)
                               { return r.holes[k]; }));
      }
      out = todata (cutall (outer, holes, caller));
    }
    else if (cmd == "sweep")
    {
      const region r = toregion (args(2));
      const TopoDS_Wire spine = chain (args(3));
      vector<TopoDS_Shape> holes;
      for (const TopoDS_Wire& h : r.holes)
      {
        holes.push_back (pipe (spine, h, false, caller));
      }
      out = todata (cutall (pipe (spine, r.outer, false, caller), holes,
                            caller));
    }

    // A helix turns a region about its plane's y axis while it rises along
    // it by the pitch on every turn.  The spine is an exact helix on a
    // cylinder of the given radius, made about the z axis and carried onto
    // the region's frame, and the Frenet frame keeps the region in the plane
    // through the axis, as a thread's profile is.
    else if (cmd == "helix")
    {
      const region r = toregion (args(2));
      const double pitch = args(3).double_value ();
      const double turns = args(4).double_value ();
      const double rad = args(5).double_value ();
      const gp_Dir2d d (2 * M_PI, pitch);
      const double len = turns * hypot (2 * M_PI, pitch);
      Handle (Geom_CylindricalSurface) cyl
        = new Geom_CylindricalSurface (gp_Ax3 (gp::XOY ()), rad);
      Handle (Geom2d_Line) line = new Geom2d_Line (gp_Pnt2d (0, 0), d);
      TopoDS_Edge e = BRepBuilderAPI_MakeEdge (line, cyl, 0, len).Edge ();
      BRepLib::BuildCurves3d (e);
      gp_Trsf place;
      place.SetDisplacement (gp_Ax3 (gp::XOY ()),
                             gp_Ax3 (r.origin, r.y, r.x));
      const TopoDS_Wire spine = TopoDS::Wire (transform
                                  (BRepBuilderAPI_MakeWire (e).Wire (), place));
      vector<TopoDS_Shape> holes;
      for (const TopoDS_Wire& h : r.holes)
      {
        holes.push_back (pipe (spine, h, true, caller));
      }
      out = todata (cutall (pipe (spine, r.outer, true, caller), holes,
                            caller));
    }

    // Features on chosen edges and faces
    else if (cmd == "fillet" || cmd == "chamfer")
    {
      const TopoDS_Shape s = toshape (args(2), caller);
      const TopTools_ListOfShape edges
        = picked (s, TopAbs_EDGE, args(3).array_value ());
      const double size = args(4).array_value ()(0);
      TopoDS_Shape r;
      if (cmd == "fillet")
      {
        BRepFilletAPI_MakeFillet op (s);
        for (const TopoDS_Shape& e : edges)
        {
          op.Add (size, TopoDS::Edge (e));
        }
        op.Build ();
        if (! op.IsDone () || ! BRepCheck_Analyzer (op.Shape ()).IsValid ())
        {
          error ("%s: Open CASCADE could not round the edges.",
                 caller.c_str ());
        }
        r = op.Shape ();
      }
      else
      {
        BRepFilletAPI_MakeChamfer op (s);
        const NDArray d = args(4).array_value ();
        if (args.length () > 6 && args(6).double_value () > 0)
        {
          // D is set back along the face given, and the chamfer meets that
          // face at the angle given
          TopTools_IndexedMapOfShape fmap;
          TopExp::MapShapes (s, TopAbs_FACE, fmap);
          const TopoDS_Face f = TopoDS::Face
                                  (fmap (static_cast<int> (args(5)
                                                           .double_value ())));
          const double a = args(6).double_value () * M_PI / 180;
          for (const TopoDS_Shape& e : edges)
          {
            op.AddDA (d(0), a, TopoDS::Edge (e), f);
          }
        }
        else if (d.numel () == 2)
        {
          // D1 is set back along the face given, D2 along the other
          TopTools_IndexedMapOfShape fmap;
          TopExp::MapShapes (s, TopAbs_FACE, fmap);
          const TopoDS_Face f = TopoDS::Face
                                  (fmap (static_cast<int> (args(5)
                                                           .double_value ())));
          for (const TopoDS_Shape& e : edges)
          {
            op.Add (d(0), d(1), TopoDS::Edge (e), f);
          }
        }
        else
        {
          for (const TopoDS_Shape& e : edges)
          {
            op.Add (size, TopoDS::Edge (e));
          }
        }
        op.Build ();
        if (! op.IsDone () || ! BRepCheck_Analyzer (op.Shape ()).IsValid ())
        {
          error ("%s: Open CASCADE could not chamfer the edges.",
                 caller.c_str ());
        }
        r = op.Shape ();
      }
      out = todata (r);
    }
    else if (cmd == "shell")
    {
      const TopoDS_Shape s = toshape (args(2), caller);
      const TopTools_ListOfShape open
        = picked (s, TopAbs_FACE, args(3).array_value ());
      // The walls grow inwards, or outwards when asked, each the default
      // thickness unless given one of its own
      const bool outward = (args.length () > 5 && args(5).bool_value ());
      const double sign = outward ? 1 : -1;
      const double t = args(4).double_value ();
      BRepOffset_MakeOffset op;
      op.Initialize (s, sign * t, 1e-6, BRepOffset_Skin, Standard_False,
                     Standard_False, GeomAbs_Intersection);
      for (const TopoDS_Shape& f : open)
      {
        op.AddFace (TopoDS::Face (f));
      }
      if (args.length () > 7)
      {
        const NDArray fi = args(6).array_value ();
        const NDArray ft = args(7).array_value ();
        const TopTools_ListOfShape thick = picked (s, TopAbs_FACE, fi);
        octave_idx_type k = 0;
        for (const TopoDS_Shape& f : thick)
        {
          op.SetOffsetOnFace (TopoDS::Face (f), sign * ft(k++));
        }
      }
      op.MakeThickSolid ();
      TopoDS_Shape r;
      if (op.IsDone ())
      {
        r = op.Shape ();
        // With no face opened Open CASCADE returns the offset solid: inwards
        // the cavity, cut from the shape; outwards the outside, from which
        // the shape is cut
        if (open.IsEmpty ())
        {
          // The outside comes back inside out, its volume negative
          GProp_GProps g;
          BRepGProp::VolumeProperties (r, g);
          if (g.Mass () < 0)
          {
            r.Reverse ();
          }
          BRepAlgoAPI_Cut cut;
          TopTools_ListOfShape objects, tools;
          objects.Append (outward ? r : s);
          tools.Append (outward ? s : r);
          cut.SetArguments (objects);
          cut.SetTools (tools);
          cut.Build ();
          r = (cut.HasErrors () || ! cut.IsDone ()) ? TopoDS_Shape ()
                                                    : cut.Shape ();
        }
      }
      // Walls too thick for the shape can leave it untouched rather than
      // fail, so a result no smaller than the shape is a failure too
      GProp_GProps before, after;
      BRepGProp::VolumeProperties (s, before);
      if (! r.IsNull ())
      {
        BRepGProp::VolumeProperties (r, after);
      }
      const bool same = std::abs (after.Mass () - before.Mass ())
                        <= 1e-9 * before.Mass ();
      if (r.IsNull () || ! BRepCheck_Analyzer (r).IsValid ()
          || after.Mass () <= 0 || same
          || (! outward && after.Mass () > before.Mass ()))
      {
        error ("%s: Open CASCADE could not hollow the shape.",
               caller.c_str ());
      }
      out = todata (r);
    }

    // Booleans.  A union and a difference take every shape after the first
    // as a tool in one operation, which is several times faster than taking
    // them one at a time.  An intersection cannot: Open CASCADE intersects
    // the first shape with the union of the tools, so it goes pairwise.
    else if (cmd == "fuse" || cmd == "cut")
    {
      TopTools_ListOfShape objects, tools;
      objects.Append (toshape (args(2), caller));
      for (int i = 3; i < args.length (); i++)
      {
        tools.Append (toshape (args(i), caller));
      }
      if (cmd == "fuse")
      {
        BRepAlgoAPI_Fuse op;
        op.SetArguments (objects);
        op.SetTools (tools);
        out = todata (boolean (op, caller, "union"));
      }
      else
      {
        BRepAlgoAPI_Cut op;
        op.SetArguments (objects);
        op.SetTools (tools);
        out = todata (boolean (op, caller, "difference"));
      }
    }
    else if (cmd == "common")
    {
      TopoDS_Shape s = toshape (args(2), caller);
      for (int i = 3; i < args.length () && count (s, TopAbs_FACE) > 0; i++)
      {
        TopTools_ListOfShape objects, tools;
        objects.Append (s);
        tools.Append (toshape (args(i), caller));
        BRepAlgoAPI_Common op;
        op.SetArguments (objects);
        op.SetTools (tools);
        s = boolean (op, caller, "intersection");
      }
      out = todata (s);
    }

    // Transformations
    else if (cmd == "translate")
    {
      const gp_Pnt v = topoint (args(3));
      gp_Trsf t;
      t.SetTranslation (gp_Vec (v.X (), v.Y (), v.Z ()));
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "rotate")
    {
      gp_Trsf t;
      t.SetRotation (gp_Ax1 (topoint (args(5)), todir (args(4))),
                     args(3).double_value () * M_PI / 180);
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "mirror")
    {
      gp_Trsf t;
      t.SetMirror (gp_Ax2 (topoint (args(4)), todir (args(3))));
      out = todata (transform (toshape (args(2), caller), t));
    }
    else if (cmd == "scale")
    {
      gp_Trsf t;
      t.SetScale (topoint (args(4)), args(3).double_value ());
      out = todata (transform (toshape (args(2), caller), t));
    }

    // Queries
    else if (cmd == "volume")
    {
      out = volumeprops (toshape (args(2), caller)).Mass ();
    }
    else if (cmd == "area")
    {
      out = area (toshape (args(2), caller));
    }
    else if (cmd == "centroid")
    {
      const GProp_GProps p = volumeprops (toshape (args(2), caller));
      RowVector c (3, octave_NaN);
      if (p.Mass () > 0)
      {
        const gp_Pnt g = p.CentreOfMass ();
        c(0) = g.X ();
        c(1) = g.Y ();
        c(2) = g.Z ();
      }
      out = c;
    }
    else if (cmd == "bbox")
    {
      Bnd_Box b;
      BRepBndLib::AddOptimal (toshape (args(2), caller), b, Standard_False,
                              Standard_False);
      double x0, y0, z0, x1, y1, z1;
      b.Get (x0, y0, z0, x1, y1, z1);
      RowVector r (6);
      r(0) = x0;
      r(1) = y0;
      r(2) = z0;
      r(3) = x1;
      r(4) = y1;
      r(5) = z1;
      out = r;
    }
    else if (cmd == "edges")
    {
      out = edgeinfo (toshape (args(2), caller));
    }
    else if (cmd == "faces")
    {
      out = faceinfo (toshape (args(2), caller));
    }
    else if (cmd == "valid")
    {
      out = BRepCheck_Analyzer (toshape (args(2), caller)).IsValid ()
            ? true : false;
    }
    else if (cmd == "count")
    {
      const string what = args(3).string_value ();
      TopAbs_ShapeEnum type = TopAbs_SOLID;
      if (what == "face")
      {
        type = TopAbs_FACE;
      }
      else if (what == "edge")
      {
        type = TopAbs_EDGE;
      }
      else if (what == "vertex")
      {
        type = TopAbs_VERTEX;
      }
      out = static_cast<double> (count (toshape (args(2), caller), type));
    }

    // Files
    else if (cmd == "writestep")
    {
      writestep (toshape (args(2), caller), args(3).string_value (),
                 args(4).string_value (), caller);
    }
    else if (cmd == "writestl")
    {
      writestl (toshape (args(2), caller), args(3).string_value (),
                args(4).double_value (),
                args(5).double_value () * M_PI / 180, caller);
    }
    else if (cmd == "readstep")
    {
      out = todata (readstep (args(2).string_value (), caller));
    }
    else
    {
      error ("__occt__: unknown command '%s'.", cmd.c_str ());
    }
  }
  catch (const Standard_Failure& e)
  {
    const char *msg = e.GetMessageString ();
    if (msg != nullptr && *msg != '\0')
    {
      error ("%s: Open CASCADE failed: %s (%s).", caller.c_str (), msg,
             e.DynamicType ()->Name ());
    }
    error ("%s: Open CASCADE failed (%s).", caller.c_str (),
           e.DynamicType ()->Name ());
  }

  return ovl (out);
}
